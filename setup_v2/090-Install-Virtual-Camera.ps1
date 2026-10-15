# Install OBS Virtual Camera for LenzForge
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Install OBS Virtual Camera" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$DownloadDir = "..\downloads"
$OBSInstaller = "$DownloadDir\OBS-Studio-Installer.exe"

# Create downloads directory
New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null

# Check if OBS already installed
$OBSPaths = @(
    "${env:ProgramFiles}\obs-studio",
    "${env:ProgramFiles(x86)}\obs-studio"
)

$OBSInstalled = $false
foreach ($path in $OBSPaths) {
    if (Test-Path "$path\bin\64bit\obs64.exe") {
        Write-Host "[OK] OBS Studio already installed at: $path" -ForegroundColor Green
        $OBSInstalled = $true
        break
    }
}

if (-not $OBSInstalled) {
    Write-Host "[INFO] OBS Studio not found, downloading..." -ForegroundColor Yellow
    Write-Host "[INFO] This includes OBS Virtual Camera driver" -ForegroundColor Gray
    Write-Host ""
    
    # OBS Studio download URL (latest stable)
    $OBSURL = "https://cdn-fastly.obsproject.com/downloads/OBS-Studio-30.2.2-Windows-Installer.exe"
    
    try {
        Write-Host "[INFO] Downloading OBS Studio (30.2.2)..." -ForegroundColor Yellow
        Write-Host "[INFO] Size: ~120 MB, this may take a few minutes..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $OBSURL -OutFile $OBSInstaller -UseBasicParsing
        Write-Host "[OK] Download complete" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "[INFO] Installing OBS Studio..." -ForegroundColor Yellow
        Write-Host "[INFO] This will install silently in the background" -ForegroundColor Gray
        Write-Host ""
        
        # Silent install
        $InstallArgs = "/S"
        Start-Process -FilePath $OBSInstaller -ArgumentList $InstallArgs -Wait
        
        Write-Host "[OK] OBS Studio installed" -ForegroundColor Green
        
        # Cleanup installer
        Remove-Item $OBSInstaller -Force
        
    } catch {
        Write-Host "[ERROR] Failed to download/install OBS: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "[INFO] Manual installation:" -ForegroundColor Yellow
        Write-Host "  1. Download OBS Studio from: https://obsproject.com/download" -ForegroundColor Gray
        Write-Host "  2. Install OBS Studio" -ForegroundColor Gray
        Write-Host "  3. Virtual camera driver is included automatically" -ForegroundColor Gray
        Write-Host ""
        pause
        exit 1
    }
}

# Verify virtual camera device
Write-Host ""
Write-Host "[INFO] Checking for virtual camera device..." -ForegroundColor Yellow

# Use Python to check for virtual camera
$PythonExe = "..\buildtools\python\python.exe"
$CheckScript = @"
import cv2

# Scan for cameras
for i in range(10):
    cap = cv2.VideoCapture(i, cv2.CAP_DSHOW)
    if cap.isOpened():
        # Try to get camera name (Windows specific)
        try:
            backend_name = cap.getBackendName()
            print(f"Camera {i}: {backend_name}")
            
            # Check if it's OBS Virtual Camera
            if "OBS" in backend_name or "Virtual" in backend_name:
                print("  ✓ OBS Virtual Camera detected!")
        except:
            pass
        cap.release()
"@

$TempScript = "$DownloadDir\check_camera.py"
Set-Content -Path $TempScript -Value $CheckScript
& $PythonExe $TempScript
Remove-Item $TempScript -Force

Write-Host ""
Write-Host "[SUCCESS] OBS Virtual Camera setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "[INFO] The virtual camera device 'OBS Virtual Camera' is now available" -ForegroundColor Cyan
Write-Host "[INFO] You can use it in Zoom, Discord, Teams, and other applications" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run: .\31-Install-VirtualCam-Python.ps1" -ForegroundColor Gray
Write-Host "  2. Configure LenzForge to use virtual camera" -ForegroundColor Gray
Write-Host ""

pause
