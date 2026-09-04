param(
  [string]$BackendUrl = "http://127.0.0.1:8001"
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$envFile = Join-Path $projectRoot ".env.local"
$runtimeRoot = Join-Path $projectRoot ".quant-runtime"
$responsePath = Join-Path $runtimeRoot "strict-replay-response.json"

if (-not (Test-Path -LiteralPath $envFile)) {
  throw "Missing .env.local"
}

$tokenLine = Get-Content -LiteralPath $envFile |
  Where-Object { $_ -match '^\s*INTRADAY_QUANT_TOKEN\s*=' } |
  Select-Object -Last 1
if (-not $tokenLine -or
    $tokenLine -notmatch '^\s*INTRADAY_QUANT_TOKEN\s*=\s*(.*)\s*$') {
  throw "INTRADAY_QUANT_TOKEN is missing from .env.local"
}
$token = $Matches[1].Trim().Trim('"').Trim("'")
if ($token.Length -lt 32) {
  throw "INTRADAY_QUANT_TOKEN is too short"
}

$query = @{
  version = "axio.market-query.v2"
  intent = "forecast"
  setup_type = "model_forecast"
  symbols = @("SPX")
  limit = 1
  filters = @{
    require_realtime = $true
    include_historical = $false
    max_data_age_seconds = 120
    max_dte = 14
  }
} | ConvertTo-Json -Depth 6 -Compress

New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
$response = Invoke-WebRequest `
  -Uri "$BackendUrl/api/v1/research/databento-replay" `
  -Method Post `
  -Headers @{
    Accept = "application/json"
    "X-Research-Token" = $token
  } `
  -ContentType "application/json" `
  -Body $query `
  -TimeoutSec 1800 `
  -UseBasicParsing

[IO.File]::WriteAllText(
  $responsePath,
  $response.Content,
  [Text.UTF8Encoding]::new($false)
)

$parsed = $response.Content | ConvertFrom-Json
[pscustomobject]@{
  status = $parsed.status
  requestId = $parsed.request_id
  replaySourceMode = $parsed.model_contract.replay_source_mode
  observationCutoff = $parsed.observation_cutoff
  candidateCount = @($parsed.candidates).Count
  output = $responsePath
} | ConvertTo-Json -Compress
