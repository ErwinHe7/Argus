[CmdletBinding()]
param(
  [Parameter()]
  [ValidateRange(1, 60)]
  [int]$TimeoutSeconds = 15,

  [Parameter()]
  [string]$OutputPath
)

# This utility captures API-level technical entitlement evidence only. It does
# not establish customer display, derived-output publication, or redistribution
# rights and must never be used in place of the private market-data rights
# receipt.

Add-Type -AssemblyName System.Net.Http
Set-StrictMode -Version Latest

$script:DatabentoHost = 'hist.databento.com'
$script:DatabentoDataset = 'EQUS.MINI'
$script:DatabentoSchema = 'ohlcv-1m'
$script:MaximumResponseBytes = 1MB

function Get-LowercaseSha256 {
  param(
    [Parameter(Mandatory)]
    [byte[]]$Bytes
  )

  $hasher = [System.Security.Cryptography.SHA256]::Create()
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

function ConvertFrom-StrictUtf8Json {
  param(
    [Parameter(Mandatory)]
    [byte[]]$Bytes,

    [Parameter(Mandatory)]
    [string]$EndpointPath
  )

  if ($Bytes.Length -eq 0) {
    throw "Databento endpoint '$EndpointPath' returned an empty JSON response."
  }

  $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
  try {
    $text = $utf8.GetString($Bytes)
  } catch {
    throw "Databento endpoint '$EndpointPath' did not return strict UTF-8."
  }

  try {
    $value = $text | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "Databento endpoint '$EndpointPath' did not return valid JSON."
  } finally {
    $text = $null
  }

  if ($null -eq $value) {
    throw "Databento endpoint '$EndpointPath' returned JSON null."
  }
  return $value
}

function ConvertTo-DatabentoUtcInstant {
  param(
    [Parameter(Mandatory)]
    [string]$Value,

    [Parameter(Mandatory)]
    [string]$FieldName
  )

  $match = [regex]::Match(
    $Value,
    '\A(?<base>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(?<fraction>\d{1,9}))?Z\z',
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
  )
  if (-not $match.Success) {
    throw "Databento range field '$FieldName' must be a UTC ISO-8601 timestamp."
  }

  $styles = (
    [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
    [System.Globalization.DateTimeStyles]::AdjustToUniversal
  )
  $culture = [System.Globalization.CultureInfo]::InvariantCulture
  $base = $match.Groups['base'].Value
  $fraction = $match.Groups['fraction'].Value

  try {
    if ($fraction.Length -eq 0) {
      return [DateTimeOffset]::ParseExact(
        "${base}Z",
        "yyyy-MM-dd'T'HH:mm:ss'Z'",
        $culture,
        $styles
      )
    }

    if ($fraction.Length -gt 7) {
      $fraction = $fraction.Substring(0, 7)
    } else {
      $fraction = $fraction.PadRight(7, '0')
    }
    return [DateTimeOffset]::ParseExact(
      "${base}.${fraction}Z",
      "yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'",
      $culture,
      $styles
    )
  } catch {
    throw "Databento range field '$FieldName' is not a valid UTC timestamp."
  }
}

function Get-RequiredStringProperty {
  param(
    [Parameter(Mandatory)]
    [object]$Object,

    [Parameter(Mandatory)]
    [string]$PropertyName,

    [Parameter(Mandatory)]
    [string]$Context
  )

  $property = $Object.PSObject.Properties[$PropertyName]
  if ($null -eq $property -or
      $property.Value -isnot [string] -or
      [string]::IsNullOrWhiteSpace([string]$property.Value)) {
    throw "Databento $Context is missing string field '$PropertyName'."
  }
  return [string]$property.Value
}

function Assert-StringArrayContains {
  param(
    [Parameter(Mandatory)]
    [object]$Value,

    [Parameter(Mandatory)]
    [string]$Expected,

    [Parameter(Mandatory)]
    [string]$Context
  )

  $items = @($Value)
  if ($items.Count -eq 0) {
    throw "Databento $Context returned an empty array."
  }

  $found = $false
  foreach ($item in $items) {
    if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$item)) {
      throw "Databento $Context must contain only non-empty strings."
    }
    if ([string]$item -ceq $Expected) {
      $found = $true
    }
  }

  if (-not $found) {
    throw "Databento $Context did not include required value '$Expected'."
  }
}

