#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Instrument THIS Windows machine as the lab's Windows telemetry source:
    Sysmon + a curated config, the audit settings the detections need, and a
    Fleet-enrolled Elastic Agent on the "Windows Victim Policy".

    TELEMETRY ONLY. No attack tooling is installed and nothing in attack/ is
    ever pointed at this host - see docs/scope.md. This just makes the 5
    Windows custom rules (and a chunk of prebuilts) run against real data.

.NOTES
    Run from an ELEVATED PowerShell:  right-click > Run as administrator
    then:  cd C:\Users\JReyn\dev\soc-in-a-box ; .\scripts\install-windows-telemetry.ps1

    Uninstall:
      & 'C:\Program Files\Elastic\Agent\elastic-agent.exe' uninstall
      & "$env:TEMP\sysmon\Sysmon64.exe" -u force
      # optionally revert audit: auditpol /clear  (or set the subcategories back)
#>
[CmdletBinding()]
param(
    [string]$FleetUrl = 'https://host.docker.internal:8220',
    [string]$EnvFile
)
$ErrorActionPreference = 'Stop'
# Elevation is enforced by "#Requires -RunAsAdministrator" at the top of the file.

# -- read the lab .env -------------------------------------------------------
if (-not $EnvFile) { $EnvFile = Join-Path (Split-Path $PSScriptRoot -Parent) '.env' }
if (-not (Test-Path $EnvFile)) { throw ".env not found at $EnvFile" }
$env = @{}
Get-Content $EnvFile | Where-Object { $_ -match '^\s*[^#].*=' } | ForEach-Object {
    $k, $v = $_ -split '=', 2; $env[$k.Trim()] = $v.Trim()
}
$version = $env['STACK_VERSION']; if (-not $version) { $version = '8.19.20' }
$token   = $env['WINDOWS_ENROLLMENT_TOKEN']
if (-not $token) { throw "WINDOWS_ENROLLMENT_TOKEN missing from .env - run scripts/setup-fleet.ps1 first" }

function Step($m) { Write-Host "`n== $m" -ForegroundColor Cyan }
$work = Join-Path $env:TEMP 'soc-win'
New-Item -ItemType Directory -Force -Path $work | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'   # Windows PowerShell IWR is ~10x slower with the progress bar

# Fast download: curl.exe (bundled since Win10 1803) saturates the link;
# Invoke-WebRequest in Windows PowerShell does not.
function Get-File($url, $out) {
    $curl = "$env:SystemRoot\System32\curl.exe"
    if (Test-Path $curl) { & $curl -sSL --fail -o $out $url; if ($LASTEXITCODE) { throw "download failed: $url" } }
    else { Invoke-WebRequest $url -OutFile $out -UseBasicParsing }
}

# -- 1. Sysmon ---------------------------------------------------------------
Step 'Sysmon'
if (Get-Service Sysmon64 -ErrorAction SilentlyContinue) {
    Write-Host '   already installed - updating config only'
} else {
    Get-File 'https://download.sysinternals.com/files/Sysmon.zip' "$work\Sysmon.zip"
    Expand-Archive "$work\Sysmon.zip" -DestinationPath $work -Force
}
Get-File 'https://raw.githubusercontent.com/olafhartong/sysmon-modular/master/sysmonconfig.xml' "$work\sysmonconfig.xml"
$sysmon = Join-Path $work 'Sysmon64.exe'
if (Get-Service Sysmon64 -ErrorAction SilentlyContinue) { & $sysmon -c "$work\sysmonconfig.xml" }
else { & $sysmon -accepteula -i "$work\sysmonconfig.xml" }
wevtutil sl 'Microsoft-Windows-Sysmon/Operational' /ms:1073741824
Write-Host '   Sysmon events -> Microsoft-Windows-Sysmon/Operational'

# -- 2. audit settings the rules need (minimal, not the whole policy) --------
Step 'Audit policy + PowerShell logging'
foreach ($sub in 'User Account Management', 'Security Group Management', 'Process Creation') {
    auditpol /set /subcategory:"$sub" /success:enable /failure:enable | Out-Null
}
reg add 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' `
    /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f | Out-Null
$sbl = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
New-Item -Path $sbl -Force | Out-Null
Set-ItemProperty -Path $sbl -Name EnableScriptBlockLogging -Value 1
wevtutil sl 'Microsoft-Windows-PowerShell/Operational' /ms:268435456
wevtutil sl Security /ms:536870912
Write-Host '   4688 w/ cmdline, 4720/4732, and PS 4104 enabled'

# -- 3. Elastic Agent --------------------------------------------------------
Step "Elastic Agent $version -> $FleetUrl"
if (Test-Path 'C:\Program Files\Elastic\Agent\elastic-agent.exe') {
    Write-Host '   agent already installed; re-enrolling'
    & 'C:\Program Files\Elastic\Agent\elastic-agent.exe' enroll --url=$FleetUrl --enrollment-token=$token --insecure --force
} else {
    $pkg = "elastic-agent-$version-windows-x86_64"
    if (-not (Test-Path "$work\$pkg.zip")) {
        Write-Host "   downloading $pkg.zip (~600 MB)"
        Get-File "https://artifacts.elastic.co/downloads/beats/elastic-agent/$pkg.zip" "$work\$pkg.zip"
    }
    if (-not (Test-Path "$work\$pkg\elastic-agent.exe")) { Expand-Archive "$work\$pkg.zip" -DestinationPath $work -Force }
    Push-Location "$work\$pkg"
    & '.\elastic-agent.exe' install --url=$FleetUrl --enrollment-token=$token --insecure --non-interactive
    Pop-Location
}

Step 'Status'
Start-Sleep 5
& 'C:\Program Files\Elastic\Agent\elastic-agent.exe' status
Write-Host "`n[+] done. In Kibana: Fleet > Agents should show this host on 'Windows Victim Policy'."
Write-Host "    Then: .\scripts\enable-detection-rules.ps1 -IncludeWindows   (enables the Windows prebuilts too)"
