[CmdletBinding()]
param([string]$InstallDir, [string]$PartsDirectory, [switch]$VerifyOnly)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName System.IO.Compression.FileSystem
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'native-package.json') -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1 -or $manifest.channel -ne 'unsigned-development' -or $manifest.platform -ne 'windows-x64' -or $manifest.paperOnly -ne $true) { throw 'Unexpected development package manifest.' }
if ($manifest.sha256 -notmatch '^[a-f0-9]{64}$' -or $manifest.bytes -lt 1 -or $manifest.bytes -gt 250MB -or $manifest.parts.Count -lt 1 -or $manifest.parts.Count -gt 20) { throw 'Invalid package dimensions or checksum.' }
if ($manifest.bundle -notmatch '^leo-strategy-connector-[a-zA-Z0-9.-]+-windows-x64$') { throw 'Invalid bundle identity.' }
if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne [Runtime.InteropServices.Architecture]::X64 -or -not [Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([Runtime.InteropServices.OSPlatform]::Windows)) { throw 'This development package requires native Windows x64.' }
$work = Join-Path ([IO.Path]::GetTempPath()) ('leo-broker-download-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
Write-Host 'Installing unsigned development tools. Real-money execution is disabled. This does not connect an account or start trading.'
Write-Host "Download evidence is retained at $work"
$handler = [Net.Http.HttpClientHandler]::new()
$handler.AllowAutoRedirect = $false
$client = [Net.Http.HttpClient]::new($handler)
$client.Timeout = [TimeSpan]::FromMinutes(5)
try {
    $archive = Join-Path $work 'connector.zip'
    $joined = [IO.File]::Open($archive, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    try {
        $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        [long]$total = 0
        foreach ($part in $manifest.parts) {
            if ($part.name -notmatch '^leo-native-[a-f0-9]{16}\.part[0-9]{3}\.bin$' -or -not $names.Add($part.name) -or $part.sha256 -notmatch '^[a-f0-9]{64}$' -or $part.bytes -lt 1 -or $part.bytes -gt 20MB) { throw 'Invalid package part.' }
            $target = Join-Path $work $part.name
            if ($PartsDirectory) {
                Copy-Item -LiteralPath (Join-Path $PartsDirectory $part.name) -Destination $target
            } else {
                $url = 'https://leo.axio7.workers.dev/app/research-desk/downloads/' + $part.name
                $response = $client.GetAsync($url, [Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
                try {
                    if ([int]$response.StatusCode -ne 200) { throw "Download failed: HTTP $([int]$response.StatusCode). Redirects are not accepted." }
                    if ($null -ne $response.Content.Headers.ContentLength -and $response.Content.Headers.ContentLength -ne $part.bytes) { throw 'Download length does not match release.' }
                    $downloadStream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                    $output = [IO.File]::Open($target, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
                    $deadline = [Threading.CancellationTokenSource]::new([TimeSpan]::FromMinutes(5))
                    try {
                        $buffer = New-Object byte[] 65536
                        [long]$count = 0
                        while (($read = $downloadStream.ReadAsync($buffer, 0, $buffer.Length, $deadline.Token).GetAwaiter().GetResult()) -gt 0) {
                            $count += $read
                            if ($count -gt $part.bytes) { throw 'Download exceeds release length.' }
                            $output.Write($buffer, 0, $read)
                        }
                    } finally { $deadline.Dispose(); $output.Dispose(); $downloadStream.Dispose() }
                } finally { $response.Dispose() }
            }
            if ((Get-Item -LiteralPath $target).Length -ne $part.bytes -or (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $part.sha256) { throw 'Package part checksum mismatch.' }
            $partStream = [IO.File]::OpenRead($target)
            try { $partStream.CopyTo($joined) } finally { $partStream.Dispose() }
            $total += $part.bytes
        }
        if ($total -ne $manifest.bytes) { throw 'Package parts have the wrong total length.' }
    } finally { $joined.Dispose() }
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.sha256) { throw 'Complete archive checksum mismatch.' }
    $expanded = Join-Path $work 'expanded'
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        [long]$size = 0
        if ($zip.Entries.Count -gt 10000) { throw 'Archive has too many entries.' }
        foreach ($entry in $zip.Entries) {
            $relative = $entry.FullName.Replace('\', '/')
            if (-not $relative.StartsWith($manifest.bundle + '/', [StringComparison]::Ordinal) -or $relative.Contains(':') -or $relative.Contains('//') -or $relative -match '(^|/)\.\.?(/|$)' -or -not $paths.Add($relative)) { throw 'Unsafe or duplicate archive path.' }
            if (@($relative.Split('/') | Where-Object { $_ -match '[. ]$' -or $_ -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)' }).Count -gt 0) { throw 'Unsafe Windows archive name.' }
            $kind = ($entry.ExternalAttributes -shr 16) -band 0xF000
            if ($kind -eq 0xA000 -or ($entry.ExternalAttributes -band 0x400)) { throw 'Archive links are not supported.' }
            $size += $entry.Length
            if ($size -gt 1GB) { throw 'Expanded archive exceeds expected size.' }
            $resolved = [IO.Path]::GetFullPath((Join-Path $expanded $relative))
            if (-not $resolved.StartsWith($expanded + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Archive path escapes extraction directory.' }
        }
    } finally { $zip.Dispose() }
    [IO.Compression.ZipFile]::ExtractToDirectory($archive, $expanded)
    $bundle = Join-Path $expanded $manifest.bundle
    if ($VerifyOnly) {
        Write-Host "Checksums and archive structure verified. No installer executed. Bundle: $bundle"
    } else {
        if (-not $InstallDir) { $InstallDir = Join-Path $env:LOCALAPPDATA ('Programs\LeoBrokerConnectorDev-' + $manifest.sha256.Substring(0, 12)) }
        & (Join-Path $bundle 'scripts\install.ps1') -InstallDir $InstallDir
        Write-Host "Next: & '$InstallDir\scripts\pair.ps1'"
        Write-Host "After pairing and authorizing a paper mandate: & '$InstallDir\scripts\start.ps1'"
        Write-Host 'Keep the connector and broker gateway running while they manage paper exposure.'
    }
} finally { $client.Dispose(); $handler.Dispose() }
