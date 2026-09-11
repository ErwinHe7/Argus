[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Bundle,
    [Parameter(Mandatory = $true)][string]$Output,
    [string]$Msi
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$bundleRoot = [IO.Path]::GetFullPath($Bundle)
$outputRoot = [IO.Path]::GetFullPath($Output)
if (-not [IO.Path]::IsPathRooted($Output) -or (Test-Path -LiteralPath $outputRoot)) { throw 'Use a new absolute verification output directory.' }
New-Item -ItemType Directory -Path $outputRoot | Out-Null
$receipt = [ordered]@{
    schemaVersion = 1
    startedAt = [DateTime]::UtcNow.ToString('o')
    host = (Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture)
    bundle = $bundleRoot
    status = 'running'
    checks = @()
    installedBinaryHashes = @()
    notRun = @('broker/OpenD connection', 'credential store integration', 'pairing', 'order lifecycle', 'dependency installer', 'macOS', 'Ubuntu')
}
function Record-Check([string]$Name, [string]$Detail) {
    $receipt.checks += @{ name = $Name; status = 'passed'; detail = $Detail }
    Write-Host "PASS: $Name"
}
function Assert-Installed-Binaries([string]$Installation, [string]$Kind) {
    foreach ($relative in @('bin/leo-strategy-connector.exe', 'bin/strategy-lab.exe', 'adapter/leo-paper-sdk/leo-paper-sdk.exe')) {
        $expected = (Get-FileHash -LiteralPath (Join-Path $bundleRoot $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
        $actual = (Get-FileHash -LiteralPath (Join-Path $Installation $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($expected -ne $actual) { throw "Installed $Kind binary differs from the package: $relative" }
        $receipt.installedBinaryHashes += @{ installation = $Kind; path = $relative; expected = $expected; actual = $actual }
    }
    Record-Check "$Kind exact installed binary hashes" 'Runner, separate engine and frozen SDK executable match the source package byte for byte.'
}
$zipInstall = Join-Path $outputRoot 'zip-install'
$msiInstall = Join-Path $outputRoot 'msi-install'
$stateDir = Join-Path $outputRoot 'preserved-local-state'
New-Item -ItemType Directory -Path $stateDir | Out-Null
$sentinel = Join-Path $stateDir 'journal-preservation-sentinel.txt'
'Isolated verification state; no credentials or brokerage data.' | Set-Content -LiteralPath $sentinel -Encoding UTF8
$stateHash = (Get-FileHash -LiteralPath $sentinel).Hash
try {
    $parserErrors = @()
    foreach ($script in Get-ChildItem -LiteralPath (Join-Path $bundleRoot 'scripts') -Filter '*.ps1') {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$errors) | Out-Null
        $parserErrors += $errors
    }
    if ($parserErrors.Count) { throw 'Package PowerShell script parsing failed.' }
    Record-Check 'PowerShell script parsing' 'All packaged scripts parsed by the native PowerShell parser.'
    & (Join-Path $bundleRoot 'scripts/install.ps1') -InstallDir $zipInstall *>&1 | Tee-Object -FilePath (Join-Path $outputRoot 'zip-install.log')
    Record-Check 'ZIP install and full checksum verification' $zipInstall
    Assert-Installed-Binaries $zipInstall 'ZIP'
    & (Join-Path $zipInstall 'scripts/diagnose.ps1') -StateDir $stateDir *>&1 | Tee-Object -FilePath (Join-Path $outputRoot 'zip-diagnose.log')
    Record-Check 'Installed doctor and bundled SDK self-check' 'Native executables run from the isolated application directory; no broker request.'
    $refused = $false
    try { & (Join-Path $bundleRoot 'scripts/install.ps1') -InstallDir $zipInstall } catch { $refused = $true }
    if (-not $refused) { throw 'Existing directory was not refused.' }
    Record-Check 'Existing destination refusal' 'Installer did not replace the existing application directory.'
    $refused = $false
    try { & (Join-Path $bundleRoot 'scripts/install.ps1') -InstallDir 'relative-path' } catch { $refused = $true }
    if (-not $refused) { throw 'Relative destination was not refused.' }
    Record-Check 'Relative path refusal' 'Installer requires an absolute application path.'
    $tampered = Join-Path $outputRoot 'tampered-package'
    New-Item -ItemType Directory -Path (Join-Path $tampered 'scripts') | Out-Null
    Copy-Item -LiteralPath (Join-Path $bundleRoot 'scripts/install.ps1') -Destination (Join-Path $tampered 'scripts/install.ps1')
    Copy-Item -LiteralPath (Join-Path $bundleRoot 'package-manifest.json') -Destination $tampered
    ('0' * 64 + '  package-manifest.json') | Set-Content -LiteralPath (Join-Path $tampered 'SHA256SUMS') -Encoding ASCII
    $refused = $false
    try { & (Join-Path $tampered 'scripts/install.ps1') -InstallDir (Join-Path $outputRoot 'must-not-install') } catch { $refused = $_.Exception.Message -like 'Checksum mismatch:*' }
    if (-not $refused -or (Test-Path -LiteralPath (Join-Path $outputRoot 'must-not-install'))) { throw 'Tampered package was not rejected before installation.' }
    Record-Check 'Tampered checksum refusal' 'Checksum mismatch blocks copying and executable startup.'
    $customState = Join-Path $zipInstall 'custom-state'
    New-Item -ItemType Directory -Path $customState | Out-Null
    $customJournal = Join-Path $customState 'journal.sqlite3'
    'Isolated non-database journal-preservation fixture.' | Set-Content -LiteralPath $customJournal -Encoding UTF8
    $refused = $false
    try { & (Join-Path $zipInstall 'scripts/uninstall.ps1') -InstallDir $zipInstall } catch { $refused = $_.Exception.Message -like 'Local journals were placed*' }
    if (-not $refused -or -not (Test-Path -LiteralPath $customJournal)) { throw 'Custom in-application journal was not preserved.' }
    Record-Check 'ZIP refuses removal of custom in-application state' 'Journal presence blocks recursive removal.'
    $savedCustomJournal = [IO.Path]::GetFullPath((Join-Path $stateDir 'preserved-custom-journal.fixture'))
    $resolvedCustomJournal = [IO.Path]::GetFullPath($customJournal)
    foreach ($verifiedPath in @($resolvedCustomJournal, $savedCustomJournal)) {
        if (-not $verifiedPath.StartsWith($outputRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture move escapes the isolated verification directory.' }
    }
    Move-Item -LiteralPath $resolvedCustomJournal -Destination $savedCustomJournal
    & (Join-Path $zipInstall 'scripts/uninstall.ps1') -InstallDir $zipInstall *>&1 | Tee-Object -FilePath (Join-Path $outputRoot 'zip-uninstall.log')
    if (Test-Path -LiteralPath $zipInstall) { throw 'ZIP application directory survived uninstall.' }
    if ((Get-FileHash -LiteralPath $sentinel).Hash -ne $stateHash) { throw 'State sentinel changed.' }
    Record-Check 'ZIP uninstall preserves separate state' 'Removed only the receipt-bound application tree; state sentinel unchanged.'
    if ($Msi) {
        $msiPath = [IO.Path]::GetFullPath($Msi)
        $installLog = Join-Path $outputRoot 'msi-install.log'
        $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', ('"' + $msiPath + '"'), ('INSTALLFOLDER="' + $msiInstall + '"'), '/qn', '/norestart', '/l*v', ('"' + $installLog + '"')) -WindowStyle Hidden -Wait -PassThru
        if ($process.ExitCode -notin @(0, 3010)) { throw "MSI install failed with $($process.ExitCode); see $installLog" }
        Record-Check 'MSI per-user isolated installation' "Exit $($process.ExitCode); INSTALLFOLDER=$msiInstall"
        Assert-Installed-Binaries $msiInstall 'MSI'
        & (Join-Path $msiInstall 'scripts/diagnose.ps1') -StateDir $stateDir *>&1 | Tee-Object -FilePath (Join-Path $outputRoot 'msi-diagnose.log')
        Record-Check 'MSI installed doctor and bundled SDK self-check' 'Native executables run from the MSI application directory; no broker request.'
        $msiCustomState = Join-Path $msiInstall 'custom-state'
        New-Item -ItemType Directory -Path $msiCustomState | Out-Null
        $msiCustomJournal = Join-Path $msiCustomState 'journal.sqlite3'
        'Isolated non-database MSI journal-preservation fixture.' | Set-Content -LiteralPath $msiCustomJournal -Encoding UTF8
        $msiJournalHash = (Get-FileHash -LiteralPath $msiCustomJournal).Hash
        $uninstallLog = Join-Path $outputRoot 'msi-uninstall.log'
        $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/x', ('"' + $msiPath + '"'), '/qn', '/norestart', '/l*v', ('"' + $uninstallLog + '"')) -WindowStyle Hidden -Wait -PassThru
        if ($process.ExitCode -notin @(0, 3010)) { throw "MSI uninstall failed with $($process.ExitCode); see $uninstallLog" }
        if (Test-Path -LiteralPath (Join-Path $msiInstall 'bin/leo-strategy-connector.exe')) { throw 'MSI executable survived uninstall.' }
        if ((Get-FileHash -LiteralPath $sentinel).Hash -ne $stateHash) { throw 'State sentinel changed.' }
        if ((Get-FileHash -LiteralPath $msiCustomJournal).Hash -ne $msiJournalHash) { throw 'MSI removed or changed custom in-application state.' }
        Record-Check 'MSI uninstall preserves separate and custom state' "Exit $($process.ExitCode); native executable removed; both state fixtures unchanged."
    }
    $receipt.status = 'passed'
} catch {
    $receipt.status = 'failed'
    $receipt.error = $_.Exception.Message
    throw
} finally {
    $receipt.finishedAt = [DateTime]::UtcNow.ToString('o')
    $receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputRoot 'windows-install-receipt.json') -Encoding UTF8
}
