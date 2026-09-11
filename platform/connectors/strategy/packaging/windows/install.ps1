[CmdletBinding()]
param([string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\LeoStrategyConnectorDev'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$source = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$destination = [IO.Path]::GetFullPath($InstallDir)
if (-not [IO.Path]::IsPathRooted($InstallDir) -or $destination -eq [IO.Path]::GetPathRoot($destination)) { throw 'InstallDir must be an absolute application directory.' }
if (Test-Path -LiteralPath $destination) { throw 'Destination exists. Preserve the old installation and choose an empty application directory.' }
$parent = [IO.DirectoryInfo]::new([IO.Path]::GetDirectoryName($destination))
while ($null -ne $parent) {
    if ($parent.Exists -and ($parent.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Reparse points are not allowed in the installation path.' }
    $parent = $parent.Parent
}
$manifest = Get-Content -LiteralPath (Join-Path $source 'package-manifest.json') -Raw | ConvertFrom-Json
if ($manifest.product -ne 'leo-strategy-connector' -or $manifest.platform -ne 'windows-x64') { throw 'Unexpected package identity or platform.' }
if (Get-ChildItem -LiteralPath $source -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw 'Package reparse points are not permitted.' }
$expectedFiles = @('SHA256SUMS')
foreach ($line in Get-Content -LiteralPath (Join-Path $source 'SHA256SUMS')) {
    if ($line -notmatch '^([a-f0-9]{64})  (.+)$') { throw 'Invalid checksum manifest.' }
    $expected, $relative = $Matches[1], $Matches[2]
    $file = [IO.Path]::GetFullPath((Join-Path $source $relative))
    if (-not $file.StartsWith($source + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Checksum path escapes the package.' }
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) { throw "Checksum mismatch: $relative" }
    $expectedFiles += $relative.Replace('/', '\')
}
$actualFiles = @(Get-ChildItem -LiteralPath $source -Recurse -File -Force | ForEach-Object { $_.FullName.Substring($source.Length + 1) })
if (Compare-Object -ReferenceObject $expectedFiles -DifferenceObject $actualFiles) { throw 'Package contains missing or unlisted files.' }
New-Item -ItemType Directory -Path $destination | Out-Null
Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $destination -Recurse
@{ product = 'leo-strategy-connector'; origin = 'zip'; installDirectory = $destination; installedAt = [DateTime]::UtcNow.ToString('o'); statePreservedOnUninstall = $true } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destination 'installation-receipt.json') -Encoding UTF8
& (Join-Path $destination 'scripts\diagnose.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Installed files remain for diagnosis; offline checks failed.' }
Write-Host "Installed unsigned development package at $destination. Pairing and startup are separate actions."
