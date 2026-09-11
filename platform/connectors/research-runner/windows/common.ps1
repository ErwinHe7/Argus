# Shared helpers for this research runner only. No broker credential access.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ResearchPath {
    param([Parameter(Mandatory)][string]$Path, [switch]$MustExist)
    if (-not [IO.Path]::IsPathRooted($Path)) { throw "An absolute path is required: $Path" }
    $full = [IO.Path]::GetFullPath($Path)
    if ($MustExist) { $full = (Resolve-Path -LiteralPath $full -ErrorAction Stop).ProviderPath }
    return $full
}

function Get-ResearchContext {
    param([string]$Config, [string]$Python, [string]$PlatformDir)
    $configPath = Resolve-ResearchPath $Config -MustExist
    $settings = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    $state = Resolve-ResearchPath ([string]$settings.state_dir)
    if ($state.TrimEnd('\') -eq [IO.Path]::GetPathRoot($state).TrimEnd('\')) {
        throw 'state_dir must be a dedicated research directory, not a drive root.'
    }
    $recordPath = Join-Path $state 'windows-process.json'
    $saved = if (Test-Path -LiteralPath $recordPath) { Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json } else { $null }
    if (-not $PlatformDir) {
        $PlatformDir = if ($saved) { [string]$saved.platform_dir } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..')) }
    }
    if (-not $Python) {
        $Python = if ($saved) { [string]$saved.python } else { (Get-Command python.exe -ErrorAction Stop).Source }
    }
    $platform = Resolve-ResearchPath $PlatformDir -MustExist
    $source = Join-Path $platform 'intraday_quant/src'
    if (-not (Test-Path -LiteralPath (Join-Path $source 'intraday_quant/strategy_lab/continuous.py'))) {
        throw "Continuous research module not found under $source"
    }
    return [pscustomobject]@{
        Config = $configPath; Settings = $settings; State = $state
        Python = (Resolve-ResearchPath $Python -MustExist); Platform = $platform
        Source = $source; Record = $recordPath; MonitorRecord = (Join-Path $state 'windows-monitor-process.json')
    }
}

function Enter-ResearchControl {
    param($Context)
    # Serializes competing start/stop invocations for the same state directory.
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $digest = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Context.State.ToLowerInvariant()))).Replace('-', '') }
    finally { $sha.Dispose() }
    $mutex = [Threading.Mutex]::new($false, "Local\LeoResearch-$digest")
    try { $acquired = $mutex.WaitOne(10000) } catch [Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) { $mutex.Dispose(); throw 'Another research control command is active; retry shortly.' }
    return $mutex
}

function Initialize-ResearchState {
    param($Context)
    if (-not (Test-Path -LiteralPath $Context.State)) {
        $null = New-Item -ItemType Directory -Path $Context.State
        $acl = Get-Acl -LiteralPath $Context.State
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User, [Security.Principal.SecurityIdentifier]::new('S-1-5-18'))) {
            $rule = [Security.AccessControl.FileSystemAccessRule]::new($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            $acl.AddAccessRule($rule)
        }
        Set-Acl -LiteralPath $Context.State -AclObject $acl
    }
    $null = New-Item -ItemType Directory -Path (Join-Path $Context.State 'logs') -Force
}

