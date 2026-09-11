$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'windows\profile.ps1')
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function AssertRejects([scriptblock]$call) { $rejected = $false; try { & $call | Out-Null } catch { $rejected = $true }; Assert $rejected 'Invalid profile was accepted.' }
$moomoo = Get-LeoBrokerProfile
Assert ($moomoo.AdapterArguments -join ' ' -eq '--broker moomoo --security-firm FUTUINC') 'Default moomoo bridge changed.'
Assert ($moomoo.StateDir -eq (Join-Path $env:LOCALAPPDATA 'Leo\StrategyConnector')) 'Existing moomoo state path changed.'
$ibkr = Get-LeoBrokerProfile -Broker ibkr-gateway -EnableIbkrPaper -Account IBKR:DU12345 -GatewayCertificateSha256 ('a' * 64)
Assert ($ibkr.StateDir -ne $moomoo.StateDir) 'Broker profiles share state.'
Assert ($ibkr.AdapterArguments -contains '--enable-paper-execution') 'Explicit opt-in missing.'
Assert ($ibkr.AdapterArguments -contains (Join-Path $ibkr.StateDir 'gateway-orders.sqlite3')) 'Journal is outside the profile.'
AssertRejects { Get-LeoBrokerProfile -Broker ibkr-gateway -Account IBKR:DU12345 -GatewayCertificateSha256 ('a' * 64) }
AssertRejects { Get-LeoBrokerProfile -Broker ibkr-gateway -EnableIbkrPaper -Account IBKR:U12345 -GatewayCertificateSha256 ('a' * 64) }
AssertRejects { Get-LeoBrokerProfile -Broker ibkr-gateway -EnableIbkrPaper -Account IBKR:DU12345 -GatewayCertificateSha256 'invalid' }
AssertRejects { Get-LeoBrokerProfile -Broker ibkr-gateway -EnableIbkrPaper -Account IBKR:DU12345 -GatewayCertificateSha256 ('a' * 64) -GatewayCaFile 'file' }
AssertRejects { Get-LeoBrokerProfile -EnableIbkrPaper }
AssertRejects { Get-LeoBrokerProfile -StateDir relative }
AssertRejects { Get-LeoBrokerProfile -StateDir 'C:relative' }
AssertRejects { Get-LeoBrokerProfile -StateDir '\relative' }
AssertRejects { Get-LeoBrokerProfile -StateDir '\\server\share' }
Write-Output 'PASS: broker profile defaults, isolated state, exact account, explicit paper opt-in, TLS configuration and invalid combinations. No process or broker operation was started.'
