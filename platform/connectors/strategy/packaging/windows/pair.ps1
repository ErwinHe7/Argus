[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ApiBase,
    [string]$Name = $env:COMPUTERNAME,
    [string]$StateDir,
    [ValidateSet('FUTUSECURITIES','FUTUINC','FUTUSG','FUTUAU','FUTUCA','FUTUMY','FUTUJP')][string]$SecurityFirm = 'FUTUINC'
)
$ErrorActionPreference = 'Stop'
$application = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$arguments = @()
if ($StateDir) { $arguments += @('--state-dir', [IO.Path]::GetFullPath($StateDir)) }
$arguments += @('pair', '--api-base', $ApiBase, '--name', $Name, '--engine', (Join-Path $application 'bin\strategy-lab.exe'), '--adapter', (Join-Path $application 'adapter\leo-paper-sdk\leo-paper-sdk.exe'), '--adapter-argument=--security-firm', "--adapter-argument=$SecurityFirm")
$secret = Read-Host 'Paste the one-use device pairing token (hidden)' -AsSecureString
$pointer = [IntPtr]::Zero
try {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    # The token goes only to stdin. It is never a command argument or saved to disk.
    $plain | & (Join-Path $application 'bin\leo-strategy-connector.exe') @arguments
    if ($LASTEXITCODE -ne 0) { throw 'Pairing failed. Inspect the control service and OS credential store; revoke any device created by a failed pairing before trying a new token.' }
} finally {
    $plain = $null
    if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
    $secret.Dispose()
}
