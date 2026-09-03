# 10-audit.ps1 — Windows audit configuration for the victim VM.
# Enables the event channels detections rely on. Run elevated.
$ErrorActionPreference = 'Stop'

Write-Host '== advanced audit policy'
$subs = @(
    'Process Creation', 'Process Termination', 'Logon', 'Logoff',
    'Special Logon', 'Account Lockout', 'Registry', 'File System',
    'Security Group Management', 'User Account Management',
    'Authentication Policy Change', 'Audit Policy Change', 'Sensitive Privilege Use',
    'Other Object Access Events', 'Detailed File Share', 'Removable Storage'
)
foreach ($s in $subs) {
    auditpol /set /subcategory:"$s" /success:enable /failure:enable | Out-Null
}

Write-Host '== command-line in process-creation events (4688)'
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" `
    /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f | Out-Null

Write-Host '== PowerShell script-block + module + transcription logging'
$psBase = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell'
New-Item -Path "$psBase\ScriptBlockLogging" -Force | Out-Null
Set-ItemProperty -Path "$psBase\ScriptBlockLogging" -Name EnableScriptBlockLogging -Value 1
New-Item -Path "$psBase\ModuleLogging" -Force | Out-Null
Set-ItemProperty -Path "$psBase\ModuleLogging" -Name EnableModuleLogging -Value 1
New-Item -Path "$psBase\ModuleLogging\ModuleNames" -Force | Out-Null
Set-ItemProperty -Path "$psBase\ModuleLogging\ModuleNames" -Name '*' -Value '*'

Write-Host '== raising log sizes'
wevtutil sl Security /ms:1073741824
wevtutil sl 'Microsoft-Windows-PowerShell/Operational' /ms:268435456
wevtutil sl 'Windows PowerShell' /ms:268435456

Write-Host 'audit configuration complete'