function Assert-DatabentoTechnicalEntitlementResponse {
  param(
    [Parameter(Mandatory)]
    [object]$Datasets,

    [Parameter(Mandatory)]
    [object]$Schemas,

    [Parameter(Mandatory)]
    [object]$DatasetRange
  )

  Assert-StringArrayContains `
    -Value $Datasets `
    -Expected $script:DatabentoDataset `
    -Context 'metadata.list_datasets'
  Assert-StringArrayContains `
    -Value $Schemas `
    -Expected $script:DatabentoSchema `
    -Context 'metadata.list_schemas'

  $datasetStartText = Get-RequiredStringProperty `
    -Object $DatasetRange `
    -PropertyName 'start' `
    -Context 'metadata.get_dataset_range'
  $datasetEndText = Get-RequiredStringProperty `
    -Object $DatasetRange `
    -PropertyName 'end' `
    -Context 'metadata.get_dataset_range'

  $schemaProperty = $DatasetRange.PSObject.Properties['schema']
  if ($null -eq $schemaProperty -or $null -eq $schemaProperty.Value) {
    throw "Databento metadata.get_dataset_range is missing the per-schema range object."
  }
  $schemaRangeProperty = $schemaProperty.Value.PSObject.Properties[$script:DatabentoSchema]
  if ($null -eq $schemaRangeProperty -or $null -eq $schemaRangeProperty.Value) {
    throw (
      "Databento metadata.get_dataset_range did not include a range for " +
      "'$($script:DatabentoSchema)'."
    )
  }
  $schemaStartText = Get-RequiredStringProperty `
    -Object $schemaRangeProperty.Value `
    -PropertyName 'start' `
    -Context "metadata.get_dataset_range.schema.$($script:DatabentoSchema)"
  $schemaEndText = Get-RequiredStringProperty `
    -Object $schemaRangeProperty.Value `
    -PropertyName 'end' `
    -Context "metadata.get_dataset_range.schema.$($script:DatabentoSchema)"

  $datasetStart = ConvertTo-DatabentoUtcInstant `
    -Value $datasetStartText `
    -FieldName 'start'
  $datasetEnd = ConvertTo-DatabentoUtcInstant `
    -Value $datasetEndText `
    -FieldName 'end'
  $schemaStart = ConvertTo-DatabentoUtcInstant `
    -Value $schemaStartText `
    -FieldName "schema.$($script:DatabentoSchema).start"
  $schemaEnd = ConvertTo-DatabentoUtcInstant `
    -Value $schemaEndText `
    -FieldName "schema.$($script:DatabentoSchema).end"

  if ($datasetStart -ge $datasetEnd) {
    throw 'Databento dataset range must have a start before its exclusive end.'
  }
  if ($schemaStart -ge $schemaEnd) {
    throw (
      "Databento '$($script:DatabentoSchema)' range must have a start before " +
      'its exclusive end.'
    )
  }
  if ($schemaStart -lt $datasetStart -or $schemaEnd -gt $datasetEnd) {
    throw (
      "Databento '$($script:DatabentoSchema)' range must be contained by the " +
      'dataset range.'
    )
  }

  return [pscustomobject][ordered]@{
    dataset_start = $datasetStartText
    dataset_end = $datasetEndText
    schema = $script:DatabentoSchema
    schema_start = $schemaStartText
    schema_end = $schemaEndText
  }
}

function New-DatabentoMetadataUri {
  param(
    [Parameter(Mandatory)]
    [ValidateSet(
      '/v0/metadata.list_datasets',
      '/v0/metadata.list_schemas',
      '/v0/metadata.get_dataset_range'
    )]
    [string]$Path,

    [Parameter()]
    [switch]$IncludeDatasetQuery
  )

  $builder = [UriBuilder]::new('https', $script:DatabentoHost, 443, $Path)
  if ($IncludeDatasetQuery) {
    $builder.Query = (
      'dataset=' + [Uri]::EscapeDataString($script:DatabentoDataset)
    )
  }
  $uri = $builder.Uri
  if ($uri.Scheme -cne 'https' -or
      $uri.Host -cne $script:DatabentoHost -or
      $uri.Port -ne 443 -or
      -not [string]::IsNullOrEmpty($uri.Fragment) -or
      -not [string]::IsNullOrEmpty($uri.UserInfo)) {
    throw 'Refusing a Databento metadata URI outside the pinned HTTPS origin.'
  }
  return $uri
}

