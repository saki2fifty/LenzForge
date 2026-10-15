# Build MSMF Camera Capture Python Extension
# Run this to build msmf_capture.pyd

Write-Host "Building MSMF Camera Capture Extension..." -ForegroundColor Cyan
Write-Host "=" * 50

# Check Python
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Host "[ERROR] Python not found!" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Python: $($python.Source)"

# Check pybind11
Write-Host "[INFO] Checking pybind11..."
python -c "import pybind11" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] pybind11 not installed, installing..." -ForegroundColor Yellow
    python -m pip install pybind11
}

# Build extension
Write-Host "[INFO] Building extension..."
python setup.py build_ext --inplace

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[SUCCESS] Build complete!" -ForegroundColor Green
    Write-Host "Extension: msmf_capture.pyd" -ForegroundColor Green
    
    # Copy to parent directory for easy import
    if (Test-Path "msmf_capture*.pyd") {
        Copy-Item "msmf_capture*.pyd" "..\msmf_capture.pyd" -Force
        Write-Host "[INFO] Copied to backend_v2/capture/" -ForegroundColor Cyan
    }
} else {
    Write-Host ""
    Write-Host "[ERROR] Build failed!" -ForegroundColor Red
    exit 1
}
