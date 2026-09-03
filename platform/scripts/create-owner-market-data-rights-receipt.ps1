[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$OwnerHandle,

  [Parameter(Mandatory)]
  [string]$OwnerSignature,

  [Parameter(Mandatory)]
  [string]$LegalEntity,

  [Parameter(Mandatory)]
  [string]$PlanName,

  [Parameter(Mandatory)]
  [ValidateSet('ACTIVE')]
  [string]$PlanStatus,

  [Parameter(Mandatory)]
  [string]$AccountReference,

  [Parameter(Mandatory)]
  [string]$SubscriptionReference,

  [Parameter(Mandatory)]
  [ValidateSet('VENDOR_SUBSCRIPTION_ID', 'OWNER_DEFINED_NOT_VENDOR_ID')]
  [string]$SubscriptionReferenceKind,

  [Parameter(Mandatory)]
  [bool]$ModelInputPermitted,

  [Parameter(Mandatory)]
  [bool]$CustomerExternalDisplayPermitted,

  [Parameter(Mandatory)]
  [bool]$DerivedOutputPublicationPermitted,

  [Parameter(Mandatory)]
  [bool]$RawDataRedistributionPermitted,

  [Parameter(Mandatory)]
  [string]$AttestedAt,

  [Parameter(Mandatory)]
  [string]$ValidFrom,

  [Parameter(Mandatory)]
  [string]$ValidUntil,

  [Parameter(Mandatory)]
  [string]$ReviewerHandle,

  [Parameter(Mandatory)]
  [string]$ReviewedAt,

  [Parameter(Mandatory)]
  [string]$ReviewDueAt,

  [Parameter(Mandatory)]
  [string]$OfficialTermsUrl,

  [Parameter(Mandatory)]
  [string]$OfficialProductUrl,

  [Parameter()]
  [string]$TechnicalEntitlementReceiptPath,

  [Parameter()]
  [string]$RuntimeRoot,

  [Parameter()]
  [string]$QuantctlPath,

  [Parameter()]
  [string]$ConfigPath
)

# This utility records an authenticated account owner's explicit attestation.
# It does not claim vendor confirmation, does not enable raw redistribution,
# does not read a market-data credential, and does not place orders.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Provider = 'databento'
$script:Product = 'EQUS.MINI'
$script:RightsSchema = 'axio.market_data_rights.v2'
$script:AttestationSchema = 'axio.account_owner_market_data_attestation.v1'
$script:TechnicalSchema = 'axio.databento_technical_entitlement.v1'
$script:MaximumTechnicalReceiptBytes = 64KB

function Assert-SafeLabel {
  param(
    [Parameter(Mandatory)]
    [string]$Value,

    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter(Mandatory)]
    [int]$MaximumLength
  )

  $hasControlCharacter = @(
    $Value.ToCharArray() | Where-Object { [char]::IsControl($_) }
  ).Count -gt 0
  if ([string]::IsNullOrWhiteSpace($Value) -or
      $Value -cne $Value.Trim() -or
      $Value.Length -gt $MaximumLength -or
      $hasControlCharacter) {
    throw "$Name is missing or is not a safe single-line value."
  }
}

function ConvertTo-StrictUtcInstant {
  param(
    [Parameter(Mandatory)]
    [string]$Value,

    [Parameter(Mandatory)]
    [string]$Name
  )

  if ($Value -cnotmatch '\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?Z\z') {
    throw "$Name must be an explicit UTC RFC3339 instant ending in Z."
  }
  $styles = (
    [Globalization.DateTimeStyles]::AssumeUniversal -bor
    [Globalization.DateTimeStyles]::AdjustToUniversal
  )
  try {
    return [DateTimeOffset]::Parse(
      $Value,
      [Globalization.CultureInfo]::InvariantCulture,
      $styles
    )
  } catch {
    throw "$Name is not a valid UTC instant."
  }
}

