[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Config,
    [string]$Python,
    [string]$PlatformDir,
    [switch]$Dashboard,
    [ValidateRange(1024, 65535)][int]$DashboardPort = 3119
)
. "$PSScriptRoot/common.ps1"
$context = Get-ResearchContext -Config $Config -Python $Python -PlatformDir $PlatformDir
$engine = Resolve-ResearchPath ([string]$context.Settings.engine) -MustExist
$control = Enter-ResearchControl $context
try {
    Initialize-ResearchState $context
    $research = Start-ResearchProcess $context
    Write-Output "Research PID $($research.pid); state: $($context.State)"
    if ($Dashboard) {
        $monitor = Start-ResearchProcess $context -Dashboard -Port $DashboardPort
        Write-Output "Local dashboard PID $($monitor.pid): http://127.0.0.1:$DashboardPort"
    }
} finally { $control.ReleaseMutex(); $control.Dispose() }