function Invoke-DatabentoJsonEndpoint {
  param(
    [Parameter(Mandatory)]
    [object]$HttpClient,

    [Parameter(Mandatory)]
    [string]$BasicToken,

    [Parameter(Mandatory)]
    [ValidateSet(
      '/v0/metadata.list_datasets',
      '/v0/metadata.list_schemas',
      '/v0/metadata.get_dataset_range'
    )]
    [string]$Path,

    [Parameter()]
    [switch]$IncludeDatasetQuery
  )

  $uri = New-DatabentoMetadataUri `
    -Path $Path `
    -IncludeDatasetQuery:$IncludeDatasetQuery
  $request = $null
  $response = $null
  $bodyBytes = $null
  try {
    $request = [System.Net.Http.HttpRequestMessage]::new(
      [System.Net.Http.HttpMethod]::Get,
      $uri
    )
    $request.Headers.Accept.ParseAdd('application/json')
    $request.Headers.Authorization = (
      [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Basic', $BasicToken)
    )

    try {
      $response = $HttpClient.SendAsync(
        $request,
        [System.Net.Http.HttpCompletionOption]::ResponseContentRead
      ).GetAwaiter().GetResult()
    } catch {
      throw "Databento metadata request failed for '$Path'."
    }

    $statusCode = [int]$response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
      throw "Databento endpoint '$Path' returned HTTP $statusCode; no receipt was written."
    }

    $contentType = $response.Content.Headers.ContentType
    if ($null -eq $contentType -or
        ([string]$contentType.MediaType -cne 'application/json' -and
         -not ([string]$contentType.MediaType).EndsWith('+json'))) {
      throw "Databento endpoint '$Path' did not return an application/json response."
    }

    $declaredLength = $response.Content.Headers.ContentLength
    if ($null -ne $declaredLength -and
        [long]$declaredLength -gt $script:MaximumResponseBytes) {
      throw "Databento endpoint '$Path' exceeded the response-size limit."
    }

    try {
      $bodyBytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
    } catch {
      throw "Databento endpoint '$Path' response could not be read."
    }
    if ($bodyBytes.Length -gt $script:MaximumResponseBytes) {
      throw "Databento endpoint '$Path' exceeded the response-size limit."
    }

    $responseSha256 = Get-LowercaseSha256 -Bytes $bodyBytes
    $json = ConvertFrom-StrictUtf8Json -Bytes $bodyBytes -EndpointPath $Path

    return [pscustomobject]@{
      Json = $json
      Evidence = [pscustomobject][ordered]@{
        host = $uri.Host
        path = $uri.AbsolutePath
        status = $statusCode
        response_sha256 = $responseSha256
      }
    }
  } finally {
    if ($null -ne $bodyBytes) {
      [Array]::Clear($bodyBytes, 0, $bodyBytes.Length)
    }
    if ($null -ne $response) {
      $response.Dispose()
    }
    if ($null -ne $request) {
      $request.Dispose()
    }
  }
}

function Assert-ExactPropertySet {
  param(
    [Parameter(Mandatory)]
    [object]$Object,

    [Parameter(Mandatory)]
    [string[]]$Expected,

    [Parameter(Mandatory)]
    [string]$Context
  )

  $actualNames = @(
    $Object.PSObject.Properties |
      ForEach-Object { $_.Name } |
      Sort-Object
  )
  $expectedNames = @($Expected | Sort-Object)
  if ([string]::Join("`n", $actualNames) -cne
      [string]::Join("`n", $expectedNames)) {
    throw "The $Context object contains fields outside its persistence allowlist."
  }
}