function Write-ResearchJson {
    param([string]$Path, $Value)
    $temporary = "$Path.$([Guid]::NewGuid().ToString('N')).tmp"
    [IO.File]::WriteAllText($temporary, ($Value | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Get-ResearchProcess {
    param($Context, [switch]$Dashboard)
    $path = if ($Dashboard) { $Context.MonitorRecord } else { $Context.Record }
    if (-not (Test-Path -LiteralPath $path)) { return [pscustomobject]@{ Status = 'not_started'; Process = $null; Record = $null } }
    $record = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($record.config -ine $Context.Config -or $record.state_dir -ine $Context.State) {
        throw "Process metadata config/state mismatch at $path. No process was changed."
    }
    $expectedModule = if ($Dashboard) { 'intraday_quant.strategy_lab.monitor' } else { 'intraday_quant.strategy_lab.continuous' }
    $expectedArguments = if ($Dashboard) { "-m $expectedModule --config `"$($Context.Config)`" --port $([int]$record.port)" } else { "-m $expectedModule run --config `"$($Context.Config)`"" }
    $expectedCommands = @("`"$($Context.Python)`" $expectedArguments", "$($Context.Python) $expectedArguments")
    if ($record.python -ine $Context.Python -or $record.module -cne $expectedModule -or
        $expectedCommands -cnotcontains $record.command_line) {
        throw "Process metadata command/config could not be verified at $path. No process was changed."
    }
    $process = Get-Process -Id ([int]$record.pid) -ErrorAction SilentlyContinue
    if (-not $process) { return [pscustomobject]@{ Status = 'stopped'; Process = $null; Record = $record } }
    # Open a process handle before checking identity; PID reuse cannot retarget it.
    $null = $process.Handle
    $native = Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$record.pid)"
    if (-not $native -or $process.StartTime.ToUniversalTime().Ticks.ToString() -ne [string]$record.start_ticks -or
        $native.ExecutablePath -ine $record.executable -or $record.python -ine $Context.Python -or
        $record.module -cne $expectedModule -or $native.CommandLine -cne $record.command_line -or
        $expectedCommands -cnotcontains $native.CommandLine) {
        $process.Dispose()
        throw "PID $($record.pid) identity could not be verified. No process was changed; inspect $path."
    }
    return [pscustomobject]@{ Status = 'running'; Process = $process; Record = $record }
}

function Invoke-ResearchCli {
    param($Context, [ValidateSet('status', 'pause', 'resume', 'stop')][string]$Action)
    $previousPath = $env:PYTHONPATH
    try {
        $env:PYTHONPATH = $Context.Source
        $result = & $Context.Python -m intraday_quant.strategy_lab.continuous $Action --config $Context.Config
        if ($LASTEXITCODE -ne 0) { throw "Research $Action failed with exit code $LASTEXITCODE." }
        return $result
    } finally { $env:PYTHONPATH = $previousPath }
}

function Get-ResearchPayloadProcesses {
    param($Current)
    if (-not $Current.Record) { return }
    # A Windows venv redirector may own the real Python runtime as a child.
    # Pin runtimes with this exact module/config command, not consoles or arbitrary
    # descendants. Match command identity independently of ParentProcessId so an
    # intermediate redirector exit cannot hide a surviving runtime. No kill is used.
    $children = Get-CimInstance Win32_Process -Filter "Name = 'python.exe' OR Name = 'pythonw.exe'"
    foreach ($child in $children) {
        if ($child.ProcessId -eq $Current.Record.pid -or $child.CommandLine -cne $Current.Record.command_line) { continue }
        $payload = Get-Process -Id ([int]$child.ProcessId) -ErrorAction SilentlyContinue
        if (-not $payload) { continue }
        $null = $payload.Handle
        $verified = Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$child.ProcessId)"
        if (-not $verified -or $verified.CreationDate -ne $child.CreationDate -or
            $verified.CommandLine -cne $Current.Record.command_line -or
            $verified.ExecutablePath -ine $payload.Path -or
            $payload.StartTime.ToUniversalTime().Ticks -lt [long]$Current.Record.start_ticks) {
            $payload.Dispose()
            throw 'A research runtime child changed during identity verification. No stop request was sent.'
        }
        $payload
    }
}

function Test-ResearchStateAvailable {
    param($Context)
    $path = Join-Path $Context.State 'runner.lock'
    if (-not (Test-Path -LiteralPath $path)) { return $true }
    $handle = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::ReadWrite)
    $acquired = $false
    try {
        try { $handle.Lock(0, 1); $acquired = $true }
        catch [IO.IOException] { return $false }
        return $true
    } finally {
        if ($acquired) { $handle.Unlock(0, 1) }
        $handle.Dispose()
    }
}

function Wait-ResearchProcesses {
    param([Diagnostics.Process[]]$Processes, [int]$Seconds)
    $timer = [Diagnostics.Stopwatch]::StartNew()
    foreach ($process in $Processes) {
        $remaining = [math]::Max(0, ($Seconds * 1000) - [int]$timer.ElapsedMilliseconds)
        if (-not $process.WaitForExit($remaining)) { return $false }
    }
    return $true
}

function Start-ResearchProcess {
    param($Context, [switch]$Dashboard, [int]$Port = 3119)
    $existing = Get-ResearchProcess $Context -Dashboard:$Dashboard
    $existingPayloads = @(Get-ResearchPayloadProcesses $existing)
    if ($existing.Status -ne 'running' -and $existingPayloads.Count -gt 0) {
        foreach ($payload in $existingPayloads) { $payload.Dispose() }
        throw 'A matching runtime survived its launcher. Run stop to drain it before starting again.'
    }
    foreach ($payload in $existingPayloads) { $payload.Dispose() }
    if ($existing.Status -eq 'running') {
        if ($Dashboard -and [int]$existing.Record.port -ne $Port) { throw 'Dashboard already runs on another port; stop it before changing ports.' }
        $existing.Process.Dispose()
        return $existing.Record
    }
    if (-not $Dashboard) {
        # Respect a manually launched worker too, even if it has no Windows PID record.
        # This is the same byte-range lock held by Python msvcrt.locking().
        $lockFile = [IO.File]::Open((Join-Path $Context.State 'runner.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::ReadWrite)
        $ownsLock = $false
        try {
            try { $lockFile.Lock(0, 1); $ownsLock = $true }
            catch [IO.IOException] { throw 'Another research worker owns state_dir. Shutdown intent was preserved.' }
            $shutdown = Join-Path $Context.State 'SHUTDOWN'
            if (Test-Path -LiteralPath $shutdown) {
                Remove-Item -LiteralPath $shutdown
                Write-Host 'Explicit start acknowledged the previous research shutdown. Any persistent pause remains in effect.'
            }
        } finally {
            if ($ownsLock) { $lockFile.Unlock(0, 1) }
            $lockFile.Dispose()
        }
    } else {
        $monitorShutdown = Join-Path $Context.State 'MONITOR_SHUTDOWN'
        if (Test-Path -LiteralPath $monitorShutdown) {
            Remove-Item -LiteralPath $monitorShutdown
            Write-Host 'Explicit dashboard start acknowledged the previous monitor shutdown.'
        }
    }
    $module = if ($Dashboard) { 'intraday_quant.strategy_lab.monitor' } else { 'intraday_quant.strategy_lab.continuous' }
    # Windows filenames cannot contain quotes; config is an absolute file, never a trailing slash.
    $arguments = if ($Dashboard) { "-m $module --config `"$($Context.Config)`" --port $Port" } else { "-m $module run --config `"$($Context.Config)`"" }
    $label = if ($Dashboard) { 'monitor' } else { 'research' }
    $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $stdout = Join-Path $Context.State "logs/$label-$stamp.stdout.log"
    $stderr = Join-Path $Context.State "logs/$label-$stamp.stderr.log"
    $previousPath = $env:PYTHONPATH
    $previousUnbuffered = $env:PYTHONUNBUFFERED
    try {
        $env:PYTHONPATH = $Context.Source
        $env:PYTHONUNBUFFERED = '1'
        $process = Start-Process -FilePath $Context.Python -ArgumentList $arguments -WorkingDirectory $Context.Platform -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    } finally { $env:PYTHONPATH = $previousPath; $env:PYTHONUNBUFFERED = $previousUnbuffered }
    Start-Sleep -Milliseconds 750
    $process.Refresh()
    if ($process.HasExited) { throw "$label exited with code $($process.ExitCode). Inspect $stderr" }
    $native = Get-CimInstance Win32_Process -Filter "ProcessId = $($process.Id)"
    if (-not $native -or -not $native.CommandLine -or -not $native.ExecutablePath) { throw "$label started but identity could not be recorded. Inspect PID $($process.Id) and $stderr." }
    $record = [ordered]@{
        schema_version = 1; pid = $process.Id; start_ticks = $process.StartTime.ToUniversalTime().Ticks.ToString()
        started_at = $process.StartTime.ToUniversalTime().ToString('o'); executable = $native.ExecutablePath
        command_line = $native.CommandLine; module = $module; python = $Context.Python
        config = $Context.Config; state_dir = $Context.State; platform_dir = $Context.Platform
        port = $(if ($Dashboard) { $Port } else { $null }); stdout = $stdout; stderr = $stderr
    }
    Write-ResearchJson $(if ($Dashboard) { $Context.MonitorRecord } else { $Context.Record }) $record
    $process.Dispose()
    return [pscustomobject]$record
}
