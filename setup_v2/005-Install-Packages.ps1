$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$BuildToolsDir = Join-Path $ProjectRoot "buildtools\python"
$PythonExe = Join-Path $BuildToolsDir "python.exe"
$PipExe = Join-Path $BuildToolsDir "Scripts\pip.exe"
$LogDir = Join-Path $ProjectRoot "logs"
$LogFile = Join-Path $LogDir "package_installation_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

# Create logs directory
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

Write-Host "[INFO] Installing Python packages..." -ForegroundColor Cyan
Write-Host "[INFO] Installation log: $LogFile" -ForegroundColor Gray

if (-not (Test-Path $PythonExe)) {
    Write-Host "[ERROR] Python not found at: $PythonExe" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $PipExe)) {
    Write-Host "[ERROR] pip not found at: $PipExe" -ForegroundColor Red
    Write-Host "[ERROR] Please run 03-Setup-Pip.ps1 first" -ForegroundColor Red
    exit 1
}

function Test-PackageInstalled {
    param([string]$PackageName)
    
    # Temporarily disable strict error handling for package check
    $PrevErrorPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    
    $Result = & $PythonExe -c "import $PackageName" 2>&1
    $Success = $LASTEXITCODE -eq 0
    
    # Restore error preference
    $ErrorActionPreference = $PrevErrorPref
    
    return $Success
}

Write-Host "[INFO] Checking opencv-python..." -ForegroundColor Yellow
if (Test-PackageInstalled "cv2") {
    Write-Host "[OK] opencv-python already installed" -ForegroundColor Green
    "opencv-python: Already installed" | Add-Content $LogFile
} else {
    Write-Host "[INFO] Installing opencv-python..." -ForegroundColor Yellow
    "Installing opencv-python..." | Add-Content $LogFile
    & $PipExe install opencv-python --quiet --no-warn-script-location 2>&1 | Add-Content $LogFile
    
    if (Test-PackageInstalled "cv2") {
        Write-Host "[SUCCESS] opencv-python installed" -ForegroundColor Green
        "opencv-python: Installed successfully" | Add-Content $LogFile
    } else {
        Write-Host "[ERROR] opencv-python installation failed" -ForegroundColor Red
        "opencv-python: Installation FAILED" | Add-Content $LogFile
        exit 1
    }
}

Write-Host "[INFO] Checking mediapipe..." -ForegroundColor Yellow
if (Test-PackageInstalled "mediapipe") {
    Write-Host "[OK] mediapipe already installed" -ForegroundColor Green
    "mediapipe: Already installed" | Add-Content $LogFile
} else {
    Write-Host "[INFO] Installing mediapipe..." -ForegroundColor Yellow
    Write-Host "[INFO] This may take a few minutes..." -ForegroundColor Gray
    "Installing mediapipe (this may take a few minutes)..." | Add-Content $LogFile
    
    # Temporarily allow errors (dependency warnings are common and OK)
    $PrevErrorPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    
    & $PipExe install mediapipe --quiet --no-warn-script-location 2>&1 | Add-Content $LogFile
    
    $ErrorActionPreference = $PrevErrorPref
    
    if (Test-PackageInstalled "mediapipe") {
        Write-Host "[SUCCESS] mediapipe installed" -ForegroundColor Green
        "mediapipe: Installed successfully (dependency warnings are normal)" | Add-Content $LogFile
    } else {
        Write-Host "[ERROR] mediapipe installation failed" -ForegroundColor Red
        "mediapipe: Installation FAILED" | Add-Content $LogFile
        exit 1
    }
}

Write-Host "[INFO] Checking pygrabber..." -ForegroundColor Yellow
if (Test-PackageInstalled "pygrabber") {
    Write-Host "[OK] pygrabber already installed" -ForegroundColor Green
    "pygrabber: Already installed" | Add-Content $LogFile
} else {
    Write-Host "[INFO] Installing pygrabber..." -ForegroundColor Yellow
    "Installing pygrabber..." | Add-Content $LogFile
    & $PipExe install pygrabber --quiet --no-warn-script-location 2>&1 | Add-Content $LogFile
    
    if (Test-PackageInstalled "pygrabber") {
        Write-Host "[SUCCESS] pygrabber installed" -ForegroundColor Green
        "pygrabber: Installed successfully" | Add-Content $LogFile
    } else {
        Write-Host "[ERROR] pygrabber installation failed" -ForegroundColor Red
        "pygrabber: Installation FAILED" | Add-Content $LogFile
        exit 1
    }
}

Write-Host "[INFO] Checking Flask..." -ForegroundColor Yellow
if (Test-PackageInstalled "flask") {
    Write-Host "[OK] Flask already installed" -ForegroundColor Green
    "Flask: Already installed" | Add-Content $LogFile
} else {
    Write-Host "[INFO] Installing Flask..." -ForegroundColor Yellow
    "Installing Flask, flask-cors, and flask-socketio..." | Add-Content $LogFile
    & $PipExe install Flask flask-cors flask-socketio --quiet --no-warn-script-location 2>&1 | Add-Content $LogFile
    
    if (Test-PackageInstalled "flask") {
        Write-Host "[SUCCESS] Flask installed" -ForegroundColor Green
        "Flask: Installed successfully" | Add-Content $LogFile
    } else {
        Write-Host "[ERROR] Flask installation failed" -ForegroundColor Red
        "Flask: Installation FAILED" | Add-Content $LogFile
        exit 1
    }
}

