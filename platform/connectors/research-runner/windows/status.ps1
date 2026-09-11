[CmdletBinding()]
param([Parameter(Mandatory)][string]$Config, [string]$Python, [string]$PlatformDir)
. "$PSScriptRoot/common.ps1"
$context = Get-ResearchContext -Config $Config -Python $Python -PlatformDir $PlatformDir
foreach ($dashboard in @($false, $true)) {
    $current = Get-ResearchProcess $context -Dashboard:$dashboard
    $payloads = @(Get-ResearchPayloadProcesses $current)
    $displayStatus = $current.Status
    if (-not $current.Process -and $payloads.Count -gt 0) { $displayStatus = 'orphan_runtime_active' }
    if (-not $dashboard -and -not (Test-ResearchStateAvailable $context) -and $displayStatus -ne 'running') { $displayStatus = 'runtime_active_launcher_missing' }
    [pscustomobject]@{
        component = $(if ($dashboard) { 'dashboard' } else { 'research' })
        status = $displayStatus
        pid = $(if ($current.Record) { $current.Record.pid } else { $null })
        runtime_pids = @($payloads | ForEach-Object Id)
        elapsed_seconds = $(if ($current.Process) { [math]::Floor(([DateTime]::UtcNow - $current.Process.StartTime.ToUniversalTime()).TotalSeconds) } else { $null })
    } | ConvertTo-Json -Compress
    if ($current.Process) { $current.Process.Dispose() }
    foreach ($payload in $payloads) { $payload.Dispose() }
}
# Worker status contains the latest heartbeat and progress; it does not expose raw datasets.
Invoke-ResearchCli $context 'status'
