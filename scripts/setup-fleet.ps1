#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Reads the Fleet enrollment tokens for the preconfigured victim policies and
    writes them into .env (LINUX_ENROLLMENT_TOKEN / WINDOWS_ENROLLMENT_TOKEN),
    so `make telemetry` can bring up an already-enrollable agent.
.NOTES
    The policies themselves are declared in compose/config/kibana.yml. Fleet
    creates a default enrollment token per policy; this just fetches it.
#>
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

$pw  = (Select-String -Path .env -Pattern '^ELASTIC_PASSWORD=(.+)').Matches.Groups[1].Value
$kbP = (Select-String -Path .env -Pattern '^KIBANA_PORT=(\d+)').Matches.Groups[1].Value
$h   = @{
    Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("elastic:$pw"))
    'kbn-xsrf'    = '1'
}
$kb = "https://localhost:$kbP"

function Wait-Fleet {
    for ($i = 0; $i -lt 60; $i++) {
        try {
            $s = Invoke-RestMethod "$kb/api/fleet/agents/setup" -Headers $h -SkipCertificateCheck
            if ($s.isReady) { return }
        } catch { }
        Start-Sleep 5
    }
    throw "Fleet did not become ready"
}

function Get-EnrollmentToken([string]$policyId) {
    for ($i = 0; $i -lt 30; $i++) {
        $keys = (Invoke-RestMethod "$kb/api/fleet/enrollment_api_keys?kuery=policy_id:$policyId" `
                 -Headers $h -SkipCertificateCheck).items
        $active = $keys | Where-Object active | Select-Object -First 1
        if ($active) { return $active.api_key }
        Start-Sleep 3
    }
    throw "no enrollment token for policy $policyId (is it preconfigured in kibana.yml?)"
}

function Set-EnvVar([string]$key, [string]$value) {
    $lines = Get-Content .env
    if ($lines -match "^$key=") {
        $lines = $lines -replace "^$key=.*", "$key=$value"
    } else {
        $lines += "$key=$value"
    }
    Set-Content -Path .env -Value $lines -Encoding utf8
}

Write-Host "[*] waiting for Fleet"
Wait-Fleet

Write-Host "[*] fetching enrollment tokens"
$linux   = Get-EnrollmentToken 'linux-victim-policy'
$windows = Get-EnrollmentToken 'windows-victim-policy'

Set-EnvVar 'LINUX_ENROLLMENT_TOKEN'   $linux
Set-EnvVar 'WINDOWS_ENROLLMENT_TOKEN' $windows

Write-Host "[+] .env updated"
Write-Host ""
Write-Host "  LINUX_ENROLLMENT_TOKEN   $($linux.Substring(0,12))...  (used by 'make telemetry')"
Write-Host "  WINDOWS_ENROLLMENT_TOKEN $($windows.Substring(0,12))...  (for vm/provision/30-agent.ps1)"
Write-Host ""
Write-Host "next:  .\soc.ps1 telemetry"
