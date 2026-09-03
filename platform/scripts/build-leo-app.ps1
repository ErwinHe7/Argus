[CmdletBinding()]
param(
  [string]$Flutter = 'C:\Users\Hj\develop\flutter\bin\flutter.bat'
)

$ErrorActionPreference = 'Stop'

$platformRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $platformRoot '..'))
$appRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'ritual-investing-app'))
$targetRoot = [System.IO.Path]::GetFullPath((Join-Path $platformRoot 'public\app'))
$expectedTarget = [System.IO.Path]::GetFullPath((Join-Path $platformRoot 'public\app'))

if ($targetRoot -ne $expectedTarget -or -not $targetRoot.StartsWith($platformRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Refusing to replace an unexpected output directory: $targetRoot"
}
if (-not (Test-Path -LiteralPath $Flutter -PathType Leaf)) {
  throw "Flutter was not found at $Flutter"
}
if (-not (Test-Path -LiteralPath (Join-Path $appRoot 'pubspec.yaml') -PathType Leaf)) {
  throw "The Leo member app was not found at $appRoot"
}

Push-Location $appRoot
try {
  & $Flutter pub get --enforce-lockfile
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }

  & $Flutter build web --release `
    --base-href=/app/ `
    --no-web-resources-cdn `
    --no-source-maps `
    --no-wasm-dry-run `
    --dart-define-from-file=config/beta.json
  if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed' }
} finally {
  Pop-Location
}

New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
$resolvedTarget = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $targetRoot).Path)
if ($resolvedTarget -ne $expectedTarget) {
  throw "Refusing to replace an unexpected resolved output directory: $resolvedTarget"
}

Get-ChildItem -LiteralPath $resolvedTarget -Force | Remove-Item -Recurse -Force
Copy-Item -Path (Join-Path $appRoot 'build\web\*') -Destination $resolvedTarget -Recurse -Force

Write-Output "Leo member app built at $resolvedTarget"
