param(
    [string]$BaseUrl = 'http://127.0.0.1:8101'
)

$ErrorActionPreference = 'Stop'

$Token = $env:AXIO7_SMOKE_RESEARCH_TOKEN
if ([string]::IsNullOrWhiteSpace($Token) -or $Token.Length -lt 32) {
    throw 'AXIO7_SMOKE_RESEARCH_TOKEN must contain at least 32 characters.'
}

$Headers = @{
    Accept = 'application/json'
    'X-Research-Token' = $Token
}
$Receipt = Invoke-RestMethod `
    -Method Get `
    -Uri "$($BaseUrl.TrimEnd('/'))/api/v1/research/universe" `
    -Headers $Headers `
    -TimeoutSec 30

if ($Receipt.production_inference_owner -ne 'quant_engine_rs') {
    throw 'The production inference owner is not quant_engine_rs.'
}
if ($Receipt.execution -ne 'DISABLED') {
    throw 'Automatic execution must remain disabled.'
}
$Runtime = $Receipt.model_runtime
if ($Runtime.schema_version -ne 'axio.model-runtime-receipt.v1') {
    throw 'The model runtime receipt schema is missing or incompatible.'
}
if ($Runtime.status -ne 'LOADED') {
    $SymbolStates = ($Runtime.symbols | ForEach-Object {
        "$($_.model_symbol):$($_.status):$($_.reason_code)"
    }) -join ','
    throw (
        'Model runtime status is {0}, expected LOADED; loaded={1}/{2}; failed={3}; symbols={4}' -f
        $Runtime.status,
        $Runtime.loaded_artifact_count,
        $Runtime.requested_artifact_count,
        $Runtime.failed_artifact_count,
        $SymbolStates
    )
}
if (
    $Runtime.requested_artifact_count -lt 1 -or
    $Runtime.loaded_artifact_count -ne $Runtime.requested_artifact_count -or
    $Runtime.failed_artifact_count -ne 0
) {
    throw 'The exact frozen-model universe did not load completely.'
}
if (
    $Runtime.quality_and_promotion_checked_separately -ne $true -or
    $Runtime.automatic_execution_enabled -ne $false
) {
    throw 'The model runtime boundary receipt is invalid.'
}

Write-Output (
    'PASS model_runtime={0} loaded={1}/{2} execution={3}' -f
    $Runtime.status,
    $Runtime.loaded_artifact_count,
    $Runtime.requested_artifact_count,
    $Receipt.execution
)