function ConvertTo-CanonicalUtcText {
  param(
    [Parameter(Mandatory)]
    [DateTimeOffset]$Value
  )

  return $Value.UtcDateTime.ToString(
    'yyyy-MM-ddTHH:mm:ss.fffZ',
    [Globalization.CultureInfo]::InvariantCulture
  )
}

function Get-LowercaseSha256 {
  param(
    [Parameter(Mandatory)]
    [byte[]]$Bytes
  )

  $hasher = [Security.Cryptography.SHA256]::Create()
  try {
    $digest = $hasher.ComputeHash($Bytes)
    try {
      return ([BitConverter]::ToString($digest)).Replace('-', '').ToLowerInvariant()
    } finally {
      [Array]::Clear($digest, 0, $digest.Length)
    }
  } finally {
    $hasher.Dispose()
  }
}

function Get-DomainSeparatedReferenceHash {
  param(
    [Parameter(Mandatory)]
    [string]$Domain,

    [Parameter(Mandatory)]
    [string]$Reference
  )

  Assert-SafeLabel -Value $Reference -Name $Domain -MaximumLength 1024
  $salt = [byte[]]::new(32)
  $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $generator.GetBytes($salt)
  } finally {
    $generator.Dispose()
  }
  $payload = $null
  try {
    $saltText = [Convert]::ToBase64String($salt)
    $payload = [Text.UTF8Encoding]::new($false).GetBytes(
      "AXIO7`0$Domain`0$($script:Provider)`0$($script:Product)`0$Reference`0$saltText"
    )
    return Get-LowercaseSha256 -Bytes $payload
  } finally {
    if ($null -ne $payload) {
      [Array]::Clear($payload, 0, $payload.Length)
    }
    [Array]::Clear($salt, 0, $salt.Length)
  }
}

function ConvertTo-JsonBytes {
  param(
    [Parameter(Mandatory)]
    [object]$Value
  )

  $json = $Value | ConvertTo-Json -Depth 12
  return [Text.UTF8Encoding]::new($false).GetBytes($json + "`n")
}

function Assert-ExactPropertySet {
  param(
    [Parameter(Mandatory)]
    [object]$Value,

    [Parameter(Mandatory)]
    [string[]]$Expected,

    [Parameter(Mandatory)]
    [string]$Context
  )

  $actual = @($Value.PSObject.Properties.Name | Sort-Object)
  $expectedSorted = @($Expected | Sort-Object)
  if ($actual.Count -ne $expectedSorted.Count) {
    throw "$Context has an unexpected field set."
  }
  for ($index = 0; $index -lt $actual.Count; $index += 1) {
    if ($actual[$index] -cne $expectedSorted[$index]) {
      throw "$Context has an unexpected field set."
    }
  }
}

