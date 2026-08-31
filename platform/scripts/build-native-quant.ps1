$ErrorActionPreference = 'Stop'
$Workspace = Split-Path -Parent $PSScriptRoot
$Bash = 'C:\msys64\usr\bin\bash.exe'
if (-not (Test-Path -LiteralPath $Bash)) {
    throw 'MSYS2 is required at C:\msys64. The project setup installed it automatically.'
}
$Drive = $Workspace.Substring(0, 1).ToLowerInvariant()
$Rest = $Workspace.Substring(2).Replace('\', '/')
$MsysWorkspace = "/$Drive$Rest"
$WindowsTemp = Join-Path $Workspace 'quant_core_cpp\build\tmp'
New-Item -ItemType Directory -Force -Path $WindowsTemp | Out-Null
$MsysTemp = "$MsysWorkspace/quant_core_cpp/build/tmp"
& $Bash -lc "export PATH=/ucrt64/bin:`$PATH; cd '$MsysWorkspace'; export TMPDIR='$MsysTemp' TEMP='$MsysTemp' TMP='$MsysTemp'; cmake -S quant_core_cpp -B quant_core_cpp/build -G Ninja -DCMAKE_BUILD_TYPE=Release -DAXIO_WARNINGS_AS_ERRORS=ON && cmake --build quant_core_cpp/build -j 4 && cd quant_core_cpp/build && ctest --output-on-failure"
if ($LASTEXITCODE -ne 0) { throw "Native Quant OS build failed with exit code $LASTEXITCODE" }
