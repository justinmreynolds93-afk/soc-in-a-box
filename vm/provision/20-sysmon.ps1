# 20-sysmon.ps1 - install Sysmon with a community modular config. Run elevated.
$ErrorActionPreference = 'Stop'
$work = Join-Path $env:TEMP 'sysmon'
New-Item -ItemType Directory -Force -Path $work | Out-Null

Write-Host '== downloading Sysmon (Sysinternals)'
Invoke-WebRequest -Uri 'https://download.sysinternals.com/files/Sysmon.zip' `
    -OutFile "$work\Sysmon.zip"
Expand-Archive "$work\Sysmon.zip" -DestinationPath $work -Force

Write-Host '== downloading sysmon-modular config (Olaf Hartong)'
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/olafhartong/sysmon-modular/master/sysmonconfig.xml' `
    -OutFile "$work\sysmonconfig.xml"

$sysmon = Join-Path $work 'Sysmon64.exe'
if (& $sysmon -c 2>$null | Select-String 'not installed') {
    & $sysmon -accepteula -i "$work\sysmonconfig.xml"
} else {
    & $sysmon -c "$work\sysmonconfig.xml"
}

Write-Host '== verifying'
Get-Service Sysmon64 | Format-Table Name, Status
wevtutil sl 'Microsoft-Windows-Sysmon/Operational' /ms:1073741824
Write-Host 'Sysmon installed - events in Microsoft-Windows-Sysmon/Operational'
