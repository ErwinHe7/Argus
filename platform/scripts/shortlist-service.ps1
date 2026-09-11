[CmdletBinding()]
param(
    [ValidateSet('Start','Status','Pause','Resume','Stop')][string]$Action = 'Status',
    [string]$Config = (Join-Path $PSScriptRoot '../.quant-runtime/shortlist-publisher/config.json'),
    [string]$Python = (Join-Path $PSScriptRoot '../.quant-runtime/strategy-research-venv/Scripts/python.exe'),
    [string]$TokenFile = (Join-Path $PSScriptRoot '../.quant-runtime/shortlist-publisher/publish-token.txt')
)
$ErrorActionPreference = 'Stop'
$taskConfig = (Resolve-Path -LiteralPath $Config).Path
$taskPython = (Resolve-Path -LiteralPath $Python).Path
$taskPlatform = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$taskPriorPath = $env:PYTHONPATH
$taskPriorToken = $env:LEO_SHORTLIST_PUBLISH_TOKEN
try {
    $env:PYTHONPATH = Join-Path $taskPlatform 'intraday_quant/src'
    if ($Action -ne 'Start') {
        & $taskPython -m intraday_quant.shortlist_service $Action.ToLowerInvariant() --config $taskConfig
        if ($LASTEXITCODE -ne 0) { throw 'Shortlist command failed; retained state was not cleared.' }
        return
    }
    # The actual worker owns the OS lock. Never kill a saved PID or delete its
    # lock to force a restart. Probe and validate before acknowledging shutdown.
    $taskProbe = @'
import sys
from pathlib import Path
from intraday_quant.shortlist_service import load_config, exclusive_lock
c=load_config(Path(sys.argv[1]))
with exclusive_lock(c.state_dir):
    (c.state_dir/'SHUTDOWN').unlink(missing_ok=True)
print(c.state_dir)
'@
    $taskState = & $taskPython -c $taskProbe $taskConfig
    if ($LASTEXITCODE -ne 0) { throw 'Another publisher is active or the config is invalid. No new worker was launched.' }
    $taskState = [string]$taskState
    $taskSettings = Get-Content -LiteralPath $taskConfig -Raw | ConvertFrom-Json
    if ($taskSettings.publish_url) {
        if (-not (Test-Path -LiteralPath $TokenFile -PathType Leaf)) { throw 'The private publisher token is missing.' }
        $env:LEO_SHORTLIST_PUBLISH_TOKEN = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $TokenFile).Path).Trim()
    } else {
        Remove-Item Env:LEO_SHORTLIST_PUBLISH_TOKEN -ErrorAction SilentlyContinue
    }
    $taskLogs = Join-Path $taskState 'logs'
    [IO.Directory]::CreateDirectory($taskLogs) | Out-Null
    $taskStamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff')
    $taskArgs = '-m intraday_quant.shortlist_service run --config "' + $taskConfig + '"'
    $taskProcess = Start-Process -FilePath $taskPython -ArgumentList $taskArgs -WorkingDirectory $taskPlatform -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskLogs "$taskStamp.stdout.log") -RedirectStandardError (Join-Path $taskLogs "$taskStamp.stderr.log")
    @{ launcher_pid=$taskProcess.Id; started_at=[DateTime]::UtcNow.ToString('o'); config=$taskConfig } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskState 'windows-launch.json') -Encoding utf8
    Write-Output 'Shortlist publisher launched. Use -Action Status to inspect its actual heartbeat and source date.'
} finally {
    $env:PYTHONPATH = $taskPriorPath
    $env:LEO_SHORTLIST_PUBLISH_TOKEN = $taskPriorToken
}
