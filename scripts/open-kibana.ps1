#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Open the Kibana pages worth screenshotting for the README.
.PARAMETER Trust
    Also add the lab's self-signed CA to your CurrentUser Root store so the
    browser stops warning. Removes cleanly:
        Get-ChildItem Cert:\CurrentUser\Root | ? Subject -match 'Elastic' | Remove-Item
.EXAMPLE
    .\scripts\open-kibana.ps1 -Trust
#>
param([switch]$Trust)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

$port = (Select-String -Path .env -Pattern '^KIBANA_PORT=(\d+)').Matches.Groups[1].Value
if (-not $port) { $port = 5601 }

if ($Trust) {
    $ca = Join-Path $env:TEMP 'soc-lab-ca.crt'
    docker cp soc-in-a-box-elasticsearch-1:/usr/share/elasticsearch/config/certs/ca/ca.crt $ca
    Import-Certificate -FilePath $ca -CertStoreLocation Cert:\CurrentUser\Root | Out-Null
    Remove-Item $ca
    Write-Host "[+] lab CA trusted for CurrentUser. Restart the browser."
}

$base = "https://localhost:$port/app"
# Ordered so the tabs open left-to-right in a sensible sequence.
$pages = [ordered]@{
    'fleet-agents' = "$base/fleet/agents"
    'rules'        = "$base/security/rules/management?rulesTable=(source:custom)"
    'discover'     = "$base/discover"
    'alerts'       = "$base/security/alerts"
}
foreach ($k in $pages.Keys) {
    Write-Host "  $k  ->  $($pages[$k])"
    Start-Process $pages[$k]
    Start-Sleep 1
}
Write-Host ""
Write-Host "user: elastic   password: $((Select-String -Path .env -Pattern '^ELASTIC_PASSWORD=(.+)').Matches.Groups[1].Value)"
Write-Host "Screenshot into docs/img/ per docs/img/README.md."
