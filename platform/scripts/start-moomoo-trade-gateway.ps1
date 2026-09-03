param(
  [ValidateSet('simulate', 'real')]
  [string]$Mode = 'simulate',
  [long]$AccountId = 0,
  [double]$MaxOrderNotional = 500.0,
  [string]$AllowSymbols = 'US.SPY',
  [switch]$Foreground
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runtimeRoot = Join-Path $repoRoot '.quant-runtime'
$gatewayScript = Join-Path $repoRoot 'scripts\moomoo_trade_gateway.py'
$pidPath = Join-Path $runtimeRoot 'moomoo-trade-gateway.pid'
$stdoutPath = Join-Path $runtimeRoot 'moomoo-trade-gateway.out.log'
$stderrPath = Join-Path $runtimeRoot 'moomoo-trade-gateway.err.log'

if ([string]::IsNullOrWhiteSpace($env:AXIO_BROKER_GATEWAY_TOKEN) -or
    $env:AXIO_BROKER_GATEWAY_TOKEN.Length -lt 32) {
  throw 'Set AXIO_BROKER_GATEWAY_TOKEN to a random value of at least 32 characters in this session.'
}
if ($Mode -eq 'real') {
  if ($AccountId -le 0) {
    throw 'Real mode requires -AccountId with the exact Moomoo account ID.'
  }
  if ($env:AXIO_LIVE_TRADING_ENABLED -ne 'I_UNDERSTAND_REAL_ORDERS') {
    throw 'Real mode requires AXIO_LIVE_TRADING_ENABLED=I_UNDERSTAND_REAL_ORDERS.'
  }
  if ([string]::IsNullOrWhiteSpace($env:AXIO_LIVE_ARMING_TOKEN) -or
      $env:AXIO_LIVE_ARMING_TOKEN.Length -lt 32) {
    throw 'Real mode requires AXIO_LIVE_ARMING_TOKEN with at least 32 characters.'
  }
  if ([string]::IsNullOrWhiteSpace($env:MOOMOO_TRADE_PASSWORD_MD5) -and
      [string]::IsNullOrWhiteSpace($env:MOOMOO_TRADE_PASSWORD)) {
    throw 'Real mode requires a session-only MOOMOO_TRADE_PASSWORD_MD5 or MOOMOO_TRADE_PASSWORD.'
  }
}

$installedVersion = (& python -c "import moomoo; print(moomoo.__version__)" 2>$null).Trim()
if ($LASTEXITCODE -ne 0) {
  throw 'The official Python package is missing. Run: python -m pip install moomoo-api==10.9.6908'
}
if ($installedVersion -ne '10.09.6908' -and $installedVersion -ne '10.9.6908') {
  throw "Expected moomoo-api 10.9.6908, found $installedVersion. Run: python -m pip install --upgrade moomoo-api==10.9.6908"
}
if (-not (Test-NetConnection 127.0.0.1 -Port 11111 -InformationLevel Quiet)) {
  throw 'Moomoo OpenD is not listening on 127.0.0.1:11111. Start and sign in to OpenD first.'
}

New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
$arguments = @(
  $gatewayScript,
  '--mode', $Mode,
  '--max-order-notional', $MaxOrderNotional.ToString([Globalization.CultureInfo]::InvariantCulture),
  '--allow-symbols', $AllowSymbols
)
if ($AccountId -gt 0) {
  $arguments += @('--account-id', $AccountId.ToString())
}

if ($Foreground) {
  & python @arguments
  exit $LASTEXITCODE
}

$process = Start-Process -FilePath 'python' `
  -ArgumentList $arguments `
  -WorkingDirectory $repoRoot `
  -WindowStyle Hidden `
  -RedirectStandardOutput $stdoutPath `
  -RedirectStandardError $stderrPath `
  -PassThru
Set-Content -LiteralPath $pidPath -Value $process.Id -Encoding ascii
Start-Sleep -Milliseconds 1200
if ($process.HasExited) {
  $detail = if (Test-Path $stderrPath) { Get-Content $stderrPath -Raw } else { 'no stderr' }
  throw "Moomoo trade gateway exited during startup: $detail"
}
Write-Output "MOOMOO_TRADE_GATEWAY_STARTED pid=$($process.Id) mode=$Mode url=http://127.0.0.1:8765"
