# Build MSMF Extension with VERBOSE output for debugging
# Run this to see actual compilation errors

Write-Host "================================" -ForegroundColor Cyan
Write-Host "  MSMF Extension DEBUG BUILD" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

$extensionDir = "$PSScriptRoot\assets\backend_v2\capture\msmf_extension"

Write-Host "[INFO] Building with verbose output..." -ForegroundColor Cyan
Write-Host "[INFO] Location: $extensionDir" -ForegroundColor Gray
Write-Host ""

Push-Location $extensionDir

# Build with verbose output
Write-Host ">>> Running: python setup.py build_ext --inplace --verbose" -ForegroundColor Yellow
Write-Host ""

python setup.py build_ext --inplace --verbose 2>&1 | Tee-Object build_verbose.txt

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Full output saved to: build_verbose.txt" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

Pop-Location

Write-Host "Please share the contents of build_verbose.txt to diagnose the issue" -ForegroundColor Yellow
