#!/usr/bin/env pwsh
<#
.SYNOPSIS
    End-to-end health check for the lab. Prints a PASS/FAIL line per component.
.EXAMPLE
    .\scripts\healthcheck.ps1
#>
$ErrorActionPreference = 'Continue'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

$pw   = (Select-String -Path .env -Pattern '^ELASTIC_PASSWORD=(.+)').Matches.Groups[1].Value
$esP  = (Select-String -Path .env -Pattern '^ES_PORT=(\d+)').Matches.Groups[1].Value
$kbP  = (Select-String -Path .env -Pattern '^KIBANA_PORT=(\d+)').Matches.Groups[1].Value
$fsP  = (Select-String -Path .env -Pattern '^FLEET_SERVER_PORT=(\d+)').Matches.Groups[1].Value
$auth = @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("elastic:$pw")) }
$xsrf = $auth + @{ 'kbn-xsrf' = '1' }

$pass = 0; $fail = 0
function Check($name, [scriptblock]$test) {
    try {
        $r = & $test
        if ($r) { Write-Host ("  PASS  {0} -> {1}" -f $name, $r) -ForegroundColor Green; $script:pass++ }
        else    { Write-Host ("  FAIL  {0}" -f $name) -ForegroundColor Red; $script:fail++ }
    } catch {
        Write-Host ("  FAIL  {0} -> {1}" -f $name, $_.Exception.Message) -ForegroundColor Red; $script:fail++
    }
}

Write-Host "`nSOC-in-a-Box health check`n"

Check "Elasticsearch cluster" {
    $c = Invoke-RestMethod "https://localhost:$esP/_cluster/health" -Headers $auth -SkipCertificateCheck
    if ($c.status -in 'green', 'yellow') { "status=$($c.status) nodes=$($c.number_of_nodes)" }
}
Check "Kibana" {
    $s = Invoke-RestMethod "https://localhost:$kbP/api/status" -Headers $auth -SkipCertificateCheck
    if ($s.status.overall.level -eq 'available') { "v$($s.version.number)" }
}
Check "Fleet Server" {
    $s = Invoke-RestMethod "https://localhost:$fsP/api/status" -SkipCertificateCheck
    if ($s.status -eq 'HEALTHY') { $s.name }
}
Check "Fleet agents online" {
    $a = (Invoke-RestMethod "https://localhost:$kbP/api/fleet/agents?showInactive=false" -Headers $auth -SkipCertificateCheck).items
    $online = ($a | Where-Object status -eq 'online').Count
    if ($online -ge 1) { "$online online" }
}
Check "Detection engine" {
    $d = Invoke-RestMethod "https://localhost:$kbP/api/detection_engine/rules/_find?per_page=1" -Headers $xsrf -SkipCertificateCheck
    "rules installed: $($d.total)"
}
Check "Data streams" {
    $ds = Invoke-RestMethod "https://localhost:$esP/_data_stream" -Headers $auth -SkipCertificateCheck
    if ($ds.data_streams.Count -gt 0) { "$($ds.data_streams.Count) streams" }
}

Write-Host "`n$pass passed, $fail failed`n"
exit ([int]($fail -gt 0))
