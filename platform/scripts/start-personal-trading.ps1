param(
  [ValidateRange(1024, 65535)][int]$WebPort = 3001,
  [ValidateRange(1, 1000000)][decimal]$MaxOrderNotional = 500,
  [switch]$AllowLiveTrading
)

$ErrorActionPreference = 'Stop'
$personalRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$personalRuntime = Join-Path $personalRoot '.quant-runtime\personal-moomoo'
$personalPython = Join-Path $personalRuntime 'venv\Scripts\python.exe'
$personalNode = (Get-Command node -ErrorAction Stop).Source
$personalNext = Join-Path $personalRoot 'node_modules\next\dist\bin\next'
if (-not (Test-Path -LiteralPath $personalPython)) { throw 'Run setup-personal-trading.ps1 first to install the official SDK in an isolated environment.' }
if (-not (Test-Path -LiteralPath $personalNext)) { throw 'Install the platform Node dependencies before starting the web app.' }
foreach ($personalPort in @(8766, $WebPort)) {
  if (Get-NetTCPConnection -LocalPort $personalPort -State Listen -ErrorAction SilentlyContinue) { throw "Port $personalPort is already in use. Stop the existing personal workspace or choose another web port." }
}
New-Item -ItemType Directory -Path $personalRuntime -Force | Out-Null
$personalKeys = @('LEO_PERSONAL_GATEWAY_TOKEN','LEO_PERSONAL_TRADING_ENABLED','LEO_PERSONAL_WEB_ORIGIN','AXIO7_NEXT_DIST_DIR','PUBLIC_MARKET_MAP_DEV_ORIGIN','SENTRY_DSN','NEXT_PUBLIC_SENTRY_DSN','NEXT_PUBLIC_POSTHOG_KEY','NEXT_PUBLIC_GA_ID','NEXT_TELEMETRY_DISABLED')
$personalPrevious = @{}
foreach ($personalKey in $personalKeys) { $personalPrevious[$personalKey] = [Environment]::GetEnvironmentVariable($personalKey, 'Process') }
$personalGateway = $null
try {
  $personalKeyPath = Join-Path $personalRuntime 'gateway-key.dpapi'
  if (Test-Path -LiteralPath $personalKeyPath) {
    $personalSecureKey = (Get-Content -LiteralPath $personalKeyPath -Raw).Trim() | ConvertTo-SecureString
  } else {
    $personalRandom = New-Object byte[] 48
    $personalRng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $personalRng.GetBytes($personalRandom)
    $personalRng.Dispose()
    $personalSecureKey = ConvertTo-SecureString ([Convert]::ToBase64String($personalRandom)) -AsPlainText -Force
    $personalSecureKey | ConvertFrom-SecureString | Set-Content -LiteralPath $personalKeyPath -Encoding ascii
  }
  $env:LEO_PERSONAL_GATEWAY_TOKEN = (New-Object PSCredential('local-owner', $personalSecureKey)).GetNetworkCredential().Password
  $env:LEO_PERSONAL_TRADING_ENABLED = 'true'
  $env:LEO_PERSONAL_WEB_ORIGIN = "http://127.0.0.1:$WebPort"
  $env:AXIO7_NEXT_DIST_DIR = '.next-personal-broker'
  $env:NEXT_TELEMETRY_DISABLED = '1'
  # The personal root layout does not mount analytics. Disable telemetry SDKs too.
  $env:SENTRY_DSN = ''
  $env:NEXT_PUBLIC_SENTRY_DSN = ''
  $env:NEXT_PUBLIC_POSTHOG_KEY = ''
  $env:NEXT_PUBLIC_GA_ID = ''
  if (Get-NetTCPConnection -LocalPort 8791 -State Listen -ErrorAction SilentlyContinue) { $env:PUBLIC_MARKET_MAP_DEV_ORIGIN = 'http://127.0.0.1:8791' }
  $personalJournal = Join-Path $personalRuntime 'orders.sqlite3'
  $personalGatewayArgs = '-m scripts.personal_moomoo --port 8766 --journal "{0}" --max-order-notional {1}' -f $personalJournal, $MaxOrderNotional.ToString([Globalization.CultureInfo]::InvariantCulture)
  if ($AllowLiveTrading) { $personalGatewayArgs += ' --allow-live' }
  $personalGateway = Start-Process -FilePath $personalPython -ArgumentList $personalGatewayArgs -WorkingDirectory $personalRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $personalRuntime 'gateway.out.log') -RedirectStandardError (Join-Path $personalRuntime 'gateway.err.log') -PassThru
  Start-Sleep -Milliseconds 700
  if ($personalGateway.HasExited) { throw 'The personal gateway could not start. Check the local gateway error log.' }
  $personalWebArgs = '"{0}" dev --hostname 127.0.0.1 --port {1}' -f $personalNext, $WebPort
  $personalWeb = Start-Process -FilePath $personalNode -ArgumentList $personalWebArgs -WorkingDirectory $personalRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $personalRuntime 'web.out.log') -RedirectStandardError (Join-Path $personalRuntime 'web.err.log') -PassThru
  @{ gateway_pid=$personalGateway.Id; gateway_started=$personalGateway.StartTime.ToUniversalTime().ToString('o'); web_pid=$personalWeb.Id; web_started=$personalWeb.StartTime.ToUniversalTime().ToString('o'); web_port=$WebPort; live_enabled=[bool]$AllowLiveTrading } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $personalRuntime 'processes.json') -Encoding utf8
  $personalReady = $false
  for ($personalAttempt=0; $personalAttempt -lt 20; $personalAttempt++) {
    if ($personalWeb.HasExited -or $personalGateway.HasExited) { throw 'A personal workspace process exited during startup. Check its local error log.' }
    if ((Get-NetTCPConnection -LocalPort $WebPort -State Listen -ErrorAction SilentlyContinue) -and
        (Get-NetTCPConnection -LocalPort 8766 -State Listen -ErrorAction SilentlyContinue)) { $personalReady = $true; break }
    Start-Sleep -Milliseconds 500
  }
  if (-not $personalReady) { throw 'The personal workspace did not start listening. Check the local logs before restarting it.' }
  Write-Output "Personal trading workspace ready: http://127.0.0.1:$WebPort/brokers"
  Write-Output 'The first page visit compiles the web interface and can take a few seconds.'
  Write-Output "Manual real orders enabled: $([bool]$AllowLiveTrading). Order cap: USD $MaxOrderNotional. Automatic execution: disabled."
} catch {
  if ($personalGateway -and -not $personalGateway.HasExited) { Stop-Process -Id $personalGateway.Id -ErrorAction SilentlyContinue }
  throw
} finally {
  foreach ($personalKey in $personalKeys) { [Environment]::SetEnvironmentVariable($personalKey, $personalPrevious[$personalKey], 'Process') }
}
