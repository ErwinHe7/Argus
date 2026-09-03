[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$EnvPath,

  [Parameter(Mandatory)]
  [ValidatePattern('^[0-9a-f]{40}$')]
  [string]$GitCommit,

  [Parameter(Mandatory)]
  [string]$RightsReceiptPath,

  [Parameter(Mandatory)]
  [string]$TechnicalEntitlementReceiptPath,

  [Parameter(Mandatory)]
  [string]$OwnerAttestationPath
)

# Atomically binds an existing production environment to one clean source
# commit and one internally consistent owner-attested rights evidence set.
# Existing secrets are preserved byte-for-value and are never printed.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LowercaseSha256 {
  param([Parameter(Mandatory)][string]$Path)

  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Read-JsonArtifact {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Name
  )

  $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
  $item = Get-Item -LiteralPath $resolved -Force
  if (-not $item.PSIsContainer -and $item.Length -gt 0 -and $item.Length -le 64KB) {
    try {
      $value = [IO.File]::ReadAllText(
        $resolved,
        [Text.UTF8Encoding]::new($false, $true)
      ) | ConvertFrom-Json -ErrorAction Stop
    } catch {
      throw "$Name is not strict UTF-8 JSON."
    }
    return [pscustomobject]@{
      Path = $resolved
      Sha256 = Get-LowercaseSha256 -Path $resolved
      Value = $value
    }
  }
  throw "$Name is missing, empty, oversized, or not a regular file."
}

function Assert-Hash {
  param(
    [Parameter(Mandatory)][object]$Value,
    [Parameter(Mandatory)][string]$Name
  )

  if ([string]$Value -cnotmatch '\A[0-9a-f]{64}\z') {
    throw "$Name is not a lowercase SHA-256 value."
  }
}

