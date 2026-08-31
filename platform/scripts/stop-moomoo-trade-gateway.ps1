$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pidPath = Join-Path $repoRoot '.quant-runtime\moomoo-trade-gateway.pid'
if (-not (Test-Path -LiteralPath $pidPath)) {
  Write-Output 'MOOMOO_TRADE_GATEWAY_NOT_RUNNING'
  exit 0
}
$processId = [int](Get-Content -LiteralPath $pidPath -Raw)
$process = Get-Process -Id $processId -ErrorAction SilentlyContinue
if ($null -ne $process) {
  Stop-Process -Id $processId
  $process.WaitForExit(5000)
}
Remove-Item -LiteralPath $pidPath -Force
Write-Output "MOOMOO_TRADE_GATEWAY_STOPPED pid=$processId"
