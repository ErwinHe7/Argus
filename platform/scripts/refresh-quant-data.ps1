[CmdletBinding()]
param(
  [ValidateRange(1, 365)]
  [int]$LookbackDays = 3,

  [switch]$SkipSlowRegime,

  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$quantRoot = Join-Path $workspaceRoot 'quant_engine_rs'
$quantCtlPath = Join-Path $PSScriptRoot 'quantctl.ps1'
$productionConfigPath = Join-Path $quantRoot 'configs\production.yaml'
$normalizedPath = Join-Path $quantRoot 'data\normalized\market_bars.csv'
$manifestRoot = Join-Path $quantRoot 'data\manifests'
$qualityRoot = Join-Path $quantRoot 'data\quality'
$receiptPath = Join-Path $qualityRoot 'refresh_receipt_latest.json'
$lockPath = Join-Path $qualityRoot 'refresh-quant-data.lock'
$runId = [Guid]::NewGuid().ToString('N')
$startedAt = [DateTimeOffset]::UtcNow
$stagingRoot = Join-Path $qualityRoot ".refresh-staging-$runId"
$stagingNormalizedRoot = Join-Path $stagingRoot 'normalized'
$stagingNormalizedPath = Join-Path $stagingNormalizedRoot 'market_bars.csv'
$stagingManifestRoot = Join-Path $stagingRoot 'manifests'
$stagingOutputRoot = Join-Path $stagingRoot 'outputs'
$stagingConfigPath = Join-Path $stagingRoot 'production.refresh.yaml'
$stagedCapabilityPath = Join-Path $stagingOutputRoot 'data_capability_latest.json'
$stagedPredictorPath = Join-Path $stagingOutputRoot 'predictor_candidate_latest.json'
$stagedForecastPath = Join-Path $stagingOutputRoot 'forecast_contract_latest.json'
$stagedRegimePath = Join-Path $stagingOutputRoot 'regime_latest.json'
$finalCapabilityPath = Join-Path $qualityRoot 'data_capability_latest.json'
$finalPredictorPath = Join-Path $quantRoot 'data\models\predictor_candidate_latest.json'
$finalForecastPath = Join-Path $quantRoot 'data\reports\forecast_contract_latest.json'
$finalRegimePath = Join-Path $quantRoot 'data\reports\regime_latest.json'
$relativeNormalizedPath = 'data/normalized/market_bars.csv'
$stepReceipts = [System.Collections.Generic.List[object]]::new()
$publishedFiles = [System.Collections.Generic.List[object]]::new()
$lockStream = $null
$refreshSucceeded = $false

function ConvertTo-CanonicalUtc {
  param(
    [Parameter(Mandatory = $true)]
    [DateTimeOffset]$Value
  )

  return $Value.ToUniversalTime().ToString(
    "yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'",
    [Globalization.CultureInfo]::InvariantCulture
  )
}

function ConvertFrom-JsonFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required JSON artifact is missing: $Path"
  }

  try {
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  } catch {
    throw "Invalid JSON artifact '$Path': $($_.Exception.Message)"
  }
}

function Set-JsonProperty {
  param(
    [Parameter(Mandatory = $true)]
    [psobject]$InputObject,

    [Parameter(Mandatory = $true)]
    [string]$Name,

    [AllowNull()]
    [object]$Value
  )

  $property = $InputObject.PSObject.Properties[$Name]
  if ($null -eq $property) {
    $InputObject | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
  } else {
    $property.Value = $Value
  }
}

function Write-Utf8Json {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Value,

    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }

  $json = $Value | ConvertTo-Json -Depth 100
  [IO.File]::WriteAllText(
    $Path,
    $json + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false)
  )
}

function Assert-RefreshInvariant {
  param(
    [Parameter(Mandatory = $true)]
    [bool]$Condition,

    [Parameter(Mandatory = $true)]
    [string]$Message
  )

  if (-not $Condition) {
    throw "Refresh consistency check failed: $Message"
  }
}

