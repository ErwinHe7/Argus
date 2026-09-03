param(
    [int]$Port = 8101
)

$ErrorActionPreference = 'Stop'

$Token = $env:AXIO7_SMOKE_RESEARCH_TOKEN
if ([string]::IsNullOrWhiteSpace($Token) -or $Token.Length -lt 32) {
    throw 'AXIO7_SMOKE_RESEARCH_TOKEN must contain at least 32 characters.'
}

$Workspace = Split-Path -Parent $PSScriptRoot
$Engine = Join-Path $Workspace 'quant_engine_rs'
$Executable = Join-Path $Engine 'target\debug\quantd.exe'
if (-not (Test-Path -LiteralPath $Executable)) {
    throw 'Build the debug quantd binary before running this smoke server.'
}

$env:INTRADAY_QUANT_TOKEN = $Token
Set-Location -LiteralPath $Engine
& $Executable --config configs/production.yaml --port $Port
