[CmdletBinding()]
param([Parameter(Mandatory)][string]$Config, [string]$Python, [string]$PlatformDir)
. "$PSScriptRoot/common.ps1"
$context = Get-ResearchContext -Config $Config -Python $Python -PlatformDir $PlatformDir
$control = Enter-ResearchControl $context
try { Invoke-ResearchCli $context 'pause' }
finally { $control.ReleaseMutex(); $control.Dispose() }
