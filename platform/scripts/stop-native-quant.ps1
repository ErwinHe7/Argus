$ErrorActionPreference = 'Stop'
$Workspace = Split-Path -Parent $PSScriptRoot
$StateFile = Join-Path $Workspace '.quant-runtime\native-process.json'
if (-not (Test-Path -LiteralPath $StateFile)) { Write-Output 'axiod is not registered as running'; exit 0 }
$State = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
$Process = Get-Process -Id $State.pid -ErrorAction SilentlyContinue
if ($Process) { Stop-Process -Id $State.pid; $Process.WaitForExit(5000) | Out-Null }
Remove-Item -LiteralPath $StateFile -Force
Write-Output "axiod stopped (PID $($State.pid))"