function Read-TechnicalEntitlementReceipt {
  param(
    [Parameter(Mandatory)]
    [string]$Path
  )

  $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
  $item = Get-Item -LiteralPath $resolved -Force
  if (-not $item.PSIsContainer -and
      $item.Length -gt 0 -and
      $item.Length -le $script:MaximumTechnicalReceiptBytes) {
    $bytes = [IO.File]::ReadAllBytes($item.FullName)
  } else {
    throw 'The technical-entitlement receipt is missing, empty, or oversized.'
  }
  $utf8 = [Text.UTF8Encoding]::new($false, $true)
  try {
    $text = $utf8.GetString($bytes)
    if ($text -match '(?i)authorization|basic\s|api[_-]?key|credential|secret|token') {
      throw 'The technical-entitlement receipt contains a forbidden secret-bearing field.'
    }
    $value = $text | ConvertFrom-Json -ErrorAction Stop
  } catch {
    [Array]::Clear($bytes, 0, $bytes.Length)
    throw 'The technical-entitlement receipt is not strict, secret-safe JSON.'
  } finally {
    $text = $null
  }
  Assert-ExactPropertySet `
    -Value $value `
    -Expected @(
      'schema_version',
      'status',
      'provider',
      'product',
      'dataset',
      'captured_at',
      'endpoints',
      'entitled',
      'range'
    ) `
    -Context 'technical-entitlement receipt'
  if ([string]$value.schema_version -cne $script:TechnicalSchema -or
      [string]$value.status -cne 'TECHNICAL_ENTITLEMENT_VERIFIED' -or
      [string]$value.provider -cne $script:Provider -or
      [string]$value.dataset -cne $script:Product -or
      $value.entitled -ne $true) {
    [Array]::Clear($bytes, 0, $bytes.Length)
    throw 'The technical-entitlement receipt identity or status is invalid.'
  }
  return [pscustomobject]@{
    bytes = $bytes
    sha256 = Get-LowercaseSha256 -Bytes $bytes
  }
}

function Write-AtomicBytes {
  param(
    [Parameter(Mandatory)]
    [string]$Destination,

    [Parameter(Mandatory)]
    [byte[]]$Bytes
  )

  $absolute = [IO.Path]::GetFullPath($Destination)
  $directory = [IO.Path]::GetDirectoryName($absolute)
  if ([string]::IsNullOrWhiteSpace($directory)) {
    throw 'An output destination is missing its parent directory.'
  }
  [void][IO.Directory]::CreateDirectory($directory)
  if ([IO.Directory]::Exists($absolute)) {
    throw 'An output destination is a directory.'
  }
  $temporary = Join-Path $directory (
    ".$([IO.Path]::GetFileName($absolute)).$([Guid]::NewGuid().ToString('N')).tmp"
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
      $stream.Write($Bytes, 0, $Bytes.Length)
      $stream.Flush($true)
    } finally {
      $stream.Dispose()
    }
    if ([IO.File]::Exists($absolute)) {
      [IO.File]::Replace($temporary, $absolute, $null, $true)
    } else {
      [IO.File]::Move($temporary, $absolute)
    }
  } finally {
    if ([IO.File]::Exists($temporary)) {
      [IO.File]::Delete($temporary)
    }
  }
  return $absolute
}

function Assert-OwnerAttestationInputs {
  if ($OwnerSignature -cne $OwnerHandle) {
    throw 'OwnerSignature must exactly match OwnerHandle.'
  }
  Assert-SafeLabel -Value $OwnerHandle -Name 'OwnerHandle' -MaximumLength 128
  Assert-SafeLabel -Value $LegalEntity -Name 'LegalEntity' -MaximumLength 256
  Assert-SafeLabel -Value $PlanName -Name 'PlanName' -MaximumLength 128
  Assert-SafeLabel -Value $ReviewerHandle -Name 'ReviewerHandle' -MaximumLength 128
  if ($OwnerHandle.ToLowerInvariant().Contains($script:Provider) -or
      $OwnerHandle.ToLowerInvariant().Contains('databento.com')) {
    throw 'OwnerHandle must not imply that the attestation was issued by Databento.'
  }
  if (-not $ModelInputPermitted -or
      -not $CustomerExternalDisplayPermitted -or
      -not $DerivedOutputPublicationPermitted) {
    throw 'All three derived-product scopes must be explicitly true.'
  }
  if ($RawDataRedistributionPermitted) {
    throw 'Raw-data redistribution must remain false for owner attestation.'
  }
}

function Resolve-QuantctlExecutable {
  param(
    [Parameter(Mandatory)]
    [string]$RepositoryRoot
  )

  if (-not [string]::IsNullOrWhiteSpace($QuantctlPath)) {
    return (Resolve-Path -LiteralPath $QuantctlPath -ErrorAction Stop).Path
  }
  foreach ($candidate in @(
    (Join-Path $RepositoryRoot 'quant_engine_rs\target\release\quantctl.exe'),
    (Join-Path $RepositoryRoot 'quant_engine_rs\target\debug\quantctl.exe'),
    (Join-Path $RepositoryRoot 'quant_engine_rs\target\release\quantctl'),
    (Join-Path $RepositoryRoot 'quant_engine_rs\target\debug\quantctl')
  )) {
    if ([IO.File]::Exists($candidate)) {
      return [IO.Path]::GetFullPath($candidate)
    }
  }
  throw (
    'quantctl is required for same-parser validation. Build it with ' +
    '`cargo build --locked --bin quantctl` in quant_engine_rs, or pass -QuantctlPath.'
  )
}

function Invoke-RustRightsValidation {
  param(
    [Parameter(Mandatory)]
    [string]$Executable,

    [Parameter(Mandatory)]
    [string]$Configuration,

    [Parameter(Mandatory)]
    [string]$DataRoot,

    [Parameter(Mandatory)]
    [string]$ReceiptSha256
  )

  $output = @(
    & $Executable `
      --config $Configuration `
      data validate-market-data-rights `
      --data-root $DataRoot `
      --provider $script:Provider `
      --product $script:Product `
      --receipt-sha256 $ReceiptSha256 2>&1
  )
  if ($LASTEXITCODE -ne 0) {
    throw 'The shared Rust market-data rights validator rejected the staged receipt.'
  }
  try {
    $validation = ($output -join [Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw 'The shared Rust market-data rights validator returned an invalid response.'
  }
  if ([string]$validation.status -cne 'READY' -or
      [string]$validation.reason -cne 'OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT') {
    throw 'The shared Rust validator did not return the owner-attested ready basis.'
  }
}

function Remove-PrivateValidationRoot {
  param(
    [Parameter(Mandatory)]
    [string]$ValidationRoot,

    [Parameter(Mandatory)]
    [string]$ApprovedRuntimeRoot
  )

  $absoluteValidation = [IO.Path]::GetFullPath($ValidationRoot)
  $absoluteRuntime = [IO.Path]::GetFullPath($ApprovedRuntimeRoot).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
  )
  $requiredPrefix = $absoluteRuntime + [IO.Path]::DirectorySeparatorChar
  if (-not $absoluteValidation.StartsWith(
      $requiredPrefix,
      [StringComparison]::OrdinalIgnoreCase
    ) -or
    [IO.Path]::GetFileName($absoluteValidation) -cnotlike '.owner-rights-validation-*') {
    throw 'Refusing to remove a validation path outside the approved runtime root.'
  }
  if ([IO.Directory]::Exists($absoluteValidation)) {
    Remove-Item -LiteralPath $absoluteValidation -Recurse -Force
  }
}

function Invoke-OwnerMarketDataRightsReceiptCreation {
  $repositoryRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
  if ([string]::IsNullOrWhiteSpace($RuntimeRoot)) {
    $RuntimeRoot = Join-Path $repositoryRoot 'infra\single-vm\runtime'
  }
  if ([string]::IsNullOrWhiteSpace($TechnicalEntitlementReceiptPath)) {
    $TechnicalEntitlementReceiptPath = Join-Path $repositoryRoot (
      'quant_engine_rs\data\evidence\' +
      'databento_technical_entitlement_latest.json'
    )
  }
  if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $repositoryRoot 'quant_engine_rs\configs\production.yaml'
  }

  Assert-OwnerAttestationInputs
  $attested = ConvertTo-StrictUtcInstant -Value $AttestedAt -Name 'AttestedAt'
  $validFromInstant = ConvertTo-StrictUtcInstant -Value $ValidFrom -Name 'ValidFrom'
  $validUntilInstant = ConvertTo-StrictUtcInstant -Value $ValidUntil -Name 'ValidUntil'
  $reviewed = ConvertTo-StrictUtcInstant -Value $ReviewedAt -Name 'ReviewedAt'
  $reviewDue = ConvertTo-StrictUtcInstant -Value $ReviewDueAt -Name 'ReviewDueAt'
  $now = [DateTimeOffset]::UtcNow
  if ($validFromInstant -ge $validUntilInstant -or
      $now -lt $validFromInstant -or
      $now -gt $validUntilInstant -or
      $attested -lt $validFromInstant -or
      $attested -gt $reviewed -or
      $reviewed -gt $now -or
      $reviewDue -le $reviewed -or
      $reviewDue -le $now -or
      $reviewDue -gt $validUntilInstant) {
    throw 'The attestation, validity, and review clocks are inconsistent or inactive.'
  }

  $technical = Read-TechnicalEntitlementReceipt `
    -Path $TechnicalEntitlementReceiptPath
  $runtime = [IO.Path]::GetFullPath($RuntimeRoot)
  [void][IO.Directory]::CreateDirectory($runtime)
  $configuration = (Resolve-Path -LiteralPath $ConfigPath -ErrorAction Stop).Path
  $quantctl = Resolve-QuantctlExecutable -RepositoryRoot $repositoryRoot

  $accountLicenseHash = Get-DomainSeparatedReferenceHash `
    -Domain 'ACCOUNT_LICENSE_REFERENCE' `
    -Reference $AccountReference
  $accountIdentityHash = Get-DomainSeparatedReferenceHash `
    -Domain 'ACCOUNT_IDENTITY' `
    -Reference $AccountReference
  $subscriptionIdentityHash = Get-DomainSeparatedReferenceHash `
    -Domain "SUBSCRIPTION_IDENTITY:$SubscriptionReferenceKind" `
    -Reference $SubscriptionReference
  $AccountReference = $null
  $SubscriptionReference = $null

  $attestedText = ConvertTo-CanonicalUtcText -Value $attested
  $validFromText = ConvertTo-CanonicalUtcText -Value $validFromInstant
  $validUntilText = ConvertTo-CanonicalUtcText -Value $validUntilInstant
  $reviewedText = ConvertTo-CanonicalUtcText -Value $reviewed
  $reviewDueText = ConvertTo-CanonicalUtcText -Value $reviewDue

  $attestation = [pscustomobject][ordered]@{
    schema_version = $script:AttestationSchema
    evidence_kind = 'ACCOUNT_OWNER_ATTESTATION'
    evidence_basis = 'OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT'
    provider = $script:Provider
    product = $script:Product
    owner_handle = $OwnerHandle
    issuer_role = 'ACCOUNT_OWNER'
    legal_entity = $LegalEntity
    plan_name = $PlanName
    plan_status = $PlanStatus
    identity_bindings = [pscustomobject][ordered]@{
      account_license_reference_sha256 = $accountLicenseHash
      account_identity_sha256 = $accountIdentityHash
      subscription_reference_kind = $SubscriptionReferenceKind
      subscription_identity_sha256 = $subscriptionIdentityHash
    }
    permitted_uses = [pscustomobject][ordered]@{
      model_input = $true
      customer_external_display = $true
      derived_output_publication = $true
      raw_data_redistribution = $false
    }
    technical_entitlement_receipt_sha256 = $technical.sha256
    official_terms_url = $OfficialTermsUrl
    official_product_url = $OfficialProductUrl
    attestation_statement = (
      'As the account owner, I attest that the identified active subscription ' +
      'permits market data as model input, customer-facing external display, ' +
      'and publication of derived model outputs to paid AXIO7 subscribers. ' +
      'This attestation does not authorize raw-data redistribution and is not ' +
      'represented as vendor-issued confirmation. The subscription reference ' +
      $(if ($SubscriptionReferenceKind -ceq 'OWNER_DEFINED_NOT_VENDOR_ID') {
          'is an owner-defined local binding, not a vendor subscription ID.'
        } else {
          'is identified by the account owner as a vendor subscription ID.'
        })
    )
    signature = [pscustomobject][ordered]@{
      kind = 'AUTHENTICATED_REPOSITORY_OWNER_HANDLE'
      signed_by = $OwnerSignature
      signed_at = $attestedText
    }
    valid_from = $validFromText
    valid_until = $validUntilText
    reviewed_by = $ReviewerHandle
    reviewed_at = $reviewedText
    review_due_at = $reviewDueText
  }
  $attestationBytes = ConvertTo-JsonBytes -Value $attestation
  $attestationSha256 = Get-LowercaseSha256 -Bytes $attestationBytes

  $rights = [pscustomobject][ordered]@{
    schema_version = $script:RightsSchema
    provider = $script:Provider
    product = $script:Product
    legal_entity = $LegalEntity
    plan_name = $PlanName
    plan_status = $PlanStatus
    permitted_uses = [pscustomobject][ordered]@{
      model_input = $true
      customer_external_display = $true
      derived_output_publication = $true
      raw_data_redistribution = $false
    }
    evidence_kind = 'ACCOUNT_OWNER_ATTESTATION'
    evidence_artifact_sha256 = $attestationSha256
    account_license_reference_sha256 = $accountLicenseHash
    official_terms_url = $OfficialTermsUrl
    official_product_url = $OfficialProductUrl
    owner_attestation = [pscustomobject][ordered]@{
      issuer_role = 'ACCOUNT_OWNER'
      signed_at = $attestedText
      account_identity_sha256 = $accountIdentityHash
      subscription_reference_kind = $SubscriptionReferenceKind
      subscription_identity_sha256 = $subscriptionIdentityHash
      technical_entitlement_receipt_sha256 = $technical.sha256
    }
    valid_from = $validFromText
    valid_until = $validUntilText
    issuer = $OwnerHandle
    reviewer = $ReviewerHandle
    issued_at = $attestedText
    reviewed_at = $reviewedText
    review_due_at = $reviewDueText
  }
  $rightsBytes = ConvertTo-JsonBytes -Value $rights
  $rightsSha256 = Get-LowercaseSha256 -Bytes $rightsBytes
  $hashes = @(
    $attestationSha256,
    $technical.sha256,
    $rightsSha256,
    $accountLicenseHash,
    $accountIdentityHash,
    $subscriptionIdentityHash
  )
  if (($hashes | Select-Object -Unique).Count -ne $hashes.Count) {
    throw 'Owner-attestation hashes must be pairwise distinct.'
  }

  $validationRoot = Join-Path $runtime (
    ".owner-rights-validation-$([Guid]::NewGuid().ToString('N'))"
  )
  try {
    Write-AtomicBytes `
      -Destination (Join-Path $validationRoot 'rights\market_data_rights_receipt.json') `
      -Bytes $rightsBytes | Out-Null
    Write-AtomicBytes `
      -Destination (Join-Path $validationRoot 'evidence\databento_technical_entitlement_latest.json') `
      -Bytes $technical.bytes | Out-Null
    Invoke-RustRightsValidation `
      -Executable $quantctl `
      -Configuration $configuration `
      -DataRoot $validationRoot `
      -ReceiptSha256 $rightsSha256

    $technicalOutput = Write-AtomicBytes `
      -Destination (Join-Path $runtime 'quant-evidence\databento_technical_entitlement_latest.json') `
      -Bytes $technical.bytes
    $attestationOutput = Write-AtomicBytes `
      -Destination (Join-Path $runtime 'private-rights-evidence\account_owner_attestation.json') `
      -Bytes $attestationBytes
    # Commit the authorization receipt last, after both dependencies exist and
    # the shared Rust parser has accepted the exact staged bytes.
    $rightsOutput = Write-AtomicBytes `
      -Destination (Join-Path $runtime 'quant-rights\market_data_rights_receipt.json') `
      -Bytes $rightsBytes
  } finally {
    Remove-PrivateValidationRoot `
      -ValidationRoot $validationRoot `
      -ApprovedRuntimeRoot $runtime
    [Array]::Clear($technical.bytes, 0, $technical.bytes.Length)
    [Array]::Clear($attestationBytes, 0, $attestationBytes.Length)
    [Array]::Clear($rightsBytes, 0, $rightsBytes.Length)
  }

  [pscustomobject][ordered]@{
    attestation_path = $attestationOutput
    attestation_sha256 = $attestationSha256
    technical_entitlement_receipt_path = $technicalOutput
    technical_entitlement_receipt_sha256 = $technical.sha256
    rights_receipt_path = $rightsOutput
    rights_receipt_sha256 = $rightsSha256
  } | ConvertTo-Json -Compress
}

Invoke-OwnerMarketDataRightsReceiptCreation
