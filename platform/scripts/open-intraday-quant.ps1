$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$frontendUrl = "http://127.0.0.1:3000/quant/intraday"

$frontend = Get-NetTCPConnection -State Listen -LocalPort 3000 -ErrorAction SilentlyContinue | Select-Object -First 1
$backend = Get-NetTCPConnection -State Listen -LocalPort 8001 -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $frontend -or -not $backend) {
  if ($frontend -or $backend) {
    throw "Only one AXIO7 service is running. Use npm run quant:stop, then npm run quant:open."
  }
  & (Join-Path $PSScriptRoot "start-intraday-quant.ps1")
}

Start-Process $frontendUrl
Write-Output "Opened AXIO7 Intraday Research Terminal: $frontendUrl"
