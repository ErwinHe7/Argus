$ErrorActionPreference = 'Stop'
$personalRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$personalRuntime = Join-Path $personalRoot '.quant-runtime\personal-moomoo'
$personalVenv = Join-Path $personalRuntime 'venv'
$personalPython = Join-Path $personalVenv 'Scripts\python.exe'
if (-not (Test-Path -LiteralPath $personalPython)) {
  New-Item -ItemType Directory -Path $personalRuntime -Force | Out-Null
  & py -3.13 -m venv $personalVenv
  if ($LASTEXITCODE -ne 0) { throw 'Install Python 3.13, then run setup again.' }
}
& $personalPython -m pip install 'moomoo-api==10.9.6908'
if ($LASTEXITCODE -ne 0) { throw 'Official moomoo SDK installation failed.' }
& $personalPython -m pip check
if ($LASTEXITCODE -ne 0) { throw 'Python dependency verification failed.' }
Write-Output 'SDK ready. Install the stable Windows GUI OpenD from https://www.moomoo.com/download/OpenAPI and sign in yourself.'
Write-Output 'Then run scripts/start-personal-trading.ps1. Real manual orders require its explicit -AllowLiveTrading option.'
