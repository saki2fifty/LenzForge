$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$PythonExe = Join-Path $ProjectRoot "buildtools\python\python.exe"
$MainPy = Join-Path $ProjectRoot "workspace\webcam-facemesh\main.py"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Testing LenzForge Application" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $PythonExe)) {
    Write-Host "[ERROR] Python not found at: $PythonExe" -ForegroundColor Red
    Write-Host "[ERROR] Please run 00-Setup.ps1 first" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $MainPy)) {
    Write-Host "[ERROR] Application not found at: $MainPy" -ForegroundColor Red
    Write-Host "[ERROR] Please run 00-Setup.ps1 first" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Validating Python installation..." -ForegroundColor Cyan
$PythonVersion = & $PythonExe --version 2>&1
Write-Host "[OK] $PythonVersion" -ForegroundColor Green

Write-Host ""
Write-Host "[INFO] Validating required packages..." -ForegroundColor Cyan

$TestCV2 = & $PythonExe -c "import cv2; print(cv2.__version__)" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] opencv-python $TestCV2" -ForegroundColor Green
} else {
    Write-Host "[ERROR] opencv-python not installed or not working" -ForegroundColor Red
    exit 1
}

$TestMP = & $PythonExe -c "import mediapipe; print(mediapipe.__version__)" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] mediapipe $TestMP" -ForegroundColor Green
} else {
    Write-Host "[ERROR] mediapipe not installed or not working" -ForegroundColor Red
    exit 1
}

$TestPIL = & $PythonExe -c "import PIL; print(PIL.__version__)" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] PIL/Pillow $TestPIL" -ForegroundColor Green
} else {
    Write-Host "[WARNING] PIL/Pillow not available (optional)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  All Validations Passed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "[INFO] Launching application..." -ForegroundColor Cyan
Write-Host "[INFO] Close the application window to return to the console" -ForegroundColor Gray
Write-Host ""

& $PythonExe $MainPy

Write-Host ""
Write-Host "[INFO] Application closed" -ForegroundColor Cyan

exit 0
