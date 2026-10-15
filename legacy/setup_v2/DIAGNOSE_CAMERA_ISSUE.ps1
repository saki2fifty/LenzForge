# Diagnostic Script for Camera Detection Issue
# Run this on any computer where only 1 camera is detected

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Camera Detection Diagnostic" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "[1] Checking Python Configuration..." -ForegroundColor Yellow
Write-Host ""

# Check buildtools Python
$PortablePython = Join-Path $ProjectRoot "buildtools\python\python.exe"
if (Test-Path $PortablePython) {
    Write-Host "[OK] Buildtools Python exists: $PortablePython" -ForegroundColor Green
    $pythonVersion = & $PortablePython --version
    Write-Host "     Version: $pythonVersion" -ForegroundColor Gray
} else {
    Write-Host "[ERROR] Buildtools Python NOT found!" -ForegroundColor Red
    Write-Host "        Expected at: $PortablePython" -ForegroundColor Red
    Write-Host "        Run: .\setup_v2\000-Setup.ps1" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[2] Checking MSMF Extension..." -ForegroundColor Yellow
Write-Host ""

# Check if .pyd exists in source
$SourcePyd = Join-Path $ProjectRoot "setup_v2\assets\backend_v2\capture\msmf_capture.pyd"
if (Test-Path $SourcePyd) {
    $pydSize = (Get-Item $SourcePyd).Length
    Write-Host "[OK] Source .pyd exists: $SourcePyd" -ForegroundColor Green
    Write-Host "     Size: $pydSize bytes" -ForegroundColor Gray
} else {
    Write-Host "[ERROR] Source .pyd NOT found!" -ForegroundColor Red
    Write-Host "        Expected at: $SourcePyd" -ForegroundColor Red
    Write-Host "        Run: .\setup_v2\020-Build-MSMF-Extension.ps1" -ForegroundColor Yellow
}

# Check if .pyd exists in workspace
$WorkspacePyd = Join-Path $ProjectRoot "workspace_v2\cpp-viewer\backend_v2\capture\msmf_capture.pyd"
if (Test-Path $WorkspacePyd) {
    $pydSize = (Get-Item $WorkspacePyd).Length
    Write-Host "[OK] Workspace .pyd exists: $WorkspacePyd" -ForegroundColor Green
    Write-Host "     Size: $pydSize bytes" -ForegroundColor Gray
} else {
    Write-Host "[ERROR] Workspace .pyd NOT found!" -ForegroundColor Red
    Write-Host "        Expected at: $WorkspacePyd" -ForegroundColor Red
    Write-Host "        Run: .\setup_v2\030-Deploy-Backend.ps1" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[3] Checking MinGW DLLs..." -ForegroundColor Yellow
Write-Host ""

$CapturePath = Join-Path $ProjectRoot "workspace_v2\cpp-viewer\backend_v2\capture"
$RequiredDlls = @("libgcc_s_seh-1.dll", "libstdc++-6.dll", "libwinpthread-1.dll")

$allDllsPresent = $true
foreach ($dll in $RequiredDlls) {
    $dllPath = Join-Path $CapturePath $dll
    if (Test-Path $dllPath) {
        Write-Host "[OK] $dll present" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] $dll MISSING!" -ForegroundColor Red
        $allDllsPresent = $false
    }
}

if (-not $allDllsPresent) {
    Write-Host ""
    Write-Host "[FIX] Copy DLLs manually:" -ForegroundColor Yellow
    Write-Host "      copy buildtools\mingw\bin\*.dll workspace_v2\cpp-viewer\backend_v2\capture\" -ForegroundColor White
}

Write-Host ""
Write-Host "[4] Testing MSMF Import..." -ForegroundColor Yellow
Write-Host ""

if (Test-Path $PortablePython) {
    Push-Location (Join-Path $ProjectRoot "workspace_v2\cpp-viewer\backend_v2\capture")
    
    $importTest = & $PortablePython -c "import sys; sys.path.insert(0, '.'); import msmf_capture; print('SUCCESS')" 2>&1
    
    if ($importTest -match "SUCCESS") {
        Write-Host "[OK] MSMF imports successfully!" -ForegroundColor Green
        
        # Try to enumerate cameras
        Write-Host ""
        Write-Host "[5] Testing Camera Enumeration..." -ForegroundColor Yellow
        Write-Host ""
        
        $cameraTest = & $PortablePython -c @"
import sys
sys.path.insert(0, '.')
import msmf_capture
cameras = msmf_capture.enumerate_cameras()
print(f'Found {len(cameras)} camera(s)')
for i, cam in enumerate(cameras):
    print(f'  Camera {i}: {cam.name}')
"@
        Write-Host $cameraTest -ForegroundColor Cyan
        
    } else {
        Write-Host "[ERROR] MSMF import failed!" -ForegroundColor Red
        Write-Host "Error details:" -ForegroundColor Red
        Write-Host $importTest -ForegroundColor Red
        Write-Host ""
        Write-Host "[LIKELY CAUSE] .pyd built with different Python version" -ForegroundColor Yellow
        Write-Host "[FIX] Rebuild with buildtools Python:" -ForegroundColor Yellow
        Write-Host "      .\setup_v2\020-Build-MSMF-Extension.ps1" -ForegroundColor White
    }
    
    Pop-Location
}

Write-Host ""
Write-Host "[6] Checking Backend Logs..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Look for these messages when starting backend:" -ForegroundColor Gray
Write-Host "  GOOD: 'MSMF extension loaded successfully'" -ForegroundColor Green
Write-Host "  BAD:  'MSMF extension not available, OpenCV fallback'" -ForegroundColor Red
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Diagnostic Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "If MSMF import failed, the issue is Python version mismatch." -ForegroundColor Yellow
Write-Host "Rebuild with: .\setup_v2\020-Build-MSMF-Extension.ps1" -ForegroundColor Yellow
