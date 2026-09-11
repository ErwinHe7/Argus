[CmdletBinding()]
param([string]$Python = (Get-Command python.exe -ErrorAction Stop).Source, [switch]$ExerciseOrphan)
# Isolated process-control fixture; no backtests, data downloads, or broker calls.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scripts = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../windows'))
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("Leo research ops smoke " + [Guid]::NewGuid().ToString('N'))
$platform = Join-Path $testRoot 'platform with spaces'
$module = Join-Path $platform 'intraday_quant/src/intraday_quant/strategy_lab'
$state = Join-Path $testRoot 'private state'
$config = Join-Path $testRoot 'research config.json'
$null = New-Item -ItemType Directory -Path $module -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/continuous.py') -Destination (Join-Path $module 'continuous.py')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/monitor.py') -Destination (Join-Path $module 'monitor.py')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/redirector_helper.py') -Destination (Join-Path $module 'redirector_helper.py')
[IO.File]::WriteAllText($config, (@{ state_dir = $state; engine = $Python } | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
$arguments = @{ Config = $config; Python = $Python; PlatformDir = $platform }
$portProbe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$portProbe.Start()
$dashboardPort = $portProbe.LocalEndpoint.Port
$portProbe.Stop()
$savedRecord = $null
try {
    & "$scripts/start.ps1" @arguments -Dashboard -DashboardPort $dashboardPort
    $recordPath = Join-Path $state 'windows-process.json'
    $savedRecord = [IO.File]::ReadAllText($recordPath)
    $record = $savedRecord | ConvertFrom-Json
    & "$scripts/start.ps1" @arguments -Dashboard -DashboardPort $dashboardPort
    $repeat = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
    if ($repeat.pid -ne $record.pid) { throw 'Idempotent start changed the running PID.' }
    $history = Join-Path $state 'journal.fixture'
    [IO.File]::WriteAllText($history, 'retained research history')
    & "$scripts/pause.ps1" @arguments
    & "$scripts/pause.ps1" @arguments
    if (-not (Test-Path -LiteralPath (Join-Path $state 'STOP'))) { throw 'Pause marker missing.' }
    & "$scripts/resume.ps1" @arguments
    & "$scripts/resume.ps1" @arguments
    if (Test-Path -LiteralPath (Join-Path $state 'STOP')) { throw 'Resume did not clear pause.' }
    & "$scripts/status.ps1" @arguments

    # A reused PID or edited metadata must not signal/kill a different process.
    $record.pid = $PID
    [IO.File]::WriteAllText($recordPath, ($record | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
    $rejected = $false
    try { & "$scripts/stop.ps1" @arguments } catch { $rejected = $_.Exception.Message -match 'identity could not be verified' }
    if (-not $rejected) { throw 'Stop accepted mismatched process identity.' }
    if (Test-Path -LiteralPath (Join-Path $state 'SHUTDOWN')) { throw 'Rejected stop still sent shutdown.' }
    [IO.File]::WriteAllText($recordPath, $savedRecord, [Text.UTF8Encoding]::new($false))
    & "$scripts/pause.ps1" @arguments
    & "$scripts/stop.ps1" @arguments -WaitSeconds 5
    & "$scripts/stop.ps1" @arguments -WaitSeconds 5
    if (-not (Test-Path -LiteralPath (Join-Path $state 'STOP'))) { throw 'Stop lost persistent pause.' }
    if ([IO.File]::ReadAllText($history) -ne 'retained research history') { throw 'Run history changed.' }
    $heldLock = [IO.File]::Open((Join-Path $state 'runner.lock'), 'Open', 'ReadWrite', 'ReadWrite')
    $heldLock.Lock(0, 1)
    try {
        $rejected = $false
        try { & "$scripts/start.ps1" @arguments } catch { $rejected = $_.Exception.Message -match 'worker owns state_dir' }
        if (-not $rejected) { throw 'Start accepted an already locked state directory.' }
        if (-not (Test-Path -LiteralPath (Join-Path $state 'SHUTDOWN'))) { throw 'Rejected start lost shutdown intent.' }
    } finally { $heldLock.Unlock(0, 1); $heldLock.Dispose() }
    $previousDetach = $env:LEO_RESEARCH_SMOKE_DETACH
    try {
        if ($ExerciseOrphan) { $env:LEO_RESEARCH_SMOKE_DETACH = '1' }
        & "$scripts/start.ps1" @arguments -Dashboard -DashboardPort $dashboardPort
    } finally { $env:LEO_RESEARCH_SMOKE_DETACH = $previousDetach }
    $savedRecord = [IO.File]::ReadAllText($recordPath)
    if (Test-Path -LiteralPath (Join-Path $state 'SHUTDOWN')) { throw 'Explicit start did not acknowledge prior shutdown.' }
    if (-not (Test-Path -LiteralPath (Join-Path $state 'STOP'))) { throw 'Explicit start lost persistent pause.' }
    if ($ExerciseOrphan) {
        . "$scripts/common.ps1"
        $context = Get-ResearchContext @arguments
        $workerLauncher = Get-ResearchProcess $context
        $monitorLauncher = Get-ResearchProcess $context -Dashboard
        $workerChildren = @(Get-ResearchPayloadProcesses $workerLauncher)
        $monitorChildren = @(Get-ResearchPayloadProcesses $monitorLauncher)
        if ($workerChildren.Count -lt 2 -or $monitorChildren.Count -lt 2) { throw 'Use a real redirector venv to exercise detached orphan runtimes.' }
        # Only isolated fixture launchers are killed; base runtimes intentionally survive.
        $workerLauncher.Process.Kill()
        $monitorLauncher.Process.Kill()
        $null = $workerLauncher.Process.WaitForExit(5000)
        $null = $monitorLauncher.Process.WaitForExit(5000)
        if (@($workerChildren | Where-Object { -not $_.HasExited }).Count -eq 0 -or @($monitorChildren | Where-Object { -not $_.HasExited }).Count -eq 0) { throw 'Fixture did not produce surviving runtime children.' }
        $orphanStatus = (& "$scripts/status.ps1" @arguments | Out-String)
        if ($orphanStatus -notmatch 'runtime_active_launcher_missing' -or $orphanStatus -notmatch 'orphan_runtime_active') { throw 'Status falsely reported orphan runtimes stopped.' }
        $restartRejected = $false
        try { & "$scripts/start.ps1" @arguments -Dashboard -DashboardPort $dashboardPort } catch { $restartRejected = $_.Exception.Message -match 'survived its launcher' }
        if (-not $restartRejected) { throw 'Start failed to recognize surviving runtimes.' }
        $workerLauncher.Process.Dispose()
        $monitorLauncher.Process.Dispose()
    }
    & "$scripts/stop.ps1" @arguments -WaitSeconds 5
    if ($ExerciseOrphan) {
        foreach ($child in @($workerChildren) + @($monitorChildren)) {
            if (-not $child.WaitForExit(5000)) { throw 'Graceful stop orphaned a runtime child.' }
            $child.Dispose()
        }
        $connection = [Net.Sockets.TcpClient]::new()
        $listenerClosed = $false
        try { $connection.Connect('127.0.0.1', $dashboardPort) } catch [Net.Sockets.SocketException] { $listenerClosed = $true }
        finally { $connection.Dispose() }
        if (-not $listenerClosed) { throw 'Monitor left its HTTP port listening.' }
        Write-Output 'PASS: detached-runtime fault injection with real venv survived launcher crashes; graceful stop closed all runtimes and the loopback HTTP listener.'
    }
    & "$scripts/status.ps1" @arguments
    Write-Output "PASS: hidden start, paths with spaces, duplicate start, pause/resume, heartbeat status, PID mismatch refusal, graceful stop, repeated stop, held-lock refusal, restart pause/shutdown intent, history retention. Evidence: $testRoot"
} finally {
    if ($savedRecord) {
        [IO.File]::WriteAllText((Join-Path $state 'windows-process.json'), $savedRecord, [Text.UTF8Encoding]::new($false))
        & "$scripts/stop.ps1" @arguments -WaitSeconds 5
    }
}