function New-DatabentoTechnicalEntitlementReceipt {
  param(
    [Parameter(Mandatory)]
    [object[]]$EndpointEvidence,

    [Parameter(Mandatory)]
    [object]$ValidatedRange,

    [Parameter(Mandatory)]
    [DateTimeOffset]$CapturedAt
  )

  if ($EndpointEvidence.Count -ne 3) {
    throw 'Exactly three Databento endpoint evidence entries are required.'
  }

  $expectedPaths = @(
    '/v0/metadata.list_datasets',
    '/v0/metadata.list_schemas',
    '/v0/metadata.get_dataset_range'
  )
  for ($index = 0; $index -lt $EndpointEvidence.Count; $index += 1) {
    $endpoint = $EndpointEvidence[$index]
    Assert-ExactPropertySet `
      -Object $endpoint `
      -Expected @('host', 'path', 'status', 'response_sha256') `
      -Context 'endpoint'
    if ([string]$endpoint.host -cne $script:DatabentoHost -or
        [string]$endpoint.path -cne $expectedPaths[$index] -or
        [int]$endpoint.status -lt 200 -or
        [int]$endpoint.status -ge 300 -or
        [string]$endpoint.response_sha256 -cnotmatch '\A[0-9a-f]{64}\z') {
      throw 'Databento endpoint evidence failed its persistence contract.'
    }
  }
  Assert-ExactPropertySet `
    -Object $ValidatedRange `
    -Expected @(
      'dataset_start',
      'dataset_end',
      'schema',
      'schema_start',
      'schema_end'
    ) `
    -Context 'range'

  $receipt = [pscustomobject][ordered]@{
    schema_version = 'axio.databento_technical_entitlement.v1'
    status = 'TECHNICAL_ENTITLEMENT_VERIFIED'
    provider = 'databento'
    product = 'Databento US Equities Mini'
    dataset = $script:DatabentoDataset
    captured_at = $CapturedAt.UtcDateTime.ToString(
      'yyyy-MM-ddTHH:mm:ss.fffZ',
      [System.Globalization.CultureInfo]::InvariantCulture
    )
    endpoints = @($EndpointEvidence)
    entitled = $true
    range = $ValidatedRange
  }

  Assert-ExactPropertySet `
    -Object $receipt `
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
    -Context 'technical entitlement receipt'
  return $receipt
}

function Write-ReceiptAtomically {
  param(
    [Parameter(Mandatory)]
    [object]$Receipt,

    [Parameter(Mandatory)]
    [string]$Destination
  )

  $absoluteDestination = [IO.Path]::GetFullPath($Destination)
  $directory = [IO.Path]::GetDirectoryName($absoluteDestination)
  if ([string]::IsNullOrWhiteSpace($directory)) {
    throw 'The technical entitlement receipt destination must have a parent directory.'
  }

  [void][IO.Directory]::CreateDirectory($directory)
  if ([IO.Directory]::Exists($absoluteDestination)) {
    throw 'The technical entitlement receipt destination is a directory.'
  }

  $json = $Receipt | ConvertTo-Json -Depth 8
  if ($json -match '(?i)authorization|basic\s|DATABENTO_API_KEY|db-[A-Za-z0-9]{20,}') {
    throw 'The technical entitlement receipt failed its secret-exclusion check.'
  }
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json + "`n")
  $temporaryPath = Join-Path $directory (
    ".$([IO.Path]::GetFileName($absoluteDestination))." +
    "$([Guid]::NewGuid().ToString('N')).tmp"
  )

  try {
    $stream = [IO.FileStream]::new(
      $temporaryPath,
      [IO.FileMode]::CreateNew,
      [IO.FileAccess]::Write,
      [IO.FileShare]::None,
      4096,
      [IO.FileOptions]::WriteThrough
    )
    try {
      $stream.Write($bytes, 0, $bytes.Length)
      $stream.Flush($true)
    } finally {
      $stream.Dispose()
    }

    if ([IO.File]::Exists($absoluteDestination)) {
      [IO.File]::Replace($temporaryPath, $absoluteDestination, $null, $true)
    } else {
      [IO.File]::Move($temporaryPath, $absoluteDestination)
    }
  } finally {
    [Array]::Clear($bytes, 0, $bytes.Length)
    if ([IO.File]::Exists($temporaryPath)) {
      [IO.File]::Delete($temporaryPath)
    }
  }

  return $absoluteDestination
}

