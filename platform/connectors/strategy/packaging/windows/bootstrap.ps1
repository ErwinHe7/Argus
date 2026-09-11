[CmdletBinding()]
param([switch]$InstallVisualCpp)
$ErrorActionPreference = 'Stop'
if (-not [Environment]::Is64BitOperatingSystem) { throw 'Windows x64 is required.' }
if ($InstallVisualCpp) {
    $bootstrapDir = Join-Path ([IO.Path]::GetTempPath()) ('leo-vc-bootstrap-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $bootstrapDir | Out-Null
    $installer = Join-Path $bootstrapDir 'vc_redist.x64.exe'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://aka.ms/vc14/vc_redist.x64.exe' -OutFile $installer
    $signature = Get-AuthenticodeSignature -LiteralPath $installer
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation(?:,|$)') { throw 'Microsoft runtime signature validation failed.' }
    $process = Start-Process -FilePath $installer -ArgumentList @('/install', '/passive', '/norestart') -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -notin @(0, 1638, 3010)) { throw "Visual C++ installation failed: $($process.ExitCode)" }
    Write-Host "Visual C++ installer exit code: $($process.ExitCode). Installer retained at $installer."
}
& (Join-Path $PSScriptRoot 'diagnose.ps1')
Write-Host 'Python and SDK dependencies are included in this native bundle. Install and authenticate vendor OpenD separately from https://www.moomoo.com/download/OpenAPI, using loopback 127.0.0.1:11111. Broker passwords remain in OpenD.'