function Assert-ReleaseEvidence {
  param(
    [Parameter(Mandatory)][object]$Rights,
    [Parameter(Mandatory)][object]$Technical,
    [Parameter(Mandatory)][object]$Attestation
  )

  $rightsValue = $Rights.Value
  $technicalValue = $Technical.Value
  $attestationValue = $Attestation.Value

  if ([string]$rightsValue.schema_version -cne 'axio.market_data_rights.v2' -or
      [string]$rightsValue.provider -cne 'databento' -or
      [string]$rightsValue.product -cne 'EQUS.MINI' -or
      [string]$rightsValue.plan_status -cne 'ACTIVE' -or
      [string]$rightsValue.evidence_kind -cne 'ACCOUNT_OWNER_ATTESTATION' -or
      $rightsValue.permitted_uses.model_input -ne $true -or
      $rightsValue.permitted_uses.customer_external_display -ne $true -or
      $rightsValue.permitted_uses.derived_output_publication -ne $true -or
      $rightsValue.permitted_uses.raw_data_redistribution -ne $false) {
    throw 'The rights receipt does not authorize the expected derived-output use.'
  }
  Assert-Hash -Value $rightsValue.evidence_artifact_sha256 `
    -Name 'rights evidence_artifact_sha256'
  Assert-Hash `
    -Value $rightsValue.owner_attestation.technical_entitlement_receipt_sha256 `
    -Name 'rights technical_entitlement_receipt_sha256'

  if ([string]$technicalValue.schema_version -cne 'axio.databento_technical_entitlement.v1' -or
      [string]$technicalValue.status -cne 'TECHNICAL_ENTITLEMENT_VERIFIED' -or
      [string]$technicalValue.provider -cne 'databento' -or
      [string]$technicalValue.product -cne 'Databento US Equities Mini' -or
      [string]$technicalValue.dataset -cne 'EQUS.MINI' -or
      $technicalValue.entitled -ne $true -or
      $Technical.Sha256 -cne
        [string]$rightsValue.owner_attestation.technical_entitlement_receipt_sha256) {
    throw 'The technical-entitlement artifact does not match the rights receipt.'
  }

  if ([string]$attestationValue.schema_version -cne
        'axio.account_owner_market_data_attestation.v1' -or
      [string]$attestationValue.evidence_kind -cne 'ACCOUNT_OWNER_ATTESTATION' -or
      [string]$attestationValue.evidence_basis -cne
        'OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT' -or
      [string]$attestationValue.provider -cne 'databento' -or
      [string]$attestationValue.product -cne 'EQUS.MINI' -or
      $Attestation.Sha256 -cne [string]$rightsValue.evidence_artifact_sha256 -or
      [string]$attestationValue.technical_entitlement_receipt_sha256 -cne
        $Technical.Sha256) {
    throw 'The private owner attestation does not match the rights receipt.'
  }
}

function Read-EnvironmentLines {
  param([Parameter(Mandatory)][string]$Path)

  $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
  $item = Get-Item -LiteralPath $resolved -Force
  if ($item.PSIsContainer -or $item.Length -eq 0 -or $item.Length -gt 1MB) {
    throw 'The server environment is missing, empty, oversized, or not a file.'
  }
  $bytes = [IO.File]::ReadAllBytes($resolved)
  try {
    $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
  } finally {
    [Array]::Clear($bytes, 0, $bytes.Length)
  }
  if ($text.IndexOf([char]0) -ge 0) {
    throw 'The server environment contains a NUL byte.'
  }
  return [pscustomobject]@{
    Path = $resolved
    Sha256 = Get-LowercaseSha256 -Path $resolved
    Lines = @($text -split '\r?\n')
  }
}

function Get-EnvironmentMap {
  param(
    [Parameter(Mandatory)]
    [AllowEmptyString()]
    [string[]]$Lines
  )

  $values = @{}
  foreach ($line in $Lines) {
    if ($line -match '^\s*#' -or [string]::IsNullOrWhiteSpace($line)) {
      continue
    }
    if ($line -notmatch '\A([A-Za-z_][A-Za-z0-9_]*)=(.*)\z') {
      throw 'The server environment contains a malformed line.'
    }
    $key = $matches[1]
    if ($values.ContainsKey($key)) {
      throw "The server environment contains duplicate key $key."
    }
    $values[$key] = $matches[2]
  }
  return $values
}

function Assert-ExistingProductionEnvironment {
  param([Parameter(Mandatory)][hashtable]$Values)

  foreach ($name in @(
    'DATABENTO_API_KEY',
    'INTRADAY_QUANT_TOKEN',
    'MARKET_MONITOR_CRON_SECRET',
    'NEXT_PUBLIC_SUPABASE_URL',
    'NEXT_PUBLIC_SUPABASE_ANON_KEY',
    'SUPABASE_SERVICE_ROLE_KEY',
    'PADDLE_API_KEY',
    'NEXT_PUBLIC_PADDLE_CLIENT_TOKEN'
  )) {
    if (-not $Values.ContainsKey($name) -or
        [string]::IsNullOrWhiteSpace([string]$Values[$name])) {
      throw "Required existing production value $name is unavailable."
    }
  }
  if ([string]$Values['INTRADAY_QUANT_TOKEN'].Length -lt 32 -or
      [string]$Values['MARKET_MONITOR_CRON_SECRET'].Length -lt 32) {
    throw 'A required server-only token is shorter than 32 characters.'
  }
  if (-not $Values.ContainsKey('AXIO7_SITE_URL') -or
      [string]$Values['AXIO7_SITE_URL'] -cne 'https://axio7.com') {
    throw 'AXIO7_SITE_URL must remain https://axio7.com.'
  }
}

function Write-BoundEnvironment {
  param(
    [Parameter(Mandatory)][object]$Environment,
    [Parameter(Mandatory)][hashtable]$Updates
  )

  if ((Get-LowercaseSha256 -Path $Environment.Path) -cne $Environment.Sha256) {
    throw 'The server environment changed while it was being validated.'
  }

  $seen = @{}
  $output = [Collections.Generic.List[string]]::new()
  foreach ($line in $Environment.Lines) {
    if ($line -match '\A([A-Za-z_][A-Za-z0-9_]*)=(.*)\z' -and
        $Updates.ContainsKey($matches[1])) {
      $key = $matches[1]
      $output.Add("$key=$($Updates[$key])")
      $seen[$key] = $true
    } else {
      $output.Add($line)
    }
  }
  foreach ($key in @($Updates.Keys | Sort-Object)) {
    if (-not $seen.ContainsKey($key)) {
      $output.Add("$key=$($Updates[$key])")
    }
  }

  while ($output.Count -gt 0 -and
         [string]::IsNullOrEmpty($output[$output.Count - 1])) {
    $output.RemoveAt($output.Count - 1)
  }
  $payload = [Text.UTF8Encoding]::new($false).GetBytes(
    ([string]::Join("`n", $output) + "`n")
  )
  $directory = [IO.Path]::GetDirectoryName($Environment.Path)
  $temporary = Join-Path $directory (
    ".$([IO.Path]::GetFileName($Environment.Path)).$([Guid]::NewGuid().ToString('N')).tmp"
  )
  $backup = Join-Path $directory (
    "$([IO.Path]::GetFileName($Environment.Path)).$([Guid]::NewGuid().ToString('N')).backup"
  )
  try {
    $stream = [IO.FileStream]::new(
      $temporary,
      [IO.FileMode]::CreateNew,
      [IO.FileAccess]::Write,
      [IO.FileShare]::None,
      4096,
      [IO.FileOptions]::WriteThrough
    )
    try {
      $stream.Write($payload, 0, $payload.Length)
      $stream.Flush($true)
    } finally {
      $stream.Dispose()
    }
    if ((Get-LowercaseSha256 -Path $Environment.Path) -cne $Environment.Sha256) {
      throw 'The server environment changed before the atomic replacement.'
    }
    [IO.File]::Replace($temporary, $Environment.Path, $backup, $true)
    [IO.File]::Delete($backup)
  } finally {
    [Array]::Clear($payload, 0, $payload.Length)
    if ([IO.File]::Exists($temporary)) {
      [IO.File]::Delete($temporary)
    }
    if ([IO.File]::Exists($backup)) {
      [IO.File]::Delete($backup)
    }
  }
}

$rights = Read-JsonArtifact -Path $RightsReceiptPath -Name 'rights receipt'
$technical = Read-JsonArtifact `
  -Path $TechnicalEntitlementReceiptPath `
  -Name 'technical-entitlement receipt'
$attestation = Read-JsonArtifact `
  -Path $OwnerAttestationPath `
  -Name 'owner attestation'
Assert-ReleaseEvidence `
  -Rights $rights `
  -Technical $technical `
  -Attestation $attestation

$environment = Read-EnvironmentLines -Path $EnvPath
$values = Get-EnvironmentMap -Lines $environment.Lines
Assert-ExistingProductionEnvironment -Values $values

$updates = @{
  GIT_COMMIT = $GitCommit
  AXIO7_PUBLIC_MARKET_DATA_PROVIDER = 'databento'
  AXIO7_MARKET_DATA_RIGHTS_RECEIPT_SHA256 = $rights.Sha256
  LIVE_EXECUTION_ENABLED = 'false'
  BROKER_LIVE_ENABLED = 'false'
  ANOMALY_LIVE_ORDER_ENABLED = 'false'
}
Write-BoundEnvironment -Environment $environment -Updates $updates

[pscustomobject][ordered]@{
  schema_version = 'axio.production-release-env-binding.v1'
  status = 'BOUND'
  environment_path = $environment.Path
  source_commit = $GitCommit
  rights_receipt_sha256 = $rights.Sha256
  technical_entitlement_receipt_sha256 = $technical.Sha256
  owner_attestation_sha256 = $attestation.Sha256
  automatic_execution = 'DISABLED'
  secret_values_printed = $false
} | ConvertTo-Json -Compress
