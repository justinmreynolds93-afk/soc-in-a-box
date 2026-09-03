#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pre-flight + bring-up for the Elastic core (M1).
    - checks Docker is running and has enough memory
    - creates .env from .env.example with generated secrets if it does not exist
    - starts the core and waits for Kibana to report "available"
.EXAMPLE
    .\scripts\bootstrap.ps1
#>
[CmdletBinding()]
param(
    [int]$TimeoutMinutes = 12
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

function Info($m) { Write-Host "[*] $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[+] $m" -ForegroundColor Green }
function Die($m)  { Write-Host "[!] $m" -ForegroundColor Red; exit 1 }

# ── 1. Docker ────────────────────────────────────────────────────────────────
Info "checking Docker"
try { $srv = docker info --format '{{.ServerVersion}}' 2>$null }
catch { $srv = $null }
if (-not $srv) { Die "Docker daemon not responding. Start Docker Desktop and retry." }
Ok "Docker engine $srv"

$memBytes = [int64](docker info --format '{{.MemTotal}}' 2>$null)
$memGB = [math]::Round($memBytes / 1GB, 1)
if ($memGB -lt 6) {
    Die "Docker has only ${memGB} GB. Raise it in Docker Desktop > Settings > Resources (>= 8 GB)."
}
Ok "Docker memory ${memGB} GB"

# ── 2. .env ──────────────────────────────────────────────────────────────────
function New-Secret([int]$len) {
    $chars = [char[]]((48..57) + (65..90) + (97..122))
    -join (1..$len | ForEach-Object { $chars | Get-Random })
}

if (-not (Test-Path .env)) {
    Info "creating .env with generated secrets"
    $env = Get-Content .env.example -Raw
    $env = $env -replace 'ELASTIC_PASSWORD=.*',  ("ELASTIC_PASSWORD=" + (New-Secret 24))
    $env = $env -replace 'KIBANA_PASSWORD=.*',   ("KIBANA_PASSWORD="  + (New-Secret 24))
    $env = $env -replace 'ENCRYPTION_KEY=.*',    ("ENCRYPTION_KEY="   + (New-Secret 40))
    Set-Content -Path .env -Value $env -NoNewline -Encoding utf8
    Ok ".env created (kept out of git)"
} else {
    Ok ".env already present"
}

# ── 3. bring up the core ─────────────────────────────────────────────────────
Info "pulling images + starting core (first run downloads ~2.5 GB)"
docker compose --env-file .env -f compose/docker-compose.yml up -d --remove-orphans
if ($LASTEXITCODE -ne 0) { Die "compose up failed" }

# ── 4. wait for Kibana ───────────────────────────────────────────────────────
$kibanaPort = (Select-String -Path .env -Pattern '^KIBANA_PORT=(\d+)').Matches.Groups[1].Value
if (-not $kibanaPort) { $kibanaPort = 5601 }
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
Info "waiting for Kibana on https://localhost:$kibanaPort (up to $TimeoutMinutes min)"

do {
    Start-Sleep 10
    try {
        $r = Invoke-RestMethod -Uri "https://localhost:$kibanaPort/api/status" `
             -SkipCertificateCheck -TimeoutSec 5
        $level = $r.status.overall.level
    } catch { $level = 'starting' }
    Write-Host "    kibana: $level"
} while ($level -ne 'available' -and (Get-Date) -lt $deadline)

if ($level -ne 'available') { Die "Kibana did not become available in time. Check: docker compose -f compose/docker-compose.yml logs" }

# ── 5. summary ───────────────────────────────────────────────────────────────
$elastic = (Select-String -Path .env -Pattern '^ELASTIC_PASSWORD=(.+)').Matches.Groups[1].Value
Write-Host ""
Ok "core is up"
Write-Host ""
Write-Host "  Kibana     https://localhost:$kibanaPort"
Write-Host "  user       elastic"
Write-Host "  password   $elastic"
Write-Host ""
Write-Host "  (self-signed cert - your browser will warn; that is expected)"
Write-Host ""
docker compose -p soc-in-a-box ps
