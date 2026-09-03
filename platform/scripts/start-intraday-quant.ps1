param(
  [int]$FrontendPort = 3000,
  [int]$BackendPort = 8001,
  [switch]$StartMassiveWorkers
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$quantRoot = Join-Path $projectRoot "quant_engine_rs"
$cargoPath = Join-Path $env:USERPROFILE ".cargo\bin\cargo.exe"
$backendBinary = Join-Path $quantRoot "target\release\quantd.exe"
$controlBinary = Join-Path $quantRoot "target\release\quantctl.exe"
$runtimeRoot = Join-Path $projectRoot ".quant-runtime"
$localEnv = Join-Path $projectRoot ".env.local"

# The Rust/Next processes load .env.local themselves, while the verifier is a
# separate PowerShell child. Import only its server-side control token into the
# parent environment so the secret is inherited without appearing in argv.
if (-not $env:INTRADAY_QUANT_TOKEN -and (Test-Path -LiteralPath $localEnv)) {
  $tokenLine = Get-Content -LiteralPath $localEnv |
    Where-Object { $_ -match '^\s*INTRADAY_QUANT_TOKEN\s*=' } |
    Select-Object -Last 1
  if ($tokenLine -and $tokenLine -match '^\s*INTRADAY_QUANT_TOKEN\s*=\s*(.*)\s*$') {
    $candidateToken = $Matches[1].Trim().Trim('"').Trim("'")
    if ($candidateToken.Length -ge 32) {
      $env:INTRADAY_QUANT_TOKEN = $candidateToken
    }
  }
}
if (-not $env:INTRADAY_QUANT_TOKEN) {
  $tokenBytes = New-Object byte[] 32
  $tokenGenerator = [Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $tokenGenerator.GetBytes($tokenBytes)
  } finally {
    $tokenGenerator.Dispose()
  }
  $env:INTRADAY_QUANT_TOKEN = ($tokenBytes | ForEach-Object { $_.ToString("x2") }) -join ""
  Write-Output "Generated an ephemeral in-memory research token for this local run."
}
if (-not (Test-Path -LiteralPath $cargoPath)) {
  throw "Rust toolchain not found. Install rustup, then run cargo build --release in quant_engine_rs."
}

$buildInputs = @(
  (Join-Path $quantRoot "Cargo.toml"),
  (Join-Path $quantRoot "Cargo.lock")
) + @(Get-ChildItem -LiteralPath (Join-Path $quantRoot "src") -Recurse -File | Select-Object -ExpandProperty FullName)
$latestBuildInput = $buildInputs |
  Where-Object { Test-Path -LiteralPath $_ } |
  ForEach-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc } |
  Sort-Object -Descending |
  Select-Object -First 1
$needsBuild = -not (Test-Path -LiteralPath $backendBinary) -or -not (Test-Path -LiteralPath $controlBinary)
if (-not $needsBuild) {
  $oldestBinary = @(
    (Get-Item -LiteralPath $backendBinary).LastWriteTimeUtc,
    (Get-Item -LiteralPath $controlBinary).LastWriteTimeUtc
  ) | Sort-Object | Select-Object -First 1
  $needsBuild = $latestBuildInput -gt $oldestBinary
}

if ($needsBuild) {
  Write-Output "Building the Rust quant engine because source inputs are newer than the release binaries..."
  & $cargoPath build --release --bin quantd --bin quantctl --manifest-path (Join-Path $quantRoot "Cargo.toml")
  if ($LASTEXITCODE -ne 0) { throw "Rust release build failed." }
}

foreach ($port in @($FrontendPort, $BackendPort)) {
  $listener = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($listener) {
    throw "Port $port is already in use by process $($listener.OwningProcess). Stop that service or choose another port."
  }
}

New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null

$backendOut = Join-Path $runtimeRoot "backend.out.log"
$backendErr = Join-Path $runtimeRoot "backend.err.log"
$frontendOut = Join-Path $runtimeRoot "frontend.out.log"
$frontendErr = Join-Path $runtimeRoot "frontend.err.log"
$readinessOut = Join-Path $runtimeRoot "massive-readiness.out.log"
$readinessErr = Join-Path $runtimeRoot "massive-readiness.err.log"
$streamOut = Join-Path $runtimeRoot "massive-model.out.log"
$streamErr = Join-Path $runtimeRoot "massive-model.err.log"
$optionsOut = Join-Path $runtimeRoot "massive-options.out.log"
$optionsErr = Join-Path $runtimeRoot "massive-options.err.log"

$env:INTRADAY_QUANT_API_URL = "http://127.0.0.1:$BackendPort"
$backendProcess = Start-Process `
  -FilePath $backendBinary `
  -ArgumentList "--config", "configs/production.yaml", "--port", "$BackendPort" `
  -WorkingDirectory $quantRoot `
  -WindowStyle Hidden `
  -RedirectStandardOutput $backendOut `
  -RedirectStandardError $backendErr `
  -PassThru

$backendReady = $false
for ($attempt = 0; $attempt -lt 40; $attempt += 1) {
  Start-Sleep -Milliseconds 250
  try {
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:$BackendPort/health" -TimeoutSec 1
    if ($health.status -eq "ok") {
      $backendReady = $true
      break
    }
  } catch {
    if ($backendProcess.HasExited) { break }
  }
}

if (-not $backendReady -or $backendProcess.HasExited) {
  if (-not $backendProcess.HasExited) { Stop-Process -Id $backendProcess.Id -Force }
  throw "Intraday backend did not become ready. See $backendErr"
}

$frontendProcess = Start-Process `
  -FilePath "npm.cmd" `
  -ArgumentList "run", "dev", "--", "--port", "$FrontendPort" `
  -WorkingDirectory $projectRoot `
  -WindowStyle Hidden `
  -RedirectStandardOutput $frontendOut `
  -RedirectStandardError $frontendErr `
  -PassThru

