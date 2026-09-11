[CmdletBinding()]
param([string]$StateDir)
$ErrorActionPreference = 'Stop'
$application = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$arguments = @()
if ($StateDir) { $arguments += @('--state-dir', [IO.Path]::GetFullPath($StateDir)) }
$arguments += 'doctor'
& (Join-Path $application 'bin\leo-strategy-connector.exe') @arguments
if ($LASTEXITCODE -ne 0) { throw 'Connector doctor failed. Check the architecture and Visual C++ runtime.' }
$engineOutput = '{"operation":"stop","strategy":"MR-v1","first_fill_price":"100","signal_atr":"2"}' | & (Join-Path $application 'bin\strategy-lab.exe')
if ($LASTEXITCODE -ne 0 -or ($engineOutput | ConvertFrom-Json).initial_stop -ne '96.000000') { throw 'Separate quantitative engine offline fixture failed.' }
Write-Host 'Separate quantitative engine synthetic offline fixture passed.'
& (Join-Path $application 'adapter\leo-paper-sdk\leo-paper-sdk.exe') --self-check
if ($LASTEXITCODE -ne 0) { throw 'Bundled Python SDK self-check failed.' }
Write-Host 'Offline checks passed. Broker connection, OS credential writes, market entitlement, paper orders, and control connectivity were not checked.'
