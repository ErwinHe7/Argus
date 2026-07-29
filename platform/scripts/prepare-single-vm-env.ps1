param(
  [string]$Source = ".env.local",
  [string]$Output = "infra/single-vm/.env.server"
)

$ErrorActionPreference = "Stop"

function Read-DotEnv([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Environment source not found: $Path"
  }
  $values = @{}
  foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -match '^\s*#' -or $line -notmatch '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$') {
      continue
    }
    $values[$matches[1]] = $matches[2]
  }
  return $values
}

function Has-NonEmptyValue([hashtable]$Values, [string]$Name) {
  return $Values.ContainsKey($Name) -and -not [string]::IsNullOrWhiteSpace($Values[$Name])
}

function New-HexSecret {
  $bytes = New-Object byte[] 32
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  return ([BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()
}

$sourceValues = Read-DotEnv $Source
$outputPath = if ([System.IO.Path]::IsPathRooted($Output)) {
  [System.IO.Path]::GetFullPath($Output)
} else {
  [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Output))
}
$existingValues = if (Test-Path -LiteralPath $outputPath) {
  Read-DotEnv $outputPath
} else {
  @{}
}

$requiredSales = @(
  "BILLING_PROVIDER",
  "AXIO7_SITE_URL",
  "PADDLE_ENVIRONMENT",
  "PADDLE_API_KEY",
  "PADDLE_NOTIFICATION_WEBHOOK_SECRET",
  "NEXT_PUBLIC_PADDLE_CLIENT_TOKEN",
  "PADDLE_TRUST_X_FORWARDED_FOR",
  "PADDLE_ALLOW_SANDBOX_ACCESS",
  "PADDLE_PRODUCT_FREE",
  "PADDLE_PRICE_FREE_MONTH",
  "PADDLE_PRODUCT_PRO",
  "PADDLE_PRICE_PRO_MONTH",
  "PADDLE_PRODUCT_ANNUAL",
  "PADDLE_PRICE_ANNUAL_YEAR"
)
$requiredInfrastructure = @(
  "NEXT_PUBLIC_SUPABASE_URL",
  "NEXT_PUBLIC_SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
  "OPENAI_API_KEY"
)
foreach ($name in @($requiredInfrastructure + $requiredSales)) {
  if (-not (Has-NonEmptyValue $sourceValues $name)) {
    throw "Required production value is missing from $Source`: $name. Existing output was not changed."
  }
}

if ($sourceValues["BILLING_PROVIDER"].Trim().ToLowerInvariant() -ne "paddle") {
  throw "BILLING_PROVIDER must be paddle for the permanent AXIO7 production billing contract."
}
if ($sourceValues["AXIO7_SITE_URL"].Trim() -ne "https://axio7.com") {
  throw "AXIO7_SITE_URL must be exactly https://axio7.com for this production target."
}
if ($sourceValues["PADDLE_ENVIRONMENT"].Trim().ToLowerInvariant() -ne "live") {
  throw "PADDLE_ENVIRONMENT must be live for the AXIO7 production target."
}
if ($sourceValues["PADDLE_API_KEY"].Trim() -notmatch '^pdl_live_apikey_') {
  throw "PADDLE_API_KEY does not match the Live environment."
}
if ($sourceValues["NEXT_PUBLIC_PADDLE_CLIENT_TOKEN"].Trim() -notmatch '^live_') {
  throw "NEXT_PUBLIC_PADDLE_CLIENT_TOKEN does not match the Live environment."
}
if ($sourceValues["PADDLE_TRUST_X_FORWARDED_FOR"].Trim().ToLowerInvariant() -ne "true") {
  throw "PADDLE_TRUST_X_FORWARDED_FOR must be true behind the single-VM Caddy proxy."
}
if ($sourceValues["PADDLE_ALLOW_SANDBOX_ACCESS"].Trim().ToLowerInvariant() -ne "false") {
  throw "PADDLE_ALLOW_SANDBOX_ACCESS must be false in production."
}

$currentProductNames = @(
  "PADDLE_PRODUCT_FREE",
  "PADDLE_PRODUCT_PRO",
  "PADDLE_PRODUCT_ANNUAL"
)
$currentPriceNames = @(
  "PADDLE_PRICE_FREE_MONTH",
  "PADDLE_PRICE_PRO_MONTH",
  "PADDLE_PRICE_ANNUAL_YEAR"
)
foreach ($name in $currentProductNames) {
  if ($sourceValues[$name].Trim() -notmatch '^pro_[a-z0-9]{26}$') {
    throw "$name is not a valid Paddle Product ID."
  }
}
foreach ($name in $currentPriceNames) {
  if ($sourceValues[$name].Trim() -notmatch '^pri_[a-z0-9]{26}$') {
    throw "$name is not a valid Paddle Price ID."
  }
}
$currentProductIds = @($currentProductNames | ForEach-Object { $sourceValues[$_].Trim() })
$currentPriceIds = @($currentPriceNames | ForEach-Object { $sourceValues[$_].Trim() })
if (@($currentProductIds | Select-Object -Unique).Count -ne $currentProductIds.Count) {
  throw "Free, Pro, and Annual must use distinct Paddle Product IDs."
}
if (@($currentPriceIds | Select-Object -Unique).Count -ne $currentPriceIds.Count) {
  throw "Free, Pro, and Annual must use distinct current Paddle Price IDs."
}

# Start from the existing generated server file so rerunning this helper never
# erases unrelated production-only values. Empty source values never replace a
# non-empty existing value.
$values = @{}
foreach ($entry in $existingValues.GetEnumerator()) {
  if (-not [string]::IsNullOrWhiteSpace($entry.Value)) {
    $values[$entry.Key] = $entry.Value
  }
}

$copyFromSource = @(
  $requiredInfrastructure +
  $requiredSales +
  @(
    "ADMIN_EMAILS",
    "QUANT_ADMIN_EMAILS",
    "OPENAI_BASE_URL",
    "OPENAI_MODEL",
    "PADDLE_NOTIFICATION_SETTING_ID",
    "PADDLE_PRODUCT_STARTER",
    "PADDLE_PRICE_STARTER_MONTH",
    "PADDLE_PRICE_LEGACY_PRO_MONTH",
    "PADDLE_PRODUCT_LIFETIME",
    "PADDLE_PRICE_LIFETIME",
    "PADDLE_PRICE_STARTER_YEAR",
    "PADDLE_PRICE_PRO_YEAR",
    "PADDLE_PRICE_ADVANCED_MONTH",
    "PADDLE_PRICE_ADVANCED_YEAR",
    "NEXT_PUBLIC_SENTRY_DSN",
    "SENTRY_DSN",
    "NEXT_PUBLIC_POSTHOG_KEY",
    "NEXT_PUBLIC_POSTHOG_HOST",
    "MOOMOO_FORECAST_RELAY_ENABLED",
    "MOOMOO_FORECAST_RELAY_TOKEN"
  )
)
foreach ($name in $copyFromSource) {
  if (Has-NonEmptyValue $sourceValues $name) {
    $values[$name] = $sourceValues[$name]
  }
}

$values["AXIO7_DOMAIN"] = "axio7.com"
$values["NEXT_PUBLIC_SITE_URL"] = $sourceValues["AXIO7_SITE_URL"].Trim()
$values["AXIO7_SITE_URL"] = $sourceValues["AXIO7_SITE_URL"].Trim()
$values["BILLING_PROVIDER"] = "paddle"
$values["PADDLE_ENVIRONMENT"] = "live"
$values["PADDLE_CLIENT_TOKEN"] = $sourceValues["NEXT_PUBLIC_PADDLE_CLIENT_TOKEN"].Trim()
$values["PADDLE_TRUST_X_FORWARDED_FOR"] = "true"
$values["PADDLE_ALLOW_SANDBOX_ACCESS"] = "false"
$values["PAYMENTS_ALLOW_TEST_ACCESS"] = "false"

if (-not (Has-NonEmptyValue $values "MOOMOO_FORECAST_RELAY_ENABLED")) {
  $values["MOOMOO_FORECAST_RELAY_ENABLED"] = "false"
}
$moomooForecastRelayEnabled = $values["MOOMOO_FORECAST_RELAY_ENABLED"].Trim().ToLowerInvariant()
if ($moomooForecastRelayEnabled -notin @("true", "false")) {
  throw "MOOMOO_FORECAST_RELAY_ENABLED must be true or false."
}
$values["MOOMOO_FORECAST_RELAY_ENABLED"] = $moomooForecastRelayEnabled
if ($moomooForecastRelayEnabled -eq "true" -and
    (-not (Has-NonEmptyValue $values "MOOMOO_FORECAST_RELAY_TOKEN") -or $values["MOOMOO_FORECAST_RELAY_TOKEN"].Trim().Length -lt 32)) {
  throw "MOOMOO_FORECAST_RELAY_TOKEN must contain at least 32 characters when the relay is enabled."
}

foreach ($name in @("INTRADAY_QUANT_TOKEN", "MARKET_MONITOR_CRON_SECRET", "CRON_SECRET")) {
  if (-not (Has-NonEmptyValue $values $name)) {
    $values[$name] = New-HexSecret
  }
}

if (-not (Has-NonEmptyValue $values "ADMIN_EMAILS")) {
  $values["ADMIN_EMAILS"] = "gh2722@columbia.edu"
}
if (-not (Has-NonEmptyValue $values "QUANT_ADMIN_EMAILS")) {
  $values["QUANT_ADMIN_EMAILS"] = $values["ADMIN_EMAILS"]
}
$values["MARKET_LLM_ENABLED"] = "true"
$values["AGENT_AUTONOMOUS_ENABLED"] = "false"
$values["LIVE_EXECUTION_ENABLED"] = "false"
$values["BROKER_LIVE_ENABLED"] = "false"
$values["ANOMALY_LIVE_ORDER_ENABLED"] = "false"

$outputDirectory = Split-Path -Parent $outputPath
[System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Generated for AXIO7 single-VM deployment. Never commit this file.")
foreach ($name in @($values.Keys | Sort-Object)) {
  $lines.Add("$name=$($values[$name])")
}

$temporaryPath = Join-Path $outputDirectory ".env.server.$([Guid]::NewGuid().ToString('N')).tmp"
try {
  [System.IO.File]::WriteAllLines(
    $temporaryPath,
    $lines,
    (New-Object System.Text.UTF8Encoding($false))
  )
  Move-Item -LiteralPath $temporaryPath -Destination $outputPath -Force
} finally {
  if (Test-Path -LiteralPath $temporaryPath) {
    Remove-Item -LiteralPath $temporaryPath -Force
  }
}

Write-Output "Prepared server environment at $outputPath with $($lines.Count) entries. Secret values were not printed."
