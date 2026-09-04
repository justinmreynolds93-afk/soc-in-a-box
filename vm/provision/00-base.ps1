# 00-base.ps1 - baseline prep for the Windows victim VM. Run elevated.
$ErrorActionPreference = 'Stop'

Write-Host '== timezone + basic settings'
Set-TimeZone -Id 'Central Standard Time' -ErrorAction SilentlyContinue

Write-Host '== disable Defender automatic sample submission (keep detections local)'
Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue
Set-MpPreference -MAPSReporting 0 -ErrorAction SilentlyContinue

Write-Host '== enable RDP (lab convenience)'
Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue

Write-Host '== install package managers / tooling'
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
choco install -y git 7zip sysinternals

Write-Host 'base provisioning complete - run 10-audit, 20-sysmon, 30-agent, 40-atomics next'
