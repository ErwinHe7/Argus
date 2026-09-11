$ErrorActionPreference = 'Stop'
$personalRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$personalStatePath = Join-Path $personalRoot '.quant-runtime\personal-moomoo\processes.json'
if (-not (Test-Path -LiteralPath $personalStatePath)) { Write-Output 'No personal workspace process record exists.'; return }
$personalState = Get-Content -LiteralPath $personalStatePath -Raw | ConvertFrom-Json
$personalProcesses = @(Get-CimInstance Win32_Process)
foreach ($personalService in @('web','gateway')) {
  $personalProcessId = [int]$personalState."${personalService}_pid"
  $personalStarted = ([DateTime]$personalState."${personalService}_started").ToUniversalTime().Ticks
  $personalProcess = Get-Process -Id $personalProcessId -ErrorAction SilentlyContinue
  if (-not $personalProcess) { continue }
  if ($personalProcess.StartTime.ToUniversalTime().Ticks -ne $personalStarted) { throw 'A saved process ID was reused. No process was stopped.' }
  $personalIds = [Collections.Generic.List[int]]::new()
  $personalIds.Add($personalProcessId)
  for ($personalIndex=0; $personalIndex -lt $personalIds.Count; $personalIndex++) {
    foreach ($personalChild in @($personalProcesses | Where-Object { $_.ParentProcessId -eq $personalIds[$personalIndex] -and $_.Name -ne 'conhost.exe' })) { $personalIds.Add([int]$personalChild.ProcessId) }
  }
  foreach ($personalId in $personalIds) {
    $personalDetails = $personalProcesses | Where-Object ProcessId -eq $personalId
    if (-not $personalDetails -or $personalDetails.Name -notin @('node.exe','python.exe','pythonw.exe') -or
        ($personalDetails.CommandLine -notlike '*scripts.personal_moomoo*' -and $personalDetails.CommandLine -notlike "*$personalRoot*node_modules*next*")) {
      throw 'A process does not match the personal workspace. No processes in this service were stopped.'
    }
  }
  for ($personalIndex=$personalIds.Count-1; $personalIndex -ge 0; $personalIndex--) { Stop-Process -Id $personalIds[$personalIndex] -ErrorAction SilentlyContinue }
}
Write-Output 'Stopped the recorded personal web and gateway processes. OpenD stays running.'
