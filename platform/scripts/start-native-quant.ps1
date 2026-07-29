$ErrorActionPreference = 'Stop'
$Workspace = Split-Path -Parent $PSScriptRoot
$Executable = Join-Path $Workspace 'quant_core_cpp\build\axiod.exe'
if (-not (Test-Path -LiteralPath $Executable)) { & (Join-Path $PSScriptRoot 'build-native-quant.ps1') }
$Runtime = Join-Path $Workspace '.quant-runtime'
New-Item -ItemType Directory -Force -Path $Runtime | Out-Null
$StateFile = Join-Path $Runtime 'native-process.json'
if (Test-Path -LiteralPath $StateFile) {
    $Old = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
    if (Get-Process -Id $Old.pid -ErrorAction SilentlyContinue) {
        Write-Output "axiod is already running (PID $($Old.pid))"
        exit 0
    }
}
$env:Path = "C:\msys64\ucrt64\bin;$env:Path"
$Process = Start-Process -FilePath $Executable -WorkingDirectory $Workspace -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $Runtime 'axiod.stdout.log') `
    -RedirectStandardError (Join-Path $Runtime 'axiod.stderr.log')
@{ pid = $Process.Id; executable = $Executable; startedAt = (Get-Date).ToUniversalTime().ToString('o') } |
    ConvertTo-Json | Set-Content -LiteralPath $StateFile -Encoding utf8
Write-Output "axiod started (PID $($Process.Id)); paper-only, kill switch remains active"