function Get-WorkspaceRelativePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $fullRoot = [IO.Path]::GetFullPath($workspaceRoot).TrimEnd('\', '/')
  $fullPath = [IO.Path]::GetFullPath($Path)
  $requiredPrefix = $fullRoot + [IO.Path]::DirectorySeparatorChar
  if (-not $fullPath.StartsWith(
      $requiredPrefix,
      [StringComparison]::OrdinalIgnoreCase
    )) {
    throw "Cannot create workspace-relative path for '$fullPath'."
  }
  return $fullPath.Substring($requiredPrefix.Length).Replace('\', '/')
}

function Invoke-QuantStep {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  $stepStarted = [DateTimeOffset]::UtcNow
  Write-Host "[$Name] starting"
  $global:LASTEXITCODE = 0
  & $script:quantCtlPath @Arguments
  $exitCode = $LASTEXITCODE
  $stepCompleted = [DateTimeOffset]::UtcNow
  $stepReceipts.Add([pscustomobject][ordered]@{
      name = $Name
      started_at = ConvertTo-CanonicalUtc $stepStarted
      completed_at = ConvertTo-CanonicalUtc $stepCompleted
      duration_seconds = [Math]::Round(($stepCompleted - $stepStarted).TotalSeconds, 3)
      exit_code = $exitCode
    })

  if ($exitCode -ne 0) {
    throw "Step '$Name' failed with exit code $exitCode."
  }
  Write-Host "[$Name] completed"
}

function New-HardLinkOrCopy {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Source,

    [Parameter(Mandatory = $true)]
    [string]$Destination
  )

  $parent = Split-Path -Parent $Destination
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }

  try {
    New-Item -ItemType HardLink -Path $Destination -Target $Source -ErrorAction Stop | Out-Null
  } catch {
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
  }
}

