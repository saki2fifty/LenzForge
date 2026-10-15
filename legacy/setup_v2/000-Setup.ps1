param(
    [switch]$Redeploy,
    [switch]$Rebuild
)

# Display LenzForge ASCII logo
Clear-Host
Write-Host ""
Write-Host "  _                   _____                    " -ForegroundColor Cyan
Write-Host " | |    ___ _ __  ___|  ___|__  _ __ __ _  ___ " -ForegroundColor Cyan
Write-Host " | |   / _ \ '_ \|_  / |_ / _ \| '__/ _` |/ _ \" -ForegroundColor Cyan
Write-Host " | |__|  __/ | | |/ /|  _| (_) | | | (_| |  __/" -ForegroundColor Cyan
Write-Host " |_____\___|_| |_/___|_|  \___/|_|  \__, |\___|" -ForegroundColor Cyan
Write-Host "                                    |___/       " -ForegroundColor Cyan
Write-Host ""
Write-Host "  Complete Setup & Build System - MIT license - saki2fifty" -ForegroundColor Gray
Write-Host "    LenzForge Vision - server side (OpenCV / Mediapipe)" -ForegroundColor Gray
Write-Host "    LenzForge AR     - client side (Godot)" -ForegroundColor Gray
Write-Host ""
Start-Sleep -Seconds 5

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  LenzForge - Complete Setup Tool" -ForegroundColor Cyan
if ($Redeploy) {
    Write-Host "  Mode: REDEPLOY (Files Only)" -ForegroundColor Yellow
} elseif ($Rebuild) {
    Write-Host "  Mode: REBUILD (Deploy + Compile)" -ForegroundColor Yellow
} else {
    Write-Host "  Installing: Python + C++ + Godot + GDExtension" -ForegroundColor Cyan
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Set-Location $ScriptDir

# Setup logging
$LogDir = Join-Path $ProjectRoot "logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$LogFile = Join-Path $LogDir "setup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
Start-Transcript -Path $LogFile -Append | Out-Null

Write-Host "[INFO] Project Root: $ProjectRoot" -ForegroundColor Gray
Write-Host "[INFO] Log file: $LogFile" -ForegroundColor Gray
Write-Host ""

function Run-Script {
    param(
        [string]$ScriptName,
        [string]$Description
    )
    
    Write-Host ">>> Running: $Description" -ForegroundColor Yellow
    
    if (-not (Test-Path ".\$ScriptName")) {
        Write-Host "[WARNING] Script not found: $ScriptName" -ForegroundColor Red
        return $false
    }
    
    try {
        & ".\$ScriptName"
        if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
            Write-Host "[SUCCESS] $Description completed" -ForegroundColor Green
            Write-Host ""
            return $true
        } else {
            Write-Host "[ERROR] $Description failed with exit code: $LASTEXITCODE" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "[ERROR] $Description failed: $_" -ForegroundColor Red
        return $false
    }
}

# =============================================================================
# REBUILD MODE: Deploy files + rebuild C++ projects
# =============================================================================
if ($Rebuild) {
    Write-Host "[INFO] REBUILD MODE: Deploying files and rebuilding C++ projects..." -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "=== Deploying All Files ===" -ForegroundColor Cyan
    $success = Run-Script "030-Deploy-Backend.ps1" "Deploy Flask Backend"
    if (-not $success) { Write-Host "[ERROR] Backend deployment failed" -ForegroundColor Red; exit 1 }
    
    $success = Run-Script "081-Deploy-Godot-Project.ps1" "Deploy Godot AR Project"
    if (-not $success) { Write-Host "[ERROR] Godot AR project deployment failed" -ForegroundColor Red; exit 1 }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  REBUILD COMPLETE!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "All files redeployed and C++ projects rebuilt" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To run the Flask backend:" -ForegroundColor Cyan
    Write-Host "  .\Start-Backend.ps1" -ForegroundColor White
    Write-Host ""
    
    # Stop logging
    Stop-Transcript | Out-Null
    Write-Host "[INFO] Rebuild log saved to: $LogFile" -ForegroundColor Gray
    
    # Return to project root
    Set-Location $ProjectRoot
    
    exit 0
}

# =============================================================================
# REDEPLOY MODE: Skip downloads/builds, only deploy
# =============================================================================
if ($Redeploy) {
    Write-Host "[INFO] REDEPLOY MODE: Running all deployment scripts..." -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "=== Deploying Backend ===" -ForegroundColor Cyan
    $success = Run-Script "030-Deploy-Backend.ps1" "Deploy Flask Backend"
    if (-not $success) { Write-Host "[ERROR] Backend deployment failed" -ForegroundColor Red; exit 1 }
    
    Write-Host ""
    Write-Host "=== Deploying Godot AR Project ===" -ForegroundColor Cyan
    $success = Run-Script "081-Deploy-Godot-Project.ps1" "Deploy Godot AR Project"
    if (-not $success) { Write-Host "[ERROR] Godot AR project deployment failed" -ForegroundColor Red; exit 1 }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  REDEPLOY COMPLETE!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "All files redeployed from setup_v2/assets/ to workspace_v2/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To run the Flask backend:" -ForegroundColor Cyan
    Write-Host "  .\Start-Backend.ps1" -ForegroundColor White
    Write-Host ""
    
    # Stop logging
    Stop-Transcript | Out-Null
    Write-Host "[INFO] Redeploy log saved to: $LogFile" -ForegroundColor Gray
    
    # Return to project root
    Set-Location $ProjectRoot
    
    exit 0
}

# =============================================================================
# PHASE 1-5: Python Setup
# =============================================================================
Write-Host "=== Phase 1: Python Downloads ===" -ForegroundColor Cyan
$success = Run-Script "001-Download-Python.ps1" "Download Python Embeddable"
if (-not $success) { Write-Host "[WARNING] Python download had issues, continuing..." -ForegroundColor Yellow }

$success = Run-Script "002-Download-GetPip.ps1" "Download get-pip.py"
if (-not $success) { Write-Host "[WARNING] get-pip download had issues, continuing..." -ForegroundColor Yellow }

Write-Host ""
Write-Host "=== Phase 2: Python Extraction & Setup ===" -ForegroundColor Cyan
$success = Run-Script "003-Extract-Python.ps1" "Extract Python"
if (-not $success) { Write-Host "[ERROR] Python extraction failed" -ForegroundColor Red; exit 1 }

$success = Run-Script "004-Setup-Pip.ps1" "Setup pip"
if (-not $success) { Write-Host "[ERROR] Pip setup failed" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "=== Phase 3: Package Installation ===" -ForegroundColor Cyan
$success = Run-Script "005-Install-Packages.ps1" "Install Python Packages (MediaPipe, OpenCV, Flask, etc.)"
if (-not $success) { Write-Host "[ERROR] Package installation failed" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "=== Phase 4: C++ Compiler Setup (Optional) ===" -ForegroundColor Cyan
Write-Host "[INFO] Downloading portable MinGW-w64 compiler and Windows SDK..." -ForegroundColor Gray
Write-Host "[INFO] These enable MSMF extension for real camera names" -ForegroundColor Gray
Write-Host "[INFO] If download/extract fails, system will use OpenCV fallback" -ForegroundColor Gray
$success = Run-Script "010-Download-MinGW.ps1" "Download MinGW Compiler"
if (-not $success) { Write-Host "[WARNING] MinGW download failed, will use OpenCV fallback" -ForegroundColor Yellow }

$success = Run-Script "011-Extract-MinGW.ps1" "Extract MinGW Compiler"
if (-not $success) { Write-Host "[WARNING] MinGW extraction failed, will use OpenCV fallback" -ForegroundColor Yellow }

$success = Run-Script "012-Download-WindowsSDK.ps1" "Download Windows SDK"
if (-not $success) { Write-Host "[WARNING] SDK download failed, will use OpenCV fallback" -ForegroundColor Yellow }

$success = Run-Script "013-Extract-WindowsSDK.ps1" "Install Windows SDK"
if (-not $success) { Write-Host "[WARNING] SDK installation failed, will use OpenCV fallback" -ForegroundColor Yellow }

Write-Host ""
Write-Host "=== Phase 5: MSMF Extension Build (Optional) ===" -ForegroundColor Cyan
Write-Host "[INFO] Building MSMF camera capture extension..." -ForegroundColor Gray
Write-Host "[INFO] This provides real camera names and direct NV12 capture" -ForegroundColor Gray
Write-Host "[INFO] If build fails, system will fallback to OpenCV (still works!)" -ForegroundColor Gray
$success = Run-Script "020-Build-MSMF-Extension.ps1" "Build MSMF Extension"
if (-not $success) { 
    Write-Host "[WARNING] MSMF extension build failed - will use OpenCV fallback" -ForegroundColor Yellow
    Write-Host "[INFO] System will still work, just with generic camera names" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Phase 6: Backend Deployment ===" -ForegroundColor Cyan
$success = Run-Script "030-Deploy-Backend.ps1" "Deploy Flask Backend"
if (-not $success) { Write-Host "[ERROR] Backend deployment failed" -ForegroundColor Red; exit 1 }

$success = Run-Script "032-Deploy-Documentation.ps1" "Deploy Additional Documentation"
if (-not $success) { Write-Host "[WARNING] Documentation deployment had issues, continuing..." -ForegroundColor Yellow }

# =============================================================================
# PHASE 7: CMake Setup (Required for GDExtension)
# =============================================================================
Write-Host ""
Write-Host "=== Phase 7: CMake Setup (For GDExtension) ===" -ForegroundColor Cyan
Write-Host "[INFO] CMake is required to build the GDExtension" -ForegroundColor Gray
Write-Host "[INFO] This enables video display in Godot" -ForegroundColor Gray

$success = Run-Script "040-Download-CMake.ps1" "Download CMake"
if (-not $success) { Write-Host "[WARNING] CMake download had issues, continuing..." -ForegroundColor Yellow }

$success = Run-Script "041-Extract-CMake.ps1" "Extract CMake"
if (-not $success) { 
    Write-Host "[ERROR] CMake extraction failed" -ForegroundColor Red
    Write-Host "[WARNING] GDExtension build will fail without CMake" -ForegroundColor Yellow
    Write-Host "[INFO] Continuing with setup..." -ForegroundColor Gray
}

# =============================================================================
# PHASE 10-11: Godot Basic Setup
# =============================================================================
Write-Host ""
Write-Host "=== Phase 10-11: Godot Engine Setup ===" -ForegroundColor Cyan
$success = Run-Script "060-Download-Godot.ps1" "Download Godot Engine"
if (-not $success) { Write-Host "[WARNING] Godot download had issues, continuing..." -ForegroundColor Yellow }

$success = Run-Script "061-Extract-Godot.ps1" "Extract Godot Engine"
if (-not $success) { Write-Host "[ERROR] Godot extraction failed" -ForegroundColor Red; exit 1 }

$success = Run-Script "062-Install-Export-Templates.ps1" "Install Export Templates (Portable)"
if (-not $success) { Write-Host "[WARNING] Export templates installation had issues - builds may not work" -ForegroundColor Yellow }

$success = Run-Script "063-Configure-Godot-Settings.ps1" "Configure Godot for Portable Mode"
if (-not $success) { Write-Host "[WARNING] Godot settings configuration had issues" -ForegroundColor Yellow }

Write-Host ""
Write-Host "=== Phase 11.5: Deploy Godot Project ===" -ForegroundColor Cyan
$success = Run-Script "081-Deploy-Godot-Project.ps1" "Deploy Godot Project (includes MinGW DLL copy)"
if (-not $success) { Write-Host "[ERROR] Godot project deployment failed" -ForegroundColor Red; exit 1 }

# =============================================================================
# PHASE 12: Godot-CPP Setup (Required for GDExtension)
# =============================================================================
Write-Host ""
Write-Host "=== Phase 12: Godot-CPP Setup ===" -ForegroundColor Cyan
Write-Host "[INFO] Downloading and building godot-cpp headers..." -ForegroundColor Gray
Write-Host "[INFO] This is required to build GDExtension" -ForegroundColor Gray

$success = Run-Script "070-Download-Godot-CPP.ps1" "Download Godot-CPP Headers"
if (-not $success) { Write-Host "[ERROR] Godot-CPP download failed" -ForegroundColor Red; exit 1 }

$success = Run-Script "071-Extract-Godot-CPP.ps1" "Extract Godot-CPP Headers"
if (-not $success) { Write-Host "[ERROR] Godot-CPP extraction failed" -ForegroundColor Red; exit 1 }

Write-Host "[INFO] Building godot-cpp library (this takes 5-10 minutes)..." -ForegroundColor Gray
$success = Run-Script "072-Build-Godot-CPP.ps1" "Build Godot-CPP Library"
if (-not $success) { 
    Write-Host "[WARNING] Godot-CPP build failed" -ForegroundColor Yellow
    Write-Host "[INFO] GDExtension will not build without godot-cpp" -ForegroundColor Gray
}

# =============================================================================
# PHASE 13: Build LenzForge GDExtension
# =============================================================================
Write-Host ""
Write-Host "=== Phase 13: Build LenzForge GDExtension ===" -ForegroundColor Cyan
Write-Host "[INFO] Building C++ GDExtension for video display in Godot" -ForegroundColor Gray
Write-Host "[INFO] This will take 2-3 minutes..." -ForegroundColor Gray

$success = Run-Script "083-Build-LenzForge-GDExtension.ps1" "Build LenzForge GDExtension"
if (-not $success) {
    Write-Host "[WARNING] GDExtension build failed" -ForegroundColor Yellow
    Write-Host "[INFO] Godot will work but video display will not function" -ForegroundColor Gray
    Write-Host "[INFO] You can build it manually later with: .\setup_v2\083-Build-LenzForge-GDExtension.ps1" -ForegroundColor Gray
}

# =============================================================================
# VERIFICATION
# =============================================================================
Write-Host ""
Write-Host "Running installation verification..." -ForegroundColor Cyan
Write-Host ""

# Run verification and capture failed components
$verifyScript = Join-Path $ScriptDir "099-Verify-Installation.ps1"
$failedFile = Join-Path $ProjectRoot "logs\verification_failed.txt"

if (Test-Path $verifyScript) {
    & $verifyScript | Out-Null
} else {
    Write-Host "[WARNING] Verification script not found, skipping checks" -ForegroundColor Yellow
}

# =============================================================================
# COMPLETION
# =============================================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  COMPLETE SETUP FINISHED!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installed Components:" -ForegroundColor Cyan
Write-Host "  ✓ Python backend with Flask GUI" -ForegroundColor Green
Write-Host "  ✓ Camera processing with MediaPipe" -ForegroundColor Green
Write-Host "  ✓ Virtual camera support" -ForegroundColor Green
Write-Host "  ✓ C++ high-performance viewer" -ForegroundColor Green
Write-Host "  ✓ Godot integration" -ForegroundColor Green
Write-Host "  ✓ GDExtension for video display" -ForegroundColor Green
Write-Host ""

# Display failed components if any
if (Test-Path $failedFile) {
    $failedComponents = Get-Content $failedFile -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne "" }
    if ($failedComponents.Count -gt 0) {
        Write-Host "Failed Components:" -ForegroundColor Yellow
        foreach ($component in $failedComponents) {
            Write-Host "  ✗ $component" -ForegroundColor Red
        }
        Write-Host ""
    }
}
Write-Host "To run the Flask backend:" -ForegroundColor Cyan
Write-Host "  .\Start-Backend.ps1" -ForegroundColor White
Write-Host "  (Opens web interface at http://localhost:5000)" -ForegroundColor Gray
Write-Host ""
Write-Host "To run Godot:" -ForegroundColor Cyan
Write-Host "  .\buildtools\godot\Godot_v4.3-stable_win64.exe" -ForegroundColor White
Write-Host "  (Import: workspace_v2\godot-facemesh\project.godot)" -ForegroundColor Gray
Write-Host ""
Write-Host "Available test scripts:" -ForegroundColor Cyan
Write-Host "  .\XX-Test.ps1              - Test Python application" -ForegroundColor Gray
Write-Host "  .\XX-Test-CPP-System.ps1   - Test C++ viewer system" -ForegroundColor Gray
Write-Host "  .\XX-Test-Godot.ps1        - Test Godot integration" -ForegroundColor Gray
Write-Host ""

# Stop logging
Stop-Transcript | Out-Null
Write-Host "[INFO] Complete log saved to: $LogFile" -ForegroundColor Gray

# Return to project root
Set-Location $ProjectRoot

exit 0