Write-Host "[INFO] Checking flask-socketio..." -ForegroundColor Yellow
if (Test-PackageInstalled "flask_socketio") {
    Write-Host "[OK] flask-socketio already installed" -ForegroundColor Green
    "flask-socketio: Already installed" | Add-Content $LogFile
} else {
    Write-Host "[INFO] Installing flask-socketio..." -ForegroundColor Yellow
    "Installing flask-socketio..." | Add-Content $LogFile
    & $PipExe install flask-socketio --quiet --no-warn-script-location 2>&1 | Add-Content $LogFile
    
    if (Test-PackageInstalled "flask_socketio") {
        Write-Host "[SUCCESS] flask-socketio installed" -ForegroundColor Green
        "flask-socketio: Installed successfully" | Add-Content $LogFile
    } else {
        Write-Host "[ERROR] flask-socketio installation failed" -ForegroundColor Red
        "flask-socketio: Installation FAILED" | Add-Content $LogFile
        exit 1
    }
}

Write-Host "[INFO] Checking psutil..." -ForegroundColor Yellow
if (Test-PackageInstalled "psutil") {
    Write-Host "[OK] psutil already installed" -ForegroundColor Green
    "psutil: Already installed" | Add-Content $LogFile
} else {
    Write-Host "[INFO] Installing psutil..." -ForegroundColor Yellow
    "Installing psutil..." | Add-Content $LogFile
    & $PipExe install psutil --quiet --no-warn-script-location 2>&1 | Add-Content $LogFile
    
    if (Test-PackageInstalled "psutil") {
        Write-Host "[SUCCESS] psutil installed" -ForegroundColor Green
        "psutil: Installed successfully" | Add-Content $LogFile
    } else {
        Write-Host "[ERROR] psutil installation failed" -ForegroundColor Red
        "psutil: Installation FAILED" | Add-Content $LogFile
        exit 1
    }
}

Write-Host "[INFO] Checking SCons..." -ForegroundColor Yellow
if (Test-PackageInstalled "SCons") {
    Write-Host "[OK] SCons already installed" -ForegroundColor Green
    "SCons: Already installed" | Add-Content $LogFile
} else {
    Write-Host "[INFO] Installing SCons (required for GDExtension)..." -ForegroundColor Yellow
    "Installing SCons..." | Add-Content $LogFile
    & $PipExe install scons --quiet --no-warn-script-location 2>&1 | Add-Content $LogFile
    
    if (Test-PackageInstalled "SCons") {
        Write-Host "[SUCCESS] SCons installed" -ForegroundColor Green
        "SCons: Installed successfully" | Add-Content $LogFile
    } else {
        Write-Host "[ERROR] SCons installation failed" -ForegroundColor Red
        "SCons: Installation FAILED" | Add-Content $LogFile
        exit 1
    }
}

Write-Host "[INFO] Checking pyvirtualcam..." -ForegroundColor Yellow
if (Test-PackageInstalled "pyvirtualcam") {
    Write-Host "[OK] pyvirtualcam already installed" -ForegroundColor Green
    "pyvirtualcam: Already installed" | Add-Content $LogFile
} else {
    Write-Host "[INFO] Installing pyvirtualcam..." -ForegroundColor Yellow
    "Installing pyvirtualcam..." | Add-Content $LogFile
    & $PipExe install pyvirtualcam --quiet --no-warn-script-location 2>&1 | Add-Content $LogFile
    
    if (Test-PackageInstalled "pyvirtualcam") {
        Write-Host "[SUCCESS] pyvirtualcam installed" -ForegroundColor Green
        "pyvirtualcam: Installed successfully" | Add-Content $LogFile
    } else {
        Write-Host "[ERROR] pyvirtualcam installation failed" -ForegroundColor Red
        "pyvirtualcam: Installation FAILED" | Add-Content $LogFile
        exit 1
    }
}

Write-Host "[INFO] Checking markdown..." -ForegroundColor Yellow
if (Test-PackageInstalled "markdown") {
    Write-Host "[OK] markdown already installed" -ForegroundColor Green
    "markdown: Already installed" | Add-Content $LogFile
} else {
    Write-Host "[INFO] Installing markdown..." -ForegroundColor Yellow
    "Installing markdown..." | Add-Content $LogFile
    & $PipExe install markdown --quiet --no-warn-script-location 2>&1 | Add-Content $LogFile
    
    if (Test-PackageInstalled "markdown") {
        Write-Host "[SUCCESS] markdown installed" -ForegroundColor Green
        "markdown: Installed successfully" | Add-Content $LogFile
    } else {
        Write-Host "[ERROR] markdown installation failed" -ForegroundColor Red
        "markdown: Installation FAILED" | Add-Content $LogFile
        exit 1
    }
}

Write-Host ""
Write-Host "[SUCCESS] All packages installed successfully" -ForegroundColor Green
Write-Host ""
Write-Host "Installed packages:" -ForegroundColor Cyan
& $PipExe list | Select-String -Pattern "(opencv|mediapipe|pygrabber|numpy)"

exit 0
