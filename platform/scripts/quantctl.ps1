$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$quantRoot = Join-Path $workspace 'quant_engine_rs'
$cargo = Join-Path $env:USERPROFILE '.cargo\bin\cargo.exe'
$executable = Join-Path $quantRoot 'target\release\quantctl.exe'

if (-not (Test-Path -LiteralPath $cargo)) {
  throw 'Rust toolchain not found.'
}
$sourceFiles = @(
  (Join-Path $quantRoot 'Cargo.toml'),
  (Join-Path $quantRoot 'Cargo.lock')
) + @(Get-ChildItem -LiteralPath (Join-Path $quantRoot 'src') -Recurse -File | Select-Object -ExpandProperty FullName)
$latestSource = $sourceFiles |
  Where-Object { Test-Path -LiteralPath $_ } |
  ForEach-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc } |
  Sort-Object -Descending |
  Select-Object -First 1
$needsBuild = -not (Test-Path -LiteralPath $executable)
if (-not $needsBuild) {
  $needsBuild = $latestSource -gt (Get-Item -LiteralPath $executable).LastWriteTimeUtc
}
if ($needsBuild) {
  & $cargo build --release --bin quantctl --manifest-path (Join-Path $quantRoot 'Cargo.toml')
  if ($LASTEXITCODE -ne 0) { throw 'Rust quantctl build failed.' }
}
Push-Location $quantRoot
$quantExitCode = 0
try {
  & $executable @args
  $quantExitCode = $LASTEXITCODE
} finally {
  Pop-Location
}
if ($quantExitCode -ne 0) {
  throw "quantctl exited with code $quantExitCode."
}
$global:LASTEXITCODE = 0