function Invoke-DatabentoTechnicalEntitlementCapture {
  param(
    [Parameter(Mandatory)]
    [ValidateRange(1, 60)]
    [int]$RequestTimeoutSeconds,

    [Parameter()]
    [string]$Destination
  )

  if ([string]::IsNullOrWhiteSpace($Destination)) {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $Destination = Join-Path $repositoryRoot (
      'quant_engine_rs\data\evidence\' +
      'databento_technical_entitlement_latest.json'
    )
  }
  $Destination = [IO.Path]::GetFullPath($Destination)
  if ([IO.Path]::GetFileName($Destination) -ieq
      'market_data_rights_receipt.json') {
    throw (
      'Refusing to write technical entitlement evidence over the separate ' +
      'market-data rights receipt.'
    )
  }

  $apiKey = [Environment]::GetEnvironmentVariable(
    'DATABENTO_API_KEY',
    [EnvironmentVariableTarget]::Process
  )
  if ([string]::IsNullOrWhiteSpace($apiKey) -or
      $apiKey.Length -ne 32 -or
      -not $apiKey.StartsWith('db-', [StringComparison]::Ordinal)) {
    $apiKey = $null
    throw 'DATABENTO_API_KEY is missing or has an unexpected format.'
  }

  $authBytes = $null
  $basicToken = $null
  $handler = $null
  $client = $null
  try {
    # Databento HTTP Basic authentication uses the API key as the username and
    # an empty password. The credential and encoded header stay in this process.
    $authBytes = [Text.Encoding]::ASCII.GetBytes($apiKey + ':')
    $basicToken = [Convert]::ToBase64String($authBytes)
    $apiKey = $null
    [Array]::Clear($authBytes, 0, $authBytes.Length)
    $authBytes = $null

    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $handler.UseCookies = $false
    $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::None
    $handler.SslProtocols = [System.Security.Authentication.SslProtocols]::Tls12
    $handler.CheckCertificateRevocationList = $true

    $client = [System.Net.Http.HttpClient]::new($handler, $true)
    $handler = $null
    $client.Timeout = [TimeSpan]::FromSeconds($RequestTimeoutSeconds)
    $client.MaxResponseContentBufferSize = $script:MaximumResponseBytes

    $datasetsResult = Invoke-DatabentoJsonEndpoint `
      -HttpClient $client `
      -BasicToken $basicToken `
      -Path '/v0/metadata.list_datasets'
    $schemasResult = Invoke-DatabentoJsonEndpoint `
      -HttpClient $client `
      -BasicToken $basicToken `
      -Path '/v0/metadata.list_schemas' `
      -IncludeDatasetQuery
    $rangeResult = Invoke-DatabentoJsonEndpoint `
      -HttpClient $client `
      -BasicToken $basicToken `
      -Path '/v0/metadata.get_dataset_range' `
      -IncludeDatasetQuery

    $validatedRange = Assert-DatabentoTechnicalEntitlementResponse `
      -Datasets $datasetsResult.Json `
      -Schemas $schemasResult.Json `
      -DatasetRange $rangeResult.Json
    $receipt = New-DatabentoTechnicalEntitlementReceipt `
      -EndpointEvidence @(
        $datasetsResult.Evidence,
        $schemasResult.Evidence,
        $rangeResult.Evidence
      ) `
      -ValidatedRange $validatedRange `
      -CapturedAt ([DateTimeOffset]::UtcNow)

    # No destination is touched until every endpoint and semantic validation has
    # succeeded. The same-directory replace preserves the last successful file
    # if any request, validation, serialization, or staging write fails.
    return Write-ReceiptAtomically -Receipt $receipt -Destination $Destination
  } finally {
    $apiKey = $null
    $basicToken = $null
    if ($null -ne $authBytes) {
      [Array]::Clear($authBytes, 0, $authBytes.Length)
    }
    if ($null -ne $client) {
      $client.Dispose()
    } elseif ($null -ne $handler) {
      $handler.Dispose()
    }
  }
}

if ($MyInvocation.InvocationName -ne '.') {
  try {
    $writtenPath = Invoke-DatabentoTechnicalEntitlementCapture `
      -RequestTimeoutSeconds $TimeoutSeconds `
      -Destination $OutputPath
    Write-Output "Technical entitlement receipt written to: $writtenPath"
    Write-Output (
      'This receipt proves API-level metadata entitlement only; it grants no ' +
      'public-display, model-publication, or redistribution rights.'
    )
  } catch {
    Write-Error $_.Exception.Message
    exit 1
  }
}
