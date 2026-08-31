$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$statePath = Join-Path $projectRoot ".quant-runtime\processes.json"

if (-not (Test-Path -LiteralPath $statePath)) {
  Write-Output "No AXIO7 intraday runtime state was found."
  exit 0
}

$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
foreach ($managedPid in @($state.tradeGatewayPid, $state.liveVerifierPid, $state.optionsWatchPid, $state.liveStreamPid, $state.frontendPid, $state.backendPid)) {
  if (-not $managedPid) { continue }
  $process = Get-Process -Id $managedPid -ErrorAction SilentlyContinue
  if ($process) {
    Stop-Process -Id $managedPid -Force
    Write-Output "Stopped process $managedPid."
  }
}

Remove-Item -LiteralPath $statePath -Force
