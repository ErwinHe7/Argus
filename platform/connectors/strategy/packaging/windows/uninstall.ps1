[CmdletBinding()]
param([string]$InstallDir = (Join-Path $PSScriptRoot '..'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$destination = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\', '/')
if (-not [IO.Path]::IsPathRooted($InstallDir) -or $destination.Length -le [IO.Path]::GetPathRoot($destination).Length) { throw 'An absolute application directory is required.' }
$receiptFile = Join-Path $destination 'installation-receipt.json'
if (-not (Test-Path -LiteralPath $receiptFile)) { throw 'ZIP installation receipt missing. For an MSI installation use Windows Installed apps.' }
$receipt = Get-Content -LiteralPath $receiptFile -Raw | ConvertFrom-Json
if ($receipt.product -ne 'leo-strategy-connector' -or $receipt.origin -ne 'zip' -or $receipt.installDirectory -ne $destination) { throw 'Installation identity does not match the resolved target.' }
$state = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Leo\StrategyConnector'))
if ($state.StartsWith($destination + '\', [StringComparison]::OrdinalIgnoreCase) -or $destination.StartsWith($state, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing to remove a state directory or its parent.' }
$ancestor = [IO.DirectoryInfo]::new($destination)
while ($null -ne $ancestor) {
    if ($ancestor.Exists -and ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Reparse points are not permitted.' }
    $ancestor = $ancestor.Parent
}
if (Get-ChildItem -LiteralPath $destination -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw 'Reparse points inside the installation are not permitted.' }
if (Get-ChildItem -LiteralPath $destination -Recurse -File -Force | Where-Object { $_.Name -like 'journal.sqlite3*' -or $_.Name -like 'research-upload.sqlite3*' }) { throw 'Local journals were placed inside the application directory. Preserve them outside the installation before uninstalling.' }
foreach ($process in Get-CimInstance Win32_Process -Filter "Name='leo-strategy-connector.exe' OR Name='leo-paper-sdk.exe'") {
    if ($process.ExecutablePath -and $process.ExecutablePath.StartsWith($destination + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Connector or SDK is running. Pause entries, review exposure, and stop it before uninstalling.' }
}
# The receipt and resolved path above bind deletion to this exact application tree.
Remove-Item -LiteralPath $destination -Recurse -Force
Write-Host 'Application files removed. Local journals, configuration, and OS credentials are preserved. Revoke the device separately in Strategy Lab when appropriate.'
