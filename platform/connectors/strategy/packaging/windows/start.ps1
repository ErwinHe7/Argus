[CmdletBinding()]
param([string]$StateDir, [switch]$Once, [ValidateSet('moomoo','ibkr-gateway')][string]$Broker = 'moomoo')
$ErrorActionPreference = 'Stop'
$application = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$arguments = @()
if (-not $StateDir -and $Broker -eq 'ibkr-gateway') { $StateDir = Join-Path $env:LOCALAPPDATA 'Leo\StrategyConnector-IBKR' }
if ($StateDir) { $arguments += @('--state-dir', [IO.Path]::GetFullPath($StateDir)) }
$arguments += 'run'
if ($Once) { $arguments += '--once' }
Write-Host 'Connector running in this terminal. Closing it stops local software protection; pending broker orders remain active.'
& (Join-Path $application 'bin\leo-strategy-connector.exe') @arguments
exit $LASTEXITCODE
