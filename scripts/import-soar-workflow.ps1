#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Import soar/n8n/soc-alert-triage.json into the running n8n container.
    Called by `soc.ps1 soar`; safe to re-run (n8n dedupes by workflow id).
#>
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

$container = 'soc-in-a-box-n8n-1'
if (-not (docker ps --filter "name=$container" --format '{{.Names}}')) {
    Write-Host "n8n is not running — start it with 'make soar' / '.\\soc.ps1 soar'"
    exit 1
}

# wait for the API
for ($i = 0; $i -lt 24; $i++) {
    try { if ((Invoke-WebRequest 'http://localhost:5678/healthz' -TimeoutSec 3 -UseBasicParsing).StatusCode -eq 200) { break } } catch { }
    Start-Sleep 5
}

# n8n's import CLI wants a JSON array
$arr = "[`n" + (Get-Content soar/n8n/soc-alert-triage.json -Raw) + "`n]"
$tmp = Join-Path ([IO.Path]::GetTempPath()) 'soc-wf.json'
Set-Content -Path $tmp -Value $arr -Encoding utf8
docker cp $tmp "${container}:/tmp/soc-wf.json" | Out-Null
Remove-Item $tmp

$noise = 'Permissions 0644|User settings loaded|will not take effect|Please restart'
docker exec $container n8n import:workflow --input=/tmp/soc-wf.json 2>&1 | Where-Object { $_ -notmatch $noise }
docker exec $container n8n update:workflow --id=soc-alert-triage --active=true 2>&1 | Where-Object { $_ -notmatch $noise }

# webhook registration only happens on (re)start
Write-Host "[*] restarting n8n so the webhook registers"
docker restart $container | Out-Null
for ($i = 0; $i -lt 24; $i++) {
    try { if ((Invoke-WebRequest 'http://localhost:5678/healthz' -TimeoutSec 3 -UseBasicParsing).StatusCode -eq 200) { break } } catch { }
    Start-Sleep 5
}

Write-Host ""
Write-Host "[+] 'SOC Alert Triage' imported and active."
Write-Host "    It polls Kibana every 5 min for open SOC-in-a-Box alerts, enriches"
Write-Host "    source.ip, opens a Kibana case for high severity, and acks the alert."
Write-Host "    Set SLACK_WEBHOOK_URL / ABUSEIPDB_API_KEY in .env to light up those steps."
Write-Host "    Run once now:  docker exec $container n8n execute --id=soc-alert-triage"
