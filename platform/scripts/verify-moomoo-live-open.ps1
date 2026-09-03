param(
  [string]$ApiBase = "http://127.0.0.1:8001",
  [string]$Output = "",
  [string]$ControlToken = $env:INTRADAY_QUANT_TOKEN,
  [int]$PollSeconds = 5,
  [int]$DeadlineMinutesAfterOpen = 8
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $Output) {
  $Output = Join-Path $projectRoot "quant_engine_rs\data\quality\live_open_verification_latest.json"
}
if (-not $ControlToken -or $ControlToken.Length -lt 32) {
  throw "INTRADAY_QUANT_TOKEN must contain at least 32 characters for control-plane reads."
}
$controlHeaders = @{ "X-Research-Token" = $ControlToken }

$timeZone = [TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time")
$nowEt = [TimeZoneInfo]::ConvertTime([DateTimeOffset]::UtcNow, $timeZone)
$sessionDate = $nowEt.Date
$openEt = [DateTimeOffset]::new(
  $sessionDate.Year,
  $sessionDate.Month,
  $sessionDate.Day,
  9,
  30,
  0,
  $nowEt.Offset
)
$deadlineEt = $openEt.AddMinutes($DeadlineMinutesAfterOpen)

function Save-Result([hashtable]$payload) {
  $parent = Split-Path -Parent $Output
  New-Item -ItemType Directory -Path $parent -Force | Out-Null
  $payload | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Output -Encoding UTF8
}

while ($true) {
  $nowEt = [TimeZoneInfo]::ConvertTime([DateTimeOffset]::UtcNow, $timeZone)
  try {
    $status = Invoke-RestMethod -Uri "$ApiBase/api/v1/live/status" -Headers $controlHeaders -TimeoutSec 3
    $bars = Invoke-RestMethod -Uri "$ApiBase/api/v1/live/bars" -Headers $controlHeaders -TimeoutSec 3
    $forecast = Invoke-RestMethod -Uri "$ApiBase/api/v1/predictor/forecast" -Headers $controlHeaders -TimeoutSec 3

    $latestBar = @($bars.bars) | Select-Object -Last 1
    $latestTimestamp = if ($latestBar) {
      if ($latestBar.timestamp) { [string]$latestBar.timestamp }
      elseif ($latestBar.bar_start) { [string]$latestBar.bar_start }
      else { $null }
    } else { $null }
    $currentSessionBar = $false
    if ($latestTimestamp) {
      try {
        $barEt = [TimeZoneInfo]::ConvertTime([DateTimeOffset]::Parse($latestTimestamp), $timeZone)
        $currentSessionBar = $barEt.Date -eq $sessionDate -and $barEt -ge $openEt
      } catch {
        $currentSessionBar = $false
      }
    }
    $predictions = @($forecast.prediction_layer)
    $verifiedPrediction = $predictions.Count -gt 0 -and
      (@($predictions | Where-Object { $_.evidence_kind -ne "live_shadow_prediction" }).Count -eq 0)
    $passed = $status.status -eq "CONNECTED_QUOTE_PROTOCOL_VERIFIED" -and
      $currentSessionBar -and $verifiedPrediction

    $payload = @{
      checked_at_et = $nowEt.ToString("o")
      session_date = $sessionDate.ToString("yyyy-MM-dd")
      status = if ($passed) { "LIVE_OPEN_VERIFIED" } elseif ($nowEt -lt $openEt) { "WAITING_FOR_RTH_OPEN" } else { "WAITING_FOR_FIRST_FINALIZED_BAR_AND_FORECAST" }
      quote_protocol = $status.status
      quote_login = $status.login_status
      market_coverage = $status.market_coverage
      consolidated_nbbo = [bool]$status.consolidated_nbbo
      finalized_bar_count = [int]$bars.count
      latest_bar_timestamp = $latestTimestamp
      latest_bar_is_current_session = $currentSessionBar
      forecast_status = $forecast.status
      verified_live_prediction_count = if ($verifiedPrediction) { $predictions.Count } else { 0 }
      passed = $passed
      failure = $null
    }
    Save-Result $payload
    if ($passed) { exit 0 }
  } catch {
    Save-Result @{
      checked_at_et = $nowEt.ToString("o")
      session_date = $sessionDate.ToString("yyyy-MM-dd")
      status = "LIVE_OPEN_CHECK_ERROR"
      passed = $false
      failure = $_.Exception.Message
    }
  }

  if ($nowEt -ge $deadlineEt) {
    exit 2
  }
  Start-Sleep -Seconds ([Math]::Max(1, $PollSeconds))
}
