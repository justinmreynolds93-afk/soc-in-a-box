# 40-atomics.ps1 - install Invoke-AtomicRedTeam + the atomics folder. Run elevated.
# Executes NOTHING. Tests are launched from attack/atomic/ against this VM only.
$ErrorActionPreference = 'Stop'

Write-Host '== Defender exclusion for the atomics folder (lab VM only)'
# Many atomics drop EICAR-style test files; without this they cannot stage.
Add-MpPreference -ExclusionPath 'C:\AtomicRedTeam' -ErrorAction SilentlyContinue

Write-Host '== installing Invoke-AtomicRedTeam'
Install-Module -Name Invoke-AtomicRedTeam -Scope AllUsers -Force
Import-Module Invoke-AtomicRedTeam -Force

Write-Host '== fetching atomics'
Install-AtomicRedTeam -getAtomics -Force -InstallPath 'C:\AtomicRedTeam'

Write-Host 'ready. Example (run from attack/atomic/):'
Write-Host '  Invoke-AtomicTest T1059.001 -TestNumbers 1 -PathToAtomicsFolder C:\AtomicRedTeam\atomics'
