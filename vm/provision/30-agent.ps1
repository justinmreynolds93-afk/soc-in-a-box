# 30-agent.ps1 - install and Fleet-enroll the Elastic Agent on the Windows victim.
# Run elevated. Params come from the lab .env / Fleet UI.
param(
    [Parameter(Mandatory)] [string]$FleetUrl,          # e.g. https://<host-ip>:8220
    [Parameter(Mandatory)] [string]$EnrollmentToken,   # from Fleet > Enrollment tokens
    [string]$Version = '8.19.20',
    [string]$CaCertPath                                 # optional: lab CA .crt for TLS verify
)
$ErrorActionPreference = 'Stop'
$work = Join-Path $env:TEMP 'elastic-agent'
New-Item -ItemType Directory -Force -Path $work | Out-Null

$pkg = "elastic-agent-$Version-windows-x86_64"
$zip = Join-Path $work "$pkg.zip"
Write-Host "== downloading $pkg"
Invoke-WebRequest -Uri "https://artifacts.elastic.co/downloads/beats/elastic-agent/$pkg.zip" -OutFile $zip
Expand-Archive $zip -DestinationPath $work -Force

$installArgs = @(
    'install', '--non-interactive',
    '--url', $FleetUrl,
    '--enrollment-token', $EnrollmentToken
)
if ($CaCertPath) { $installArgs += @('--certificate-authorities', $CaCertPath) }
else { $installArgs += '--insecure' }   # self-signed lab Fleet Server without the CA on this host

Write-Host '== enrolling'
Push-Location (Join-Path $work $pkg)
& '.\elastic-agent.exe' @installArgs
Pop-Location

& 'C:\Program Files\Elastic\Agent\elastic-agent.exe' status
Write-Host 'agent enrolled - check Fleet > Agents'