$frontendReady = $false
for ($attempt = 0; $attempt -lt 120; $attempt += 1) {
  Start-Sleep -Milliseconds 250
  try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:$FrontendPort/" -TimeoutSec 2 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
      $frontendReady = $true
      break
    }
  } catch {
    if ($frontendProcess.HasExited) { break }
  }
}

if (-not $frontendReady -or $frontendProcess.HasExited) {
  $backendListener = Get-NetTCPConnection -State Listen -LocalPort $BackendPort -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($backendListener) { Stop-Process -Id $backendListener.OwningProcess -Force }
  if (-not $frontendProcess.HasExited) { Stop-Process -Id $frontendProcess.Id -Force }
  throw "Next.js dashboard did not become ready. See $frontendErr"
}

$backendListener = Get-NetTCPConnection -State Listen -LocalPort $BackendPort | Select-Object -First 1
$frontendListener = Get-NetTCPConnection -State Listen -LocalPort $FrontendPort | Select-Object -First 1

$liveStreamProcess = $null
$optionsWatchProcess = $null
if ($StartMassiveWorkers) {
  $equityReadinessProcess = Start-Process `
    -FilePath $controlBinary `
    -ArgumentList "--config", "configs/production.yaml", "live", "massive-check", "--scope", "equity", "--output", "data/live/massive_readiness.json" `
    -WorkingDirectory $quantRoot `
    -WindowStyle Hidden `
    -RedirectStandardOutput $readinessOut `
    -RedirectStandardError $readinessErr `
    -Wait `
    -PassThru

  if ($equityReadinessProcess.ExitCode -eq 0) {
    $liveStreamProcess = Start-Process `
      -FilePath $controlBinary `
      -ArgumentList "--config", "configs/production.yaml", "live", "massive-model" `
      -WorkingDirectory $quantRoot `
      -WindowStyle Hidden `
      -RedirectStandardOutput $streamOut `
      -RedirectStandardError $streamErr `
      -PassThru
  }

  $optionsReadinessProcess = Start-Process `
    -FilePath $controlBinary `
    -ArgumentList "--config", "configs/production.yaml", "live", "massive-check", "--scope", "options", "--output", "data/live/massive_readiness.json" `
    -WorkingDirectory $quantRoot `
    -WindowStyle Hidden `
    -RedirectStandardOutput $readinessOut `
    -RedirectStandardError $readinessErr `
    -Wait `
    -PassThru

  if ($optionsReadinessProcess.ExitCode -eq 0) {
    $optionsWatchProcess = Start-Process `
      -FilePath $controlBinary `
      -ArgumentList "--config", "configs/production.yaml", "live", "massive-options-watch" `
      -WorkingDirectory $quantRoot `
      -WindowStyle Hidden `
      -RedirectStandardOutput $optionsOut `
      -RedirectStandardError $optionsErr `
      -PassThru
  }
}

$processState = @{
  backendPid = $backendListener.OwningProcess
  frontendPid = $frontendListener.OwningProcess
  liveStreamPid = if ($liveStreamProcess) { $liveStreamProcess.Id } else { $null }
  optionsWatchPid = if ($optionsWatchProcess) { $optionsWatchProcess.Id } else { $null }
  backendUrl = "http://127.0.0.1:$BackendPort"
  frontendUrl = "http://127.0.0.1:$FrontendPort/"
  startedAt = (Get-Date).ToUniversalTime().ToString("o")
}
$processState | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runtimeRoot "processes.json") -Encoding UTF8

Write-Output "AXIO7 Rust intraday research system is running."
Write-Output "Dashboard: http://127.0.0.1:$FrontendPort/"
Write-Output "API:       http://127.0.0.1:$BackendPort/api/v1/system"
Write-Output "Runtime:   $runtimeRoot"
if (-not $StartMassiveWorkers) {
  Write-Output "Market data: owned by quantd using configs/production.yaml; optional Massive workers were not requested."
} elseif ($liveStreamProcess) {
  Write-Output "Market data: Massive real-time SIP model stream started (PID $($liveStreamProcess.Id)); shadow-only"
} else {
  Write-Output "Market data: fail-closed; Massive SIP equity entitlement is not production-ready."
}
if ($StartMassiveWorkers -and $optionsWatchProcess) {
  Write-Output "Options:     Massive full OPRA chain watcher started (PID $($optionsWatchProcess.Id))"
} elseif ($StartMassiveWorkers) {
  Write-Output "Options:     fail-closed; Massive OPRA entitlement is not production-ready."
}
if ($StartMassiveWorkers) {
  Write-Output "Readiness:   $quantRoot\data\live\massive_readiness.json"
}
Write-Output "Broker:      not started; this command is data/research-only and never routes orders."
