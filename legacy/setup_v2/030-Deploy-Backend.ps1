$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deploying Python Backend" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$SourceDir = Join-Path $ProjectRoot "setup\assets\backend"
$SourceDirV2 = Join-Path $ProjectRoot "setup_v2\assets\lenzforge-vision"
$TargetDir = Join-Path $ProjectRoot "workspace_v2\LenzForge-Vision"
$ConfigTarget = Join-Path $ProjectRoot "lenzforge_config.json"

# Check if old backend exists (backward compatibility)
if (-not (Test-Path $SourceDir)) {
    Write-Host "[WARNING] Old backend not found at: $SourceDir" -ForegroundColor Yellow
    Write-Host "[INFO] This is expected if using setup_v2 only" -ForegroundColor Gray
    $SourceDir = $null
}

Write-Host "[INFO] Creating target directory..." -ForegroundColor Yellow
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

# Copy old backend files if they exist (backward compatibility)
if ($SourceDir -ne $null) {
    Write-Host "[INFO] Copying old backend files..." -ForegroundColor Yellow
    
    # Copy backend_server.py
    $SourceFile = Join-Path $SourceDir "backend_server.py"
    $TargetFile = Join-Path $TargetDir "backend_server.py"

    if (Test-Path $SourceFile) {
        Copy-Item $SourceFile $TargetFile -Force
        Write-Host "[OK] Deployed: backend_server.py" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] backend_server.py not found" -ForegroundColor Yellow
    }

    # Copy backend_server_gui_flask.py (main Flask backend)
    $SourceFileFlask = Join-Path $SourceDir "backend_server_gui_flask.py"
    $TargetFileFlask = Join-Path $TargetDir "backend_server_gui_flask.py"

    if (Test-Path $SourceFileFlask) {
        Copy-Item $SourceFileFlask $TargetFileFlask -Force
        Write-Host "[OK] Deployed: backend_server_gui_flask.py" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] backend_server_gui_flask.py not found" -ForegroundColor Yellow
    }

    # Copy templates directory
    $SourceTemplates = Join-Path $SourceDir "templates"
    $TargetTemplates = Join-Path $TargetDir "templates"

    if (Test-Path $SourceTemplates) {
        if (-not (Test-Path $TargetTemplates)) {
            New-Item -ItemType Directory -Path $TargetTemplates -Force | Out-Null
        }
        Copy-Item "$SourceTemplates\*" $TargetTemplates -Force
        Write-Host "[OK] Deployed: templates/" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] templates/ not found" -ForegroundColor Yellow
    }

    # Copy virtual_camera.py
    $SourceFileVCam = Join-Path $SourceDir "virtual_camera.py"
    $TargetFileVCam = Join-Path $TargetDir "virtual_camera.py"

    if (Test-Path $SourceFileVCam) {
        Copy-Item $SourceFileVCam $TargetFileVCam -Force
        Write-Host "[OK] Deployed: virtual_camera.py" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] virtual_camera.py not found" -ForegroundColor Yellow
    }
} else {
    Write-Host "[INFO] Skipping old backend files (not found)" -ForegroundColor Gray
}

# Copy backend_v2 directory (new modular backend)
$SourceBackendV2 = $SourceDirV2
$TargetBackendV2 = Join-Path $TargetDir "backend_v2"

# Fallback to old path if new path doesn't exist
if (-not (Test-Path $SourceBackendV2)) {
    $SourceBackendV2 = Join-Path $ProjectRoot "setup\assets\lenzforge-vision"
}

