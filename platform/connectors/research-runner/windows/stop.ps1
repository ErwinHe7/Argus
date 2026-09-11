[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Config,
    [string]$Python,
    [string]$PlatformDir,
    [ValidateRange(1, 60)][int]$WaitSeconds = 30
)
. "$PSScriptRoot/common.ps1"
$context = Get-ResearchContext -Config $Config -Python $Python -PlatformDir $PlatformDir
$control = Enter-ResearchControl $context
try {
    # Verify both identities before changing either component. Never kill a bare saved PID.
    $research = Get-ResearchProcess $context
    $monitor = Get-ResearchProcess $context -Dashboard
    $researchPayloads = @(Get-ResearchPayloadProcesses $research)
    $monitorPayloads = @(Get-ResearchPayloadProcesses $monitor)
    # A missing launcher is not proof that its runtime exited. The scoped CLI
    # validates the config and writes shutdown even for an orphan/untracked worker.
    Invoke-ResearchCli $context 'stop'
    $researchProcesses = @($researchPayloads)
    if ($research.Process) { $researchProcesses += $research.Process }
    if (-not (Wait-ResearchProcesses -Processes $researchProcesses -Seconds $WaitSeconds)) {
        throw "Research shutdown requested; the current replay is still draining. Run status, then stop again. State and journal are preserved."
    }
    $lockDeadline = [DateTime]::UtcNow.AddSeconds($WaitSeconds)
    while (-not (Test-ResearchStateAvailable $context)) {
        if ([DateTime]::UtcNow -ge $lockDeadline) {
            throw 'Research shutdown requested, but a runtime still owns runner.lock. Its process identity is unknown; stopped status cannot be confirmed.'
        }
        Start-Sleep -Milliseconds 100
    }
    if ($monitor.Record) {
        # Let the actual HTTP process exit, then its venv launcher. Killing only
        # the launcher could leave the loopback listener orphaned.
        [IO.File]::WriteAllText((Join-Path $context.State 'MONITOR_SHUTDOWN'), '', [Text.UTF8Encoding]::new($false))
        $monitorProcesses = @($monitorPayloads)
        if ($monitor.Process) { $monitorProcesses += $monitor.Process }
        if (-not (Wait-ResearchProcesses -Processes $monitorProcesses -Seconds 10)) {
            throw 'Monitor shutdown requested but its launcher/runtime is still active. Update an older monitor before retrying; no process was forcibly killed.'
        }
    }
    Write-Output 'Research and tracked local dashboard are stopped. Run history and logs are preserved.'
} finally {
    if (Test-Path variable:research) { if ($research.Process) { $research.Process.Dispose() } }
    if (Test-Path variable:monitor) { if ($monitor.Process) { $monitor.Process.Dispose() } }
    if (Test-Path variable:researchPayloads) { foreach ($payload in $researchPayloads) { $payload.Dispose() } }
    if (Test-Path variable:monitorPayloads) { foreach ($payload in $monitorPayloads) { $payload.Dispose() } }
    $control.ReleaseMutex(); $control.Dispose()
}