function Set-YamlPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Content,

    [Parameter(Mandatory = $true)]
    [string]$Key,

    [Parameter(Mandatory = $true)]
    [string]$Value
  )

  $pattern = "(?m)^(?<indent>\s*)$([Regex]::Escape($Key)):\s*[^\r\n#]+(?:\s*#.*)?$"
  $matches = [Regex]::Matches($Content, $pattern)
  if ($matches.Count -ne 1) {
    throw "Expected exactly one '$Key' setting in production config; found $($matches.Count)."
  }

  $portableValue = $Value.Replace('\', '/').Replace('"', '\"')
  return [Regex]::Replace(
    $Content,
    $pattern,
    {
      param($match)
      return "$($match.Groups['indent'].Value)$Key`: `"$portableValue`""
    }
  )
}

function Get-NormalizedSummary {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$TargetSymbol
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Normalized market-bar file is missing: $Path"
  }

  $sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  $reader = [IO.File]::OpenText($Path)
  $rowCount = 0L
  $coverageStart = $null
  $coverageEnd = $null
  $targetLatest = $null
  $targetSessions = [Collections.Generic.SortedSet[string]]::new(
    [StringComparer]::Ordinal
  )

  try {
    $headerLine = $reader.ReadLine()
    if ([string]::IsNullOrWhiteSpace($headerLine)) {
      throw 'Normalized market-bar file has no CSV header.'
    }
    $headers = $headerLine.Split(',')
    $timestampIndex = [Array]::IndexOf($headers, 'timestamp')
    $symbolIndex = [Array]::IndexOf($headers, 'symbol')
    if ($timestampIndex -lt 0 -or $symbolIndex -lt 0) {
      throw 'Normalized market-bar CSV must contain timestamp and symbol columns.'
    }
    $minimumColumns = [Math]::Max($timestampIndex, $symbolIndex) + 1

    while (($line = $reader.ReadLine()) -ne $null) {
      if ([string]::IsNullOrWhiteSpace($line)) {
        continue
      }
      $columns = $line.Split(',')
      if ($columns.Length -lt $minimumColumns) {
        throw "Malformed normalized CSV row after data row $rowCount."
      }

      $timestamp = [DateTimeOffset]::Parse(
        $columns[$timestampIndex].Trim('"'),
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AssumeUniversal
      ).ToUniversalTime()
      $symbol = $columns[$symbolIndex].Trim('"')
      $rowCount++

      if ($null -eq $coverageStart -or $timestamp -lt $coverageStart) {
        $coverageStart = $timestamp
      }
      if ($null -eq $coverageEnd -or $timestamp -gt $coverageEnd) {
        $coverageEnd = $timestamp
      }
      if ($symbol.Equals($TargetSymbol, [StringComparison]::OrdinalIgnoreCase)) {
        if ($null -eq $targetLatest -or $timestamp -gt $targetLatest) {
          $targetLatest = $timestamp
        }
        $null = $targetSessions.Add($timestamp.ToString('yyyy-MM-dd'))
      }
    }
  } finally {
    $reader.Dispose()
  }

  if ($rowCount -le 0 -or $null -eq $coverageEnd) {
    throw 'Normalized market-bar file contains no data rows.'
  }
  if ($null -eq $targetLatest -or $targetSessions.Count -lt 2) {
    throw "Normalized market-bar file lacks at least two sessions for target '$TargetSymbol'."
  }

  $sessions = @($targetSessions)
  return [pscustomobject][ordered]@{
    path = $Path
    sha256 = $sha256
    row_count = $rowCount
    coverage_start = $coverageStart
    coverage_end = $coverageEnd
    target_symbol = $TargetSymbol
    target_latest = $targetLatest
    target_sessions = $sessions
    latest_target_session = $sessions[-1]
    previous_target_session = $sessions[-2]
  }
}

function Add-RefreshMetadata {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [psobject]$Summary,

    [Parameter(Mandatory = $true)]
    [string]$ArtifactKind
  )

  $artifact = ConvertFrom-JsonFile $Path
  Set-JsonProperty $artifact 'refresh_run_id' $runId
  Set-JsonProperty $artifact 'refresh_artifact_kind' $ArtifactKind
  Set-JsonProperty $artifact 'data_manifest_hash' $Summary.sha256
  Set-JsonProperty $artifact 'coverage_end' (ConvertTo-CanonicalUtc $Summary.coverage_end)
  Write-Utf8Json $artifact $Path
}

function Test-RefreshConsistency {
  param(
    [Parameter(Mandatory = $true)]
    [psobject]$Summary,

    [Parameter(Mandatory = $true)]
    [string]$MassiveManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$CapabilityPath,

    [Parameter(Mandatory = $true)]
    [string]$PredictorPath,

    [Parameter(Mandatory = $true)]
    [string]$ForecastPath,

    [string]$RegimePath,

    [switch]$RegimeSkipped
  )

  $normalizedSha = $Summary.sha256
  $coverageEnd = [DateTimeOffset]$Summary.coverage_end
  $latestSession = [string]$Summary.latest_target_session
  $previousSession = [string]$Summary.previous_target_session

  $massive = ConvertFrom-JsonFile $MassiveManifestPath
  Assert-RefreshInvariant `
    ([string]$massive.sha256 -eq $normalizedSha) `
    'Massive sync manifest SHA does not match normalized data.'
  Assert-RefreshInvariant `
    ([long]$massive.rows -eq [long]$Summary.row_count) `
    'Massive sync manifest row count does not match normalized data.'
  Assert-RefreshInvariant `
    ([DateTimeOffset]::Parse([string]$massive.coverage_end).ToUniversalTime() -eq
      $coverageEnd.ToUniversalTime()) `
    'Massive sync manifest coverage_end does not match normalized data.'

  $capability = ConvertFrom-JsonFile $CapabilityPath
  Assert-RefreshInvariant `
    ([string]$capability.data_manifest_hash -eq $normalizedSha) `
    'Capability top-level manifest hash does not match normalized data.'
  Assert-RefreshInvariant `
    ([DateTimeOffset]::Parse([string]$capability.coverage_end).ToUniversalTime() -eq
      $coverageEnd.ToUniversalTime()) `
    'Capability top-level coverage_end does not match normalized data.'
  Assert-RefreshInvariant `
    ([string]$capability.data.normalized_file_sha256 -eq $normalizedSha) `
    'Capability normalized_file_sha256 does not match normalized data.'
  Assert-RefreshInvariant `
    ([long]$capability.data.row_count -eq [long]$Summary.row_count) `
    'Capability row count does not match normalized data.'
  $capabilityCoverageEnd = [DateTimeOffset]::Parse([string]$capability.data.coverage_end)
  Assert-RefreshInvariant `
    ($capabilityCoverageEnd.ToUniversalTime() -eq $coverageEnd.ToUniversalTime()) `
    'Capability coverage_end does not match normalized data.'
  $capabilityHashes = @($capability.data.manifest_hashes | ForEach-Object {
      ([string]$_).ToLowerInvariant()
    })
  Assert-RefreshInvariant `
    ($capabilityHashes -contains $normalizedSha) `
    'Capability manifest_hashes does not contain the normalized SHA.'

  $predictor = ConvertFrom-JsonFile $PredictorPath
  Assert-RefreshInvariant `
    ([string]$predictor.data_manifest_hash -eq $normalizedSha) `
    'Predictor manifest hash does not match normalized data.'
  Assert-RefreshInvariant `
    ([DateTimeOffset]::Parse([string]$predictor.coverage_end).ToUniversalTime() -eq
      $coverageEnd.ToUniversalTime()) `
    'Predictor coverage_end does not match normalized data.'
  $predictorTrainedThrough = [DateTimeOffset]::Parse([string]$predictor.trained_through)
  Assert-RefreshInvariant `
    ($predictorTrainedThrough.ToString('yyyy-MM-dd') -eq $previousSession) `
    'Predictor trained_through is not the immediately prior target session.'
  Assert-RefreshInvariant `
    ($predictorTrainedThrough.ToUniversalTime() -le $Summary.target_latest.ToUniversalTime()) `
    'Predictor trained_through is later than the latest target observation.'

  $forecast = ConvertFrom-JsonFile $ForecastPath
  Assert-RefreshInvariant `
    ([string]$forecast.data_manifest_hash -eq $normalizedSha) `
    'Forecast top-level manifest hash does not match normalized data.'
  Assert-RefreshInvariant `
    ([DateTimeOffset]::Parse([string]$forecast.coverage_end).ToUniversalTime() -eq
      $coverageEnd.ToUniversalTime()) `
    'Forecast coverage_end does not match normalized data.'
  $predictionRows = @($forecast.prediction_layer)
  Assert-RefreshInvariant ($predictionRows.Count -gt 0) 'Forecast contains no prediction rows.'
  $forecastCutoffs = @($predictionRows | ForEach-Object {
      [DateTimeOffset]::Parse([string]$_.observation_cutoff).ToUniversalTime()
    } | Sort-Object -Unique)
  $latestAllowedCutoff = $Summary.target_latest.ToUniversalTime().AddMinutes(1)
  Assert-RefreshInvariant `
    ($forecastCutoffs.Count -gt 0) `
    'Forecast contains no reproducible observation cutoff.'
  $latestForecastCutoff = @($forecastCutoffs | Sort-Object -Descending)[0]
  Assert-RefreshInvariant `
    ($latestForecastCutoff.ToString('yyyy-MM-dd') -eq $latestSession) `
    'Latest legal horizon cutoff is not in the latest target session.'

  $predictorModelHashes = @($predictor.model_hashes | ForEach-Object { [string]$_ })
  $seenForecastHorizons = [System.Collections.Generic.HashSet[int]]::new()
  $forecastCutoffDetails = [System.Collections.Generic.List[object]]::new()
  foreach ($row in $predictionRows) {
    $horizonMinutes = [int]$row.horizon_minutes
    $rowCutoff = [DateTimeOffset]::Parse(
      [string]$row.observation_cutoff
    ).ToUniversalTime()
    $rowAsOf = [DateTimeOffset]::Parse([string]$row.as_of).ToUniversalTime()
    $rowLabelStart = [DateTimeOffset]::Parse(
      [string]$row.label_start
    ).ToUniversalTime()
    $rowLabelEnd = [DateTimeOffset]::Parse(
      [string]$row.label_end
    ).ToUniversalTime()
    Assert-RefreshInvariant `
      ($horizonMinutes -gt 0) `
      "Forecast row '$($row.prediction_id)' has a nonpositive horizon."
    Assert-RefreshInvariant `
      ($seenForecastHorizons.Add($horizonMinutes)) `
      "Forecast contains duplicate horizon '$horizonMinutes'."
    Assert-RefreshInvariant `
      ([string]$row.data_manifest_hash -eq $normalizedSha) `
      "Forecast row '$($row.prediction_id)' has a mismatched data manifest."
    Assert-RefreshInvariant `
      ($rowAsOf -eq $rowCutoff) `
      "Forecast row '$($row.prediction_id)' is not point-in-time aligned."
    Assert-RefreshInvariant `
      ($rowCutoff.ToString('yyyy-MM-dd') -eq $latestSession) `
      "Forecast row '$($row.prediction_id)' does not use the latest target session."
    Assert-RefreshInvariant `
      ($rowCutoff -le $latestAllowedCutoff) `
      "Forecast row '$($row.prediction_id)' cutoff is later than available target data."
    Assert-RefreshInvariant `
      ($rowLabelStart -eq $rowCutoff) `
      "Forecast row '$($row.prediction_id)' label_start differs from its causal cutoff."
    Assert-RefreshInvariant `
      ($rowLabelEnd -eq $rowCutoff.AddMinutes($horizonMinutes)) `
      "Forecast row '$($row.prediction_id)' label interval differs from its horizon."
    Assert-RefreshInvariant `
      ([string]$row.model_trained_through -eq $previousSession) `
      "Forecast row '$($row.prediction_id)' model_trained_through is not the prior session."
    Assert-RefreshInvariant `
      ($predictorModelHashes -contains [string]$row.model_hash) `
      "Forecast row '$($row.prediction_id)' model hash is absent from predictor artifact."
    $forecastCutoffDetails.Add([pscustomobject][ordered]@{
        horizon_minutes = $horizonMinutes
        observation_cutoff = ConvertTo-CanonicalUtc $rowCutoff
        label_end = ConvertTo-CanonicalUtc $rowLabelEnd
      })
  }

  $regimeValidation = [pscustomobject][ordered]@{
    skipped = [bool]$RegimeSkipped
    as_of = $null
    trained_through = $null
    current_session = $null
  }
  if (-not $RegimeSkipped) {
    $regime = ConvertFrom-JsonFile $RegimePath
    Assert-RefreshInvariant `
      ([string]$regime.data_manifest_hash -eq $normalizedSha) `
      'Regime manifest hash does not match normalized data.'
    Assert-RefreshInvariant `
      ([DateTimeOffset]::Parse([string]$regime.coverage_end).ToUniversalTime() -eq
        $coverageEnd.ToUniversalTime()) `
      'Regime coverage_end does not match normalized data.'
    Assert-RefreshInvariant `
      ([string]$regime.current_session -eq $latestSession) `
      'Regime current_session is not the latest target session.'
    Assert-RefreshInvariant `
      ([string]$regime.trained_through -eq $previousSession) `
      'Regime trained_through is not the immediately prior target session.'
    $regimeAsOf = [DateTimeOffset]::Parse([string]$regime.as_of).ToUniversalTime()
    Assert-RefreshInvariant `
      ($regimeAsOf.ToString('yyyy-MM-dd') -eq $latestSession) `
      'Regime as_of is not in the latest target session.'
    Assert-RefreshInvariant `
      ($regimeAsOf -le $Summary.target_latest.ToUniversalTime().AddMinutes(1)) `
      'Regime as_of is later than the latest target observation.'
    Assert-RefreshInvariant `
      ([string]$regime.source -eq $relativeNormalizedPath) `
      'Regime source does not point to the published normalized path.'
    $regimeValidation = [pscustomobject][ordered]@{
      skipped = $false
      as_of = ConvertTo-CanonicalUtc $regimeAsOf
      trained_through = [string]$regime.trained_through
      current_session = [string]$regime.current_session
    }
  }

  return [pscustomobject][ordered]@{
    status = 'PASSED'
    normalized_sha256 = $normalizedSha
    row_count = [long]$Summary.row_count
    coverage_start = ConvertTo-CanonicalUtc $Summary.coverage_start
    coverage_end = ConvertTo-CanonicalUtc $Summary.coverage_end
    target_symbol = $Summary.target_symbol
    target_latest_observation = ConvertTo-CanonicalUtc $Summary.target_latest
    latest_target_session = $latestSession
    previous_target_session = $previousSession
    predictor_trained_through = ConvertTo-CanonicalUtc $predictorTrainedThrough
    latest_forecast_observation_cutoff = ConvertTo-CanonicalUtc $latestForecastCutoff
    forecast_observation_cutoffs = @(
      $forecastCutoffDetails | Sort-Object horizon_minutes
    )
    forecast_rows = $predictionRows.Count
    regime = $regimeValidation
  }
}

function Publish-FileAtomically {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Source,

    [Parameter(Mandatory = $true)]
    [string]$Destination
  )

  if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
    throw "Cannot publish missing staged file: $Source"
  }

  $destinationParent = Split-Path -Parent $Destination
  if (-not (Test-Path -LiteralPath $destinationParent -PathType Container)) {
    New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
  }

  $incomingPath = "$Destination.refresh-$runId.tmp"
  $backupPath = Join-Path $stagingRoot ("rollback-" + [Guid]::NewGuid().ToString('N'))
  Copy-Item -LiteralPath $Source -Destination $incomingPath -Force
  $hadOriginal = Test-Path -LiteralPath $Destination -PathType Leaf
  if ($hadOriginal) {
    [IO.File]::Replace($incomingPath, $Destination, $backupPath, $true)
  } else {
    [IO.File]::Move($incomingPath, $Destination)
  }

  $record = [pscustomobject][ordered]@{
    destination = $Destination
    backup = if ($hadOriginal) { $backupPath } else { $null }
    had_original = $hadOriginal
  }
  $publishedFiles.Add($record)
}

function Undo-PublishedFiles {
  $rollbackErrors = [System.Collections.Generic.List[string]]::new()
  for ($index = $publishedFiles.Count - 1; $index -ge 0; $index--) {
    $record = $publishedFiles[$index]
    try {
      if ($record.had_original) {
        $rollbackIncoming = "$($record.destination).rollback-$runId.tmp"
        Copy-Item -LiteralPath $record.backup -Destination $rollbackIncoming -Force
        [IO.File]::Replace($rollbackIncoming, $record.destination, $null, $true)
      } elseif (Test-Path -LiteralPath $record.destination -PathType Leaf) {
        Remove-Item -LiteralPath $record.destination -Force
      }
    } catch {
      $rollbackErrors.Add("$($record.destination): $($_.Exception.Message)")
    }
  }
  return @($rollbackErrors)
}

function Remove-RefreshStaging {
  if (-not (Test-Path -LiteralPath $stagingRoot -PathType Container)) {
    return
  }

  $resolvedStaging = [IO.Path]::GetFullPath($stagingRoot)
  $allowedPrefix = [IO.Path]::GetFullPath((Join-Path $qualityRoot '.refresh-staging-'))
  if (-not $resolvedStaging.StartsWith(
      $allowedPrefix,
      [StringComparison]::OrdinalIgnoreCase
    )) {
    throw "Refusing to remove staging path outside the refresh namespace: $resolvedStaging"
  }
  Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
}

if ($DryRun) {
  $dryRunPlan = [pscustomobject][ordered]@{
    status = 'DRY_RUN'
    run_id = $runId
    lookback_days = $LookbackDays
    skip_slow_regime = [bool]$SkipSlowRegime
    mutates_files = $false
    execution_guard = 'DATA_AND_RESEARCH_ONLY_NO_BROKER_NO_ORDER_NO_EXECUTION'
    stages = @(
      'Seed an isolated normalized snapshot and isolated manifest directory.',
      "quantctl data massive-poll --lookback-days $LookbackDays",
      'quantctl data capability',
      'quantctl predictor train',
      'quantctl predictor forecast --record-shadow false',
      $(if ($SkipSlowRegime) {
          'regime-fit explicitly skipped; existing published regime is untouched'
        } else {
          'quantctl research regime-fit'
        }),
      'Validate SHA, coverage, trained-through, as-of and causal session invariants.',
      'Per-file atomic replacement with rollback; publish the commit receipt last.'
    )
  }
  $dryRunPlan | ConvertTo-Json -Depth 10
  exit 0
}

try {
  foreach ($requiredPath in @($quantCtlPath, $productionConfigPath, $normalizedPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
      throw "Refresh prerequisite is missing: $requiredPath"
    }
  }

  New-Item -ItemType Directory -Path $qualityRoot -Force | Out-Null
  try {
    $lockStream = [IO.File]::Open(
      $lockPath,
      [IO.FileMode]::OpenOrCreate,
      [IO.FileAccess]::ReadWrite,
      [IO.FileShare]::None
    )
  } catch {
    throw "Another quant refresh appears to be running; lock unavailable at '$lockPath'."
  }
  $lockStream.SetLength(0)
  $lockText = [Text.Encoding]::UTF8.GetBytes(
    "run_id=$runId pid=$PID started_at=$(ConvertTo-CanonicalUtc $startedAt)"
  )
  $lockStream.Write($lockText, 0, $lockText.Length)
  $lockStream.Flush($true)

  New-Item -ItemType Directory -Path $stagingNormalizedRoot -Force | Out-Null
  New-Item -ItemType Directory -Path $stagingManifestRoot -Force | Out-Null
  New-Item -ItemType Directory -Path $stagingOutputRoot -Force | Out-Null
  New-HardLinkOrCopy $normalizedPath $stagingNormalizedPath

  if (Test-Path -LiteralPath $manifestRoot -PathType Container) {
    foreach ($entry in Get-ChildItem -LiteralPath $manifestRoot -Force) {
      Copy-Item -LiteralPath $entry.FullName -Destination $stagingManifestRoot -Recurse -Force
    }
  }

  $configContent = Get-Content -LiteralPath $productionConfigPath -Raw
  $configContent = Set-YamlPath $configContent 'normalized_root' $stagingNormalizedRoot
  $configContent = Set-YamlPath $configContent 'manifest_root' $stagingManifestRoot
  [IO.File]::WriteAllText(
    $stagingConfigPath,
    $configContent,
    [Text.UTF8Encoding]::new($false)
  )

  $globalArguments = @('--config', $stagingConfigPath)
  Invoke-QuantStep 'massive_poll' ($globalArguments + @(
      'data',
      'massive-poll',
      '--lookback-days',
      [string]$LookbackDays,
      '--output',
      $stagingNormalizedPath
    ))

  $utcToday = [DateTime]::UtcNow.Date
  $manifestStart = $utcToday.AddDays(-1 * $LookbackDays).ToString('yyyy-MM-dd')
  $manifestEnd = $utcToday.ToString('yyyy-MM-dd')
  $stagedMassiveManifestPath = Join-Path $stagingManifestRoot (
    "massive_sync_${manifestStart}_${manifestEnd}.json"
  )
  $massiveManifest = ConvertFrom-JsonFile $stagedMassiveManifestPath
  $targetSymbol = 'SPY'
  $summary = Get-NormalizedSummary $stagingNormalizedPath $targetSymbol
  Assert-RefreshInvariant `
    ([string]$massiveManifest.sha256 -eq $summary.sha256) `
    'Massive poll receipt hash does not match its staged normalized output.'
  Set-JsonProperty $massiveManifest 'output' $relativeNormalizedPath
  Set-JsonProperty $massiveManifest 'refresh_run_id' $runId
  Set-JsonProperty $massiveManifest 'coverage_end' (ConvertTo-CanonicalUtc $summary.coverage_end)
  Write-Utf8Json $massiveManifest $stagedMassiveManifestPath

  Invoke-QuantStep 'capability' ($globalArguments + @(
      'data',
      'capability',
      '--output',
      $stagedCapabilityPath
    ))
  Invoke-QuantStep 'predictor_train' ($globalArguments + @(
      'predictor',
      'train',
      '--bars',
      $stagingNormalizedPath,
      '--output',
      $stagedPredictorPath
    ))
  Invoke-QuantStep 'predictor_forecast' ($globalArguments + @(
      'predictor',
      'forecast',
      '--bars',
      $stagingNormalizedPath,
      '--output',
      $stagedForecastPath,
      '--record-shadow',
      'false'
    ))

  if (-not $SkipSlowRegime) {
    Invoke-QuantStep 'regime_fit' ($globalArguments + @(
        'research',
        'regime-fit',
        '--bars',
        $stagingNormalizedPath,
        '--output',
        $stagedRegimePath
      ))
    $regime = ConvertFrom-JsonFile $stagedRegimePath
    Set-JsonProperty $regime 'source' $relativeNormalizedPath
    Write-Utf8Json $regime $stagedRegimePath
  }

  Add-RefreshMetadata $stagedCapabilityPath $summary 'data_capability'
  Add-RefreshMetadata $stagedPredictorPath $summary 'candidate_predictor'
  Add-RefreshMetadata $stagedForecastPath $summary 'forecast_contract'
  if (-not $SkipSlowRegime) {
    Add-RefreshMetadata $stagedRegimePath $summary 'regime_diagnostic'
  }

  $validation = Test-RefreshConsistency `
    -Summary $summary `
    -MassiveManifestPath $stagedMassiveManifestPath `
    -CapabilityPath $stagedCapabilityPath `
    -PredictorPath $stagedPredictorPath `
    -ForecastPath $stagedForecastPath `
    -RegimePath $stagedRegimePath `
    -RegimeSkipped:$SkipSlowRegime

  $finalMassiveManifestPath = Join-Path $manifestRoot (
    "massive_sync_${manifestStart}_${manifestEnd}.json"
  )
  $publicationPlan = [System.Collections.Generic.List[object]]::new()
  $publicationPlan.Add([pscustomobject]@{
      source = $stagingNormalizedPath
      destination = $normalizedPath
      name = 'normalized_market_bars'
    })
  $publicationPlan.Add([pscustomobject]@{
      source = $stagedMassiveManifestPath
      destination = $finalMassiveManifestPath
      name = 'massive_sync_manifest'
    })
  $publicationPlan.Add([pscustomobject]@{
      source = $stagedCapabilityPath
      destination = $finalCapabilityPath
      name = 'data_capability'
    })
  $publicationPlan.Add([pscustomobject]@{
      source = $stagedPredictorPath
      destination = $finalPredictorPath
      name = 'predictor_candidate'
    })
  $publicationPlan.Add([pscustomobject]@{
      source = $stagedForecastPath
      destination = $finalForecastPath
      name = 'forecast_contract'
    })
  if (-not $SkipSlowRegime) {
    $publicationPlan.Add([pscustomobject]@{
        source = $stagedRegimePath
        destination = $finalRegimePath
        name = 'regime'
      })
  }

  $expectedHashes = [ordered]@{}
  foreach ($item in $publicationPlan) {
    $expectedHashes[$item.name] = (
      Get-FileHash -LiteralPath $item.source -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    Publish-FileAtomically $item.source $item.destination
  }

  foreach ($item in $publicationPlan) {
    $publishedHash = (
      Get-FileHash -LiteralPath $item.destination -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    Assert-RefreshInvariant `
      ($publishedHash -eq $expectedHashes[$item.name]) `
      "Published artifact '$($item.name)' differs from its validated staging file."
  }

  $completedAt = [DateTimeOffset]::UtcNow
  $receipt = [pscustomobject][ordered]@{
    schema_version = 'axio7.quant.refresh-receipt.v1'
    status = if ($SkipSlowRegime) {
      'SUCCEEDED_REGIME_EXPLICITLY_SKIPPED'
    } else {
      'SUCCEEDED'
    }
    run_id = $runId
    started_at = ConvertTo-CanonicalUtc $startedAt
    completed_at = ConvertTo-CanonicalUtc $completedAt
    duration_seconds = [Math]::Round(($completedAt - $startedAt).TotalSeconds, 3)
    lookback_days = $LookbackDays
    full_refresh = -not [bool]$SkipSlowRegime
    skip_slow_regime = [bool]$SkipSlowRegime
    execution_guard = 'DATA_AND_RESEARCH_ONLY_NO_BROKER_NO_ORDER_NO_EXECUTION'
    api_keys_in_receipt = $false
    validation = $validation
    steps = @($stepReceipts)
    published = @($publicationPlan | ForEach-Object {
        [pscustomobject][ordered]@{
          name = $_.name
          path = Get-WorkspaceRelativePath $_.destination
          sha256 = $expectedHashes[$_.name]
        }
      })
  }
  $stagedReceiptPath = Join-Path $stagingOutputRoot 'refresh_receipt_latest.json'
  Write-Utf8Json $receipt $stagedReceiptPath
  $expectedReceiptHash = (
    Get-FileHash -LiteralPath $stagedReceiptPath -Algorithm SHA256
  ).Hash.ToLowerInvariant()
  Publish-FileAtomically $stagedReceiptPath $receiptPath
  $publishedReceiptHash = (
    Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256
  ).Hash.ToLowerInvariant()
  Assert-RefreshInvariant `
    ($publishedReceiptHash -eq $expectedReceiptHash) `
    'Published refresh receipt differs from its staged content.'
  $refreshSucceeded = $true
  Write-Host "Quant refresh succeeded. Receipt: $receiptPath"
} catch {
  $failureMessage = $_.Exception.Message
  $rollbackErrors = @()
  if ($publishedFiles.Count -gt 0) {
    $rollbackErrors = @(Undo-PublishedFiles)
  }
  Write-Error (
    "Quant refresh failed and published files were rolled back. " +
    "reason='$failureMessage' rollback_errors='$($rollbackErrors -join '; ')'"
  )
  exit 1
} finally {
  if ($null -ne $lockStream) {
    $lockStream.Dispose()
  }
  try {
    Remove-RefreshStaging
  } catch {
    if ($refreshSucceeded) {
      Write-Warning "Refresh succeeded, but staging cleanup failed: $($_.Exception.Message)"
    }
  }
}
