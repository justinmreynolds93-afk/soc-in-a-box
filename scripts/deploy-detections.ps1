#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy the custom detection rules in elastic/detection-rules/rules/*.json to
    Kibana (create or overwrite). Rules are plain Kibana detection-engine rule
    bodies — one file per rule, reviewed in git like any other code.
.PARAMETER Validate
    Only check that every file parses and has the required fields; do not deploy.
.EXAMPLE
    .\scripts\deploy-detections.ps1
    .\scripts\deploy-detections.ps1 -Validate
#>
param([switch]$Validate)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

$ruleDir = 'elastic/detection-rules/rules'
$files = Get-ChildItem "$ruleDir/*.json" -ErrorAction SilentlyContinue
if (-not $files) { Write-Host "no rule files in $ruleDir"; exit 0 }

$required = 'rule_id', 'name', 'description', 'severity', 'risk_score', 'type'
$ndjson = [System.Collections.Generic.List[string]]::new()
$bad = 0
foreach ($f in $files) {
    try { $r = Get-Content $f.FullName -Raw | ConvertFrom-Json }
    catch { Write-Host "  INVALID JSON  $($f.Name): $($_.Exception.Message)" -ForegroundColor Red; $bad++; continue }
    $missing = $required | Where-Object { -not $r.PSObject.Properties.Name.Contains($_) }
    if ($missing) { Write-Host "  MISSING $($missing -join ',')  $($f.Name)" -ForegroundColor Red; $bad++; continue }
    Write-Host "  ok  $($r.rule_id)  [$($r.type)]  $($r.name)"
    $ndjson.Add(($r | ConvertTo-Json -Depth 20 -Compress))
}
if ($bad) { Write-Host "`n$bad invalid rule file(s)" -ForegroundColor Red; exit 1 }
if ($Validate) { Write-Host "`n$($ndjson.Count) rules valid"; exit 0 }

$pw  = (Select-String -Path .env -Pattern '^ELASTIC_PASSWORD=(.+)').Matches.Groups[1].Value
$kbP = (Select-String -Path .env -Pattern '^KIBANA_PORT=(\d+)').Matches.Groups[1].Value
$h   = @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("elastic:$pw")); 'kbn-xsrf' = '1' }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("soc-rules-{0}.ndjson" -f ([guid]::NewGuid()))
Set-Content -Path $tmp -Value ($ndjson -join "`n") -Encoding utf8 -NoNewline

$res = Invoke-RestMethod -Method Post `
    "https://localhost:$kbP/api/detection_engine/rules/_import?overwrite=true" `
    -Headers $h -Form @{ file = Get-Item $tmp } -SkipCertificateCheck
Remove-Item $tmp

Write-Host ""
Write-Host "[+] created:  $($res.rules_installed ?? $res.success_count)"
Write-Host "[+] updated:  $($res.rules_updated)"
if ($res.errors) {
    Write-Host "[!] errors:" -ForegroundColor Red
    $res.errors | ForEach-Object { Write-Host "    $($_.rule_id ?? '?'): $($_.error.message)" -ForegroundColor Red }
    exit 1
}
