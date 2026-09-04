#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Correlate a scenario run against the alerts it produced and print an
    ATT&CK coverage / gap table. Feeds the M4 detection backlog.
.PARAMETER RunLog
    Path to a attack/scenarios/runs/*.jsonl file. Default: newest.
.PARAMETER WindowMinutes
    How long after the run start to look for alerts (default 20).
.EXAMPLE
    .\scripts\detection-gap-report.ps1
#>
param(
    [string]$RunLog,
    [int]$WindowMinutes = 20
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

if (-not $RunLog) {
    $RunLog = Get-ChildItem attack/scenarios/runs/*.jsonl | Sort-Object LastWriteTime -desc | Select-Object -First 1 -Expand FullName
}
if (-not (Test-Path $RunLog)) { throw "no run log found — run attack/scenarios/linux-intrusion.sh first" }

$events = Get-Content $RunLog | ForEach-Object { $_ | ConvertFrom-Json }
$runStart = [datetimeoffset]::Parse($events[0].ts, $null, [System.Globalization.DateTimeStyles]::RoundtripKind).UtcDateTime
$from = $runStart.AddMinutes(-2).ToString('o')
$to   = $runStart.AddMinutes($WindowMinutes).ToString('o')

$pw  = (Select-String -Path .env -Pattern '^ELASTIC_PASSWORD=(.+)').Matches.Groups[1].Value
$kbP = (Select-String -Path .env -Pattern '^KIBANA_PORT=(\d+)').Matches.Groups[1].Value
$h   = @{
    Authorization  = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("elastic:$pw"))
    'kbn-xsrf'     = '1'
    'Content-Type' = 'application/json'
}

# alerts in the window
$body = @{
    query = @{ bool = @{ filter = @(
        @{ range = @{ '@timestamp' = @{ gte = $from; lte = $to } } }
        @{ term  = @{ 'kibana.alert.rule.category' = 'siem.queryRule' } }
    ) } }
    size = 200
    _source = @('kibana.alert.rule.name', 'kibana.alert.rule.threat')
} | ConvertTo-Json -Depth 10

$resp = Invoke-RestMethod -Method Post "https://localhost:$kbP/api/detection_engine/signals/search" -Headers $h -Body $body -SkipCertificateCheck
$alerts = $resp.hits.hits._source

$firedTechniques = @{}
$firedRules = [System.Collections.Generic.HashSet[string]]::new()
foreach ($a in $alerts) {
    [void]$firedRules.Add($a.'kibana.alert.rule.name')
    foreach ($t in $a.'kibana.alert.rule.threat') {
        foreach ($tech in $t.technique) {
            $firedTechniques[$tech.id] = $tech.name
            foreach ($sub in $tech.subtechnique) { $firedTechniques[$sub.id] = $sub.name }
        }
    }
}

Write-Host "`nScenario:  $(Split-Path $RunLog -Leaf)"
Write-Host "Window:    $from  ->  $to"
Write-Host "Alerts:    $($alerts.Count)   Distinct rules: $($firedRules.Count)`n"

$rows = foreach ($e in $events) {
    $base = ($e.technique -split '\.')[0]
    $hit  = $firedTechniques.ContainsKey($e.technique) -or $firedTechniques.ContainsKey($base)
    [pscustomobject]@{
        Technique = $e.technique
        Name      = $e.name
        Detected  = if ($hit) { 'YES' } else { '--' }
    }
}
$rows | Format-Table -AutoSize

$covered = ($rows | Where-Object Detected -eq 'YES').Count
Write-Host ("Coverage:  {0}/{1} techniques  ({2:P0})" -f $covered, $rows.Count, ($covered / $rows.Count))
Write-Host "`nFired rules:"
$firedRules | Sort-Object | ForEach-Object { Write-Host "  - $_" }
Write-Host "`nGaps -> candidates for custom detections (M4):"
$rows | Where-Object Detected -eq '--' | ForEach-Object { Write-Host "  - $($_.Technique)  $($_.Name)" }
