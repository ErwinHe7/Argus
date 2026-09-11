# Shared argument construction only; this file never starts a connector or reads credentials.
function Get-LeoBrokerProfile {
    [CmdletBinding()]
    param(
        [ValidateSet('moomoo','ibkr-gateway')][string]$Broker = 'moomoo',
        [string]$StateDir,
        [ValidateSet('FUTUSECURITIES','FUTUINC','FUTUSG','FUTUAU','FUTUCA','FUTUMY','FUTUJP')][string]$SecurityFirm = 'FUTUINC',
        [string]$Account,
        [string]$GatewayCaFile,
        [string]$GatewayCertificateSha256,
        [string]$HistoryDirectory,
        [switch]$EnableIbkrPaper
    )
    if (-not $StateDir) {
        $StateDir = Join-Path $env:LOCALAPPDATA $(if ($Broker -eq 'ibkr-gateway') { 'Leo\StrategyConnector-IBKR' } else { 'Leo\StrategyConnector' })
    }
    if (-not [IO.Path]::IsPathFullyQualified($StateDir) -or $StateDir -notmatch '^[A-Za-z]:[\\/]') { throw 'StateDir must be an absolute local drive path.' }
    $resolvedState = [IO.Path]::GetFullPath($StateDir)
    $adapter = @('--broker', $Broker)
    if ($Broker -eq 'moomoo') {
        if ($Account -or $GatewayCaFile -or $GatewayCertificateSha256 -or $HistoryDirectory -or $EnableIbkrPaper) { throw 'IBKR options cannot be used for a moomoo profile.' }
        $adapter += @('--security-firm', $SecurityFirm)
    } else {
        if (-not $EnableIbkrPaper) { throw 'IBKR paper execution is experimental. Explicit -EnableIbkrPaper is required; this is not public broker approval.' }
        if ($Account -cnotmatch '^IBKR:DU[1-9][0-9]{0,18}$') { throw 'Specify the exact IBKR:DU paper account. The adapter verifies its session before every operation.' }
        if ([bool]$GatewayCaFile -eq [bool]$GatewayCertificateSha256) { throw 'Specify exactly one GatewayCaFile or GatewayCertificateSha256.' }
        $adapter += @('--enable-paper-execution', '--account', $Account, '--journal', (Join-Path $resolvedState 'gateway-orders.sqlite3'))
        if ($GatewayCaFile) {
            $certificate = Get-Item -LiteralPath $GatewayCaFile -ErrorAction Stop
            if ($certificate.PSIsContainer) { throw 'GatewayCaFile must be a certificate file.' }
            $adapter += @('--ca-file', $certificate.FullName)
        } else {
            if ($GatewayCertificateSha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'Certificate pin must be 64 hexadecimal characters.' }
            $adapter += @('--certificate-sha256', $GatewayCertificateSha256.ToLowerInvariant())
        }
        if ($HistoryDirectory) {
            $history = Get-Item -LiteralPath $HistoryDirectory -ErrorAction Stop
            if (-not $history.PSIsContainer) { throw 'HistoryDirectory must be a directory.' }
            $adapter += @('--history-directory', $history.FullName)
        }
    }
    [pscustomobject]@{ StateDir = $resolvedState; AdapterArguments = $adapter }
}
