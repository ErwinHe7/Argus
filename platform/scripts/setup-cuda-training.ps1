param(
    [string]$PythonVersion = "3.12",
    [string]$TorchVersion = "2.12.0",
    [string]$CudaWheelIndex = "https://download.pytorch.org/whl/cu130"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$researchRoot = Join-Path $repoRoot "intraday_quant"
$venvRoot = Join-Path $researchRoot ".venv-cuda"
$python = Join-Path $venvRoot "Scripts\python.exe"
$smokeTest = Join-Path $researchRoot "scripts\cuda_smoke.py"

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "uv is required. Install it from https://docs.astral.sh/uv/ and retry."
}

uv python install $PythonVersion
if (-not (Test-Path -LiteralPath $python)) {
    uv venv --seed --python $PythonVersion $venvRoot
}

uv pip install --python $python --editable $researchRoot
& $python -m pip install "torch==$TorchVersion" --index-url $CudaWheelIndex
uv pip install --python $python "onnx>=1.19" "psycopg[binary]>=3.2" "pytest>=8.0"

& $python $smokeTest
if ($LASTEXITCODE -ne 0) {
    throw "CUDA smoke test failed."
}

Write-Output "CUDA_TRAINING_PYTHON=$python"
