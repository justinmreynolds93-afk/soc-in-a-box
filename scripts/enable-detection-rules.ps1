#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install Elastic's prebuilt detection rules, then enable a curated subset that
    matches the telemetry this lab actually collects (Linux system/auth, network
    traffic, and — once the Windows victim is up — Windows event logs).
.PARAMETER Tags
    Rule tags to include. Default covers Linux + Network + Windows.
.PARAMETER MaxRules
    Safety cap so an 8 GB host is not buried under rule executions.
.EXAMPLE
    .\scripts\enable-detection-rules.ps1
    .\scripts\enable-detection-rules.ps1 -Tags 'OS: Linux','Domain: Network' -MaxRules 60
#>
param(
    [string[]]$Tags = @('OS: Linux', 'Domain: Network', 'OS: Windows'),
    [int]$MaxRules = 90
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

$pw  = (Select-String -Path .env -Pattern '^ELASTIC_PASSWORD=(.+)').Matches.Groups[1].Value
$kbP = (Select-String -Path .env -Pattern '^KIBANA_PORT=(\d+)').Matches.Groups[1].Value
$kb  = "https://localhost:$kbP"
$h   = @{
    Authorization  = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("elastic:$pw"))
    'kbn-xsrf'     = '1'
    'Content-Type' = 'application/json'
}

Write-Host "[*] installing prebuilt rules (this can take a minute)"
try {
    Invoke-RestMethod -Method Put "$kb/api/detection_engine/rules/prepackaged" -Headers $h -SkipCertificateCheck | Out-Null
} catch {
    # newer stacks: internal perform-installation endpoint
    Invoke-RestMethod -Method Post "$kb/internal/detection_engine/prebuilt_rules/installation/_perform" `
        -Headers ($h + @{ 'elastic-api-version' = '1' }) -Body '{"mode":"ALL_RULES"}' -SkipCertificateCheck | Out-Null
}

$status = Invoke-RestMethod "$kb/api/detection_engine/rules/prepackaged/_status" -Headers $h -SkipCertificateCheck
Write-Host "[+] prebuilt rules installed: $($status.rules_installed)"

# ── pick the curated subset ──────────────────────────────────────────────────
$wanted = [System.Collections.Generic.List[string]]::new()
foreach ($tag in $Tags) {
    $page = 1
    do {
        $resp = Invoke-RestMethod "$kb/api/detection_engine/rules/_find?per_page=100&page=$page&filter=alert.attributes.tags:%22$([uri]::EscapeDataString($tag))%22" `
                -Headers $h -SkipCertificateCheck
        foreach ($r in $resp.data) {
            if ($r.type -in 'query', 'eql', 'threshold', 'new_terms' -and -not $r.enabled) {
                if (-not $wanted.Contains($r.id)) { $wanted.Add($r.id) }
            }
        }
        $page++
    } while ($resp.data.Count -eq 100 -and $wanted.Count -lt ($MaxRules * 3))
}

$ids = $wanted | Select-Object -First $MaxRules
Write-Host "[*] enabling $($ids.Count) rules (cap $MaxRules)"

$body = @{ action = 'enable'; ids = $ids } | ConvertTo-Json
$res = Invoke-RestMethod -Method Post "$kb/api/detection_engine/rules/_bulk_action" -Headers $h -Body $body -SkipCertificateCheck
Write-Host "[+] enabled: $($res.attributes.summary.succeeded) / failed: $($res.attributes.summary.failed)"

$enabled = (Invoke-RestMethod "$kb/api/detection_engine/rules/_find?per_page=1&filter=alert.attributes.enabled:true" -Headers $h -SkipCertificateCheck).total
Write-Host "[+] total enabled detection rules: $enabled"
