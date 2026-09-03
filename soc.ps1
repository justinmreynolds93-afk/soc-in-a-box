#!/usr/bin/env pwsh
<#
.SYNOPSIS
    SOC-in-a-Box task runner for Windows. Mirrors the Makefile verbs.
.EXAMPLE
    .\soc.ps1 up
    .\soc.ps1 telemetry
    .\soc.ps1 status
#>
param(
    [Parameter(Position = 0)]
    [ValidateSet('help', 'up', 'down', 'restart', 'status', 'logs',
        'telemetry', 'telemetry-down', 'attack', 'attack-down',
        'soar', 'soar-down', 'casemgmt', 'casemgmt-down', 'destroy')]
    [string]$Task = 'help'
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$Project = 'soc-in-a-box'
$Core = @('-f', 'compose/docker-compose.yml')
$Tele = $Core + @('-f', 'compose/compose.telemetry.yml')
$Atk  = $Core + @('-f', 'compose/compose.attack.yml')
$Soar = $Core + @('-f', 'compose/compose.soar.yml')
$Case = $Core + @('-f', 'compose/compose.casemgmt.yml')

function dc { param([string[]]$DcArgs) & docker compose --env-file .env @DcArgs }

switch ($Task) {
    'help' {
        Write-Host @'
SOC-in-a-Box tasks

  up               Start the Elastic core (elasticsearch, kibana, fleet-server)
  down             Stop the core
  restart          Restart the core
  status           Show every lab container
  logs             Tail core logs
  telemetry        Add Suricata + the Linux victim
  telemetry-down   Stop telemetry services
  attack           Spin up Caldera + attacker (on demand)
  attack-down      Stop attack services
  soar             Start n8n
  soar-down        Stop n8n
  casemgmt         Start TheHive + Cortex (~4 GB)
  casemgmt-down    Stop TheHive + Cortex
  destroy          Stop EVERYTHING and delete volumes (DESTRUCTIVE)
'@
    }
    'up'             { dc ($Core + @('up', '-d')) }
    'down'           { dc ($Core + @('down')) }
    'restart'        { dc ($Core + @('down')); dc ($Core + @('up', '-d')) }
    'status'         { dc @('-p', $Project, 'ps') }
    'logs'           { dc ($Core + @('logs', '-f', '--tail=100')) }
    'telemetry'      { dc ($Tele + @('up', '-d')) }
    'telemetry-down' { dc ($Tele + @('stop', 'suricata', 'linux-victim')) }
    'attack'         { dc ($Atk + @('up', '-d')) }
    'attack-down'    { dc ($Atk + @('stop', 'caldera', 'attacker')) }
    'soar'           { dc ($Soar + @('up', '-d')) }
    'soar-down'      { dc ($Soar + @('stop', 'n8n')) }
    'casemgmt'       { dc ($Case + @('up', '-d')) }
    'casemgmt-down'  { dc ($Case + @('stop', 'thehive', 'cortex')) }
    'destroy'        {
        $confirm = Read-Host "This deletes ALL lab data volumes. Type 'destroy' to confirm"
        if ($confirm -eq 'destroy') { dc @('-p', $Project, 'down', '-v', '--remove-orphans') }
        else { Write-Host 'Aborted.' }
    }
}