if (Test-Path $SourceBackendV2) {
    Write-Host "[INFO] Deploying backend_v2 (modular architecture)..." -ForegroundColor Yellow
    
    # Remove old backend_v2 if exists
    if (Test-Path $TargetBackendV2) {
        Remove-Item -Path $TargetBackendV2 -Recurse -Force
    }
    
    # Copy entire backend_v2 directory structure
    Copy-Item $SourceBackendV2 $TargetBackendV2 -Recurse -Force
    Write-Host "[OK] Deployed: backend_v2/ (complete module structure)" -ForegroundColor Green
    
    # Copy MSMF extension if it was built
    Write-Host ""
    Write-Host "[INFO] Checking for built MSMF extension..." -ForegroundColor Cyan
    $MsmfSource = Join-Path $SourceBackendV2 "capture\msmf_extension"
    $MsmfTarget = Join-Path $TargetBackendV2 "capture"
    
    $pydFile = Get-ChildItem -Path $MsmfSource -Filter "msmf_capture*.pyd" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pydFile) {
        Copy-Item $pydFile.FullName (Join-Path $MsmfTarget "msmf_capture.pyd") -Force
        Write-Host "[OK] Deployed: msmf_capture.pyd" -ForegroundColor Green
        
        # Copy MinGW runtime DLLs from buildtools
        $MinGWBin = Join-Path $ProjectRoot "buildtools\mingw\bin"
        if (Test-Path $MinGWBin) {
            Write-Host "[INFO] Copying MinGW runtime DLLs..." -ForegroundColor Cyan
            $mingwDlls = @(
                "libgcc_s_seh-1.dll",
                "libstdc++-6.dll",
                "libwinpthread-1.dll"
            )
            
            foreach ($dll in $mingwDlls) {
                $sourceDll = Join-Path $MinGWBin $dll
                if (Test-Path $sourceDll) {
                    Copy-Item $sourceDll $MsmfTarget -Force
                    Write-Host "[OK] Deployed: $dll" -ForegroundColor Green
                } else {
                    Write-Host "[WARN] DLL not found: $dll" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "[WARN] MinGW not found - MSMF extension may not work" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[INFO] MSMF extension not built - system will use OpenCV fallback" -ForegroundColor Gray
    }
} else {
    Write-Host "[INFO] backend_v2 not found in either setup_v2 or setup" -ForegroundColor Gray
}

# Copy config file to project root (if old backend exists)
if ($SourceDir -ne $null) {
    $ConfigSource = Join-Path $SourceDir "lenzforge_config.json"

    if (Test-Path $ConfigSource) {
        if (Test-Path $ConfigTarget) {
            Write-Host "[INFO] Config file already exists at: $ConfigTarget" -ForegroundColor Yellow
            Write-Host "[INFO] Skipping to preserve existing settings" -ForegroundColor Yellow
        } else {
            Copy-Item $ConfigSource $ConfigTarget -Force
            Write-Host "[OK] Deployed: lenzforge_config.json" -ForegroundColor Green
        }
    } else {
        Write-Host "[WARNING] Config template not found: $ConfigSource" -ForegroundColor Yellow
    }
} else {
    Write-Host "[INFO] Skipping config file (old backend not found)" -ForegroundColor Gray
}

# Copy startup script to project root
Write-Host "[INFO] Copying startup script to project root..." -ForegroundColor Cyan
$StartScript = Join-Path $ScriptDir "XX-Start-Backend.ps1"
$TargetStartScript = Join-Path $ProjectRoot "Start-Backend.ps1"

if (Test-Path $StartScript) {
    Copy-Item $StartScript $TargetStartScript -Force
    Write-Host "[OK] Deployed: Start-Backend.ps1" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Startup script not found: $StartScript" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[SUCCESS] Backend deployed" -ForegroundColor Green
Write-Host "[INFO] Backend location: $TargetDir" -ForegroundColor Gray
Write-Host "[INFO] Config location: $ConfigTarget" -ForegroundColor Gray
Write-Host ""
Write-Host "To run backend:" -ForegroundColor Cyan
Write-Host "  .\Start-Backend.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Or manually:" -ForegroundColor Cyan
Write-Host "  .\buildtools\python\python.exe .\workspace_v2\LenzForge-Vision\backend_v2\run_server.py" -ForegroundColor Gray

exit 0
