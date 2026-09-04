#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build a MITRE ATT&CK Navigator layer from every enabled detection rule
    (prebuilt + custom), scored by how many rules cover each technique.
    Output: docs/attack-navigator-layer.json  (import at mitre-attack.github.io/attack-navigator)
#>
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

$pw  = (Select-String -Path .env -Pattern '^ELASTIC_PASSWORD=(.+)').Matches.Groups[1].Value
$kbP = (Select-String -Path .env -Pattern '^KIBANA_PORT=(\d+)').Matches.Groups[1].Value
$h   = @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("elastic:$pw")); 'kbn-xsrf' = '1' }
$kb  = "https://localhost:$kbP"

$techniques = @{}   # id -> @{ count; custom }
$page = 1
do {
    $resp = Invoke-RestMethod "$kb/api/detection_engine/rules/_find?per_page=200&page=$page&filter=alert.attributes.enabled:true" -Headers $h -SkipCertificateCheck
    foreach ($rule in $resp.data) {
        $isCustom = $rule.tags -contains 'SOC-in-a-Box'
        foreach ($t in $rule.threat) {
            foreach ($tech in $t.technique) {
                foreach ($id in @($tech.id) + @($tech.subtechnique.id)) {
                    if (-not $id) { continue }
                    if (-not $techniques[$id]) { $techniques[$id] = @{ count = 0; custom = $false } }
                    $techniques[$id].count++
                    if ($isCustom) { $techniques[$id].custom = $true }
                }
            }
        }
    }
    $page++
} while ($resp.data.Count -eq 200)

$max = ($techniques.Values | ForEach-Object { $_.count } | Measure-Object -Maximum).Maximum
$layerTechniques = foreach ($id in $techniques.Keys) {
    $t = $techniques[$id]
    [ordered]@{
        techniqueID = $id
        score       = $t.count
        comment     = "$($t.count) rule(s)$(if ($t.custom) { ' - incl. custom' })"
        color       = if ($t.custom) { '#7b2fbf' } else { $null }
        enabled     = $true
    }
}

$layer = [ordered]@{
    name        = 'SOC-in-a-Box detection coverage'
    description  = "Generated $(Get-Date -Format o) from enabled Elastic detection rules"
    domain      = 'enterprise-attack'
    versions    = [ordered]@{ attack = '15'; navigator = '4.9.5'; layer = '4.5' }
    sorting     = 3
    hideDisabled = $false
    techniques  = @($layerTechniques)
    gradient    = [ordered]@{ colors = @('#e8f0ff', '#66b1ff', '#0b3d91'); minValue = 0; maxValue = [Math]::Max($max, 1) }
    legendItems = @(
        @{ label = 'purple = covered by a custom rule'; color = '#7b2fbf' }
    )
    metadata    = @(
        @{ name = 'techniques covered'; value = "$($techniques.Count)" }
        @{ name = 'custom rules contribute'; value = "$(($techniques.Values | Where-Object custom).Count)" }
    )
}

$out = 'docs/attack-navigator-layer.json'
$layer | ConvertTo-Json -Depth 12 | Set-Content $out -Encoding utf8
Write-Host "[+] $out - $($techniques.Count) techniques, max depth $max"
