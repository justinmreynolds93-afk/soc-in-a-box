#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install Elastic's prebuilt detection rules, then enable only the ones whose
    index patterns overlap the telemetry this lab actually ingests. Most prebuilt
    Linux rules target Elastic Defend / auditd_manager / EDR indices we do not
    have; enabling them just produces "partial failure" noise. This keeps the
    enabled set honest - see docs/detection-coverage.md.
.PARAMETER IncludeWindows
    Also enable Windows Sysmon/event-log rules (only useful once the Windows
    victim VM is enrolled).
.PARAMETER MaxRules
    Safety cap for an 8 GB host.
#>
param(
    [switch]$IncludeWindows,
    [int]$MaxRules = 120
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

# index-pattern prefixes we actually ingest (extend as integrations are added)
$havePatterns = @('logs-system.', 'logs-network_traffic.', 'metrics-system.', 'logs-elastic_agent.')
if ($IncludeWindows) {
    $havePatterns += @('logs-windows.', 'logs-system.security', 'winlogbeat-')
}

function RuleIsCompatible($rule) {
    if (-not $rule.index) { return $false }         # ES|QL / ML rules - skip for now
    foreach ($idx in $rule.index) {
        foreach ($p in $havePatterns) {
            if ($idx.StartsWith($p) -or $idx.StartsWith($p.TrimEnd('.'))) { return $true }
        }
    }
    return $false
}

Write-Host "[*] installing prebuilt rules"
try {
    Invoke-RestMethod -Method Put "$kb/api/detection_engine/rules/prepackaged" -Headers $h -SkipCertificateCheck | Out-Null
} catch {
    Invoke-RestMethod -Method Post "$kb/internal/detection_engine/prebuilt_rules/installation/_perform" `
        -Headers ($h + @{ 'elastic-api-version' = '1' }) -Body '{"mode":"ALL_RULES"}' -SkipCertificateCheck | Out-Null
}
$status = Invoke-RestMethod "$kb/api/detection_engine/rules/prepackaged/_status" -Headers $h -SkipCertificateCheck
Write-Host "[+] prebuilt rules installed: $($status.rules_installed)"

# walk every prebuilt rule, split by compatibility
$enable = [System.Collections.Generic.List[string]]::new()
$disable = [System.Collections.Generic.List[string]]::new()
$page = 1
do {
    $resp = Invoke-RestMethod "$kb/api/detection_engine/rules/_find?per_page=200&page=$page&filter=alert.attributes.tags:%22__internal_immutable:true%22" -Headers $h -SkipCertificateCheck
    if (-not $resp.data) {
        $resp = Invoke-RestMethod "$kb/api/detection_engine/rules/_find?per_page=200&page=$page" -Headers $h -SkipCertificateCheck
    }
    foreach ($r in $resp.data) {
        if ($r.immutable -ne $true) { continue }
        if ($r.type -notin 'query', 'eql', 'threshold', 'new_terms') { continue }
        if (RuleIsCompatible $r) { $enable.Add($r.id) } elseif ($r.enabled) { $disable.Add($r.id) }
    }
    $page++
} while ($resp.data.Count -eq 200)

$enable = $enable | Select-Object -First $MaxRules
Write-Host "[*] compatible with our telemetry: $($enable.Count)   (disabling $($disable.Count) incompatible)"

function Bulk($action, $ids) {
    for ($i = 0; $i -lt $ids.Count; $i += 100) {
        $chunk = $ids[$i..([Math]::Min($i + 99, $ids.Count - 1))]
        $body = @{ action = $action; ids = @($chunk) } | ConvertTo-Json
        Invoke-RestMethod -Method Post "$kb/api/detection_engine/rules/_bulk_action" -Headers $h -Body $body -SkipCertificateCheck | Out-Null
    }
}
if ($disable.Count) { Bulk 'disable' $disable }
if ($enable.Count)  { Bulk 'enable'  $enable }

# Second pass: after a few runs, disable any prebuilt still hard-failing on a
# missing field (ES|QL rules referencing columns our telemetry does not produce).
Start-Sleep 45
$stillFailing = @()
$page = 1
do {
    $resp = Invoke-RestMethod "$kb/api/detection_engine/rules/_find?per_page=200&page=$page&filter=alert.attributes.enabled:true" -Headers $h -SkipCertificateCheck
    foreach ($r in $resp.data) {
        if ($r.immutable -eq $true -and $r.execution_summary.last_execution.status -eq 'failed' `
            -and $r.execution_summary.last_execution.message -match 'verification_exception|Unknown column') {
            $stillFailing += $r.id
        }
    }
    $page++
} while ($resp.data.Count -eq 200)
if ($stillFailing.Count) {
    Write-Host "[*] disabling $($stillFailing.Count) prebuilt rules that fail on missing fields"
    Bulk 'disable' $stillFailing
}

Start-Sleep 3
$en = (Invoke-RestMethod "$kb/api/detection_engine/rules/_find?per_page=1&filter=alert.attributes.enabled:true" -Headers $h -SkipCertificateCheck).total
Write-Host "[+] enabled detection rules now: $en"
Write-Host "    (run scripts/deploy-detections.ps1 for the custom rules tuned to this telemetry)"
