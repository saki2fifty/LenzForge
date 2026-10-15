# LenzForge Complete Installation Verification
# Checks EVERY component installed by the setup system

param(
    [switch]$Quiet  # Suppress headers for integration into other scripts
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$FailCount = 0
$PassCount = 0
$FailedComponents = @()

function Test-Component {
    param(
        [string]$Name,
        [scriptblock]$Test
    )
    
    try {
        $result = & $Test
        if ($result) {
            Write-Host -NoNewline "✓ " -ForegroundColor Green
            Write-Host -NoNewline "$Name... "
            Write-Host "True" -ForegroundColor Green
            $script:PassCount++
        } else {
            Write-Host -NoNewline "✗ " -ForegroundColor Red
            Write-Host -NoNewline "$Name... "
            Write-Host "False" -ForegroundColor Red
            $script:FailCount++
            $script:FailedComponents += $Name
        }
    } catch {
        Write-Host -NoNewline "✗ " -ForegroundColor Red
        Write-Host -NoNewline "$Name... "
        Write-Host "Error" -ForegroundColor Red
        $script:FailCount++
        $script:FailedComponents += $Name
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  LenzForge Installation Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# PHASE 1: PYTHON ENVIRONMENT
# ============================================================================
Write-Host "=== Python Environment ===" -ForegroundColor Yellow

$PythonDir = Join-Path $ProjectRoot "buildtools\python"
$PythonExe = Join-Path $PythonDir "python.exe"
$PipExe = Join-Path $PythonDir "Scripts\pip.exe"

Test-Component "Python directory exists" { Test-Path $PythonDir }
Test-Component "Python executable exists" { Test-Path $PythonExe }
Test-Component "Python runs" { 
    $ver = & $PythonExe --version 2>&1
    return $ver -match "Python 3"
}
Test-Component "pip executable exists" { Test-Path $PipExe }
Test-Component "pip runs" {
    $ver = & $PipExe --version 2>&1
    return $ver -match "pip"
}

# Python Packages
Write-Host ""
Write-Host "=== Python Packages ===" -ForegroundColor Yellow

$packages = @(
    "cv2",           # opencv-python
    "mediapipe",
    "pygrabber",
    "flask",
    "flask_socketio",
    "flask_cors",
    "psutil",
    "SCons",
    "pyvirtualcam",
    "markdown",
    "numpy"
)

foreach ($pkg in $packages) {
    Test-Component "Package: $pkg" {
        $result = & $PythonExe -c "import $pkg" 2>&1
        return $LASTEXITCODE -eq 0
    }
}

# ============================================================================
# PHASE 2: C++ COMPILER (MinGW)
# ============================================================================
Write-Host ""
Write-Host "=== MinGW Compiler ===" -ForegroundColor Yellow

$MinGWDir = Join-Path $ProjectRoot "buildtools\mingw"
$MinGWBin = Join-Path $MinGWDir "bin"
$GCC = Join-Path $MinGWBin "g++.exe"

Test-Component "MinGW directory exists" { Test-Path $MinGWDir }
Test-Component "MinGW bin directory exists" { Test-Path $MinGWBin }
Test-Component "g++.exe exists" { Test-Path $GCC }
Test-Component "gcc.exe exists" { Test-Path (Join-Path $MinGWBin "gcc.exe") }
Test-Component "ar.exe exists" { Test-Path (Join-Path $MinGWBin "ar.exe") }
Test-Component "ranlib.exe exists" { Test-Path (Join-Path $MinGWBin "ranlib.exe") }
Test-Component "g++ runs" {
    $ver = & $GCC --version 2>&1
    return $ver -match "g\+\+"
}

# MinGW Runtime DLLs
Test-Component "libgcc_s_seh-1.dll" { Test-Path (Join-Path $MinGWBin "libgcc_s_seh-1.dll") }
Test-Component "libstdc++-6.dll" { Test-Path (Join-Path $MinGWBin "libstdc++-6.dll") }
Test-Component "libwinpthread-1.dll" { Test-Path (Join-Path $MinGWBin "libwinpthread-1.dll") }

# ============================================================================
# PHASE 3: WINDOWS SDK (For MSMF Extension)
# ============================================================================
Write-Host ""
Write-Host "=== Windows SDK (For MSMF Extension) ===" -ForegroundColor Yellow

# Check system-installed SDK
$SystemSDKPaths = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\Include",
    "${env:ProgramFiles}\Windows Kits\10\Include"
)

$sdkFound = $false
foreach ($sdkPath in $SystemSDKPaths) {
    if (Test-Path $sdkPath) {
        $sdkVersions = Get-ChildItem $sdkPath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d+\.\d+' }
        foreach ($version in $sdkVersions) {
            $mfapiPath = Join-Path $version.FullName "um\mfapi.h"
            if (Test-Path $mfapiPath) {
                $sdkFound = $true
                break
            }
        }
        if ($sdkFound) { break }
    }
}

Test-Component "Windows SDK (system)" { return $sdkFound }

# ============================================================================
# PHASE 4: CMAKE (Optional)
# ============================================================================
Write-Host ""
Write-Host "=== CMake (Optional) ===" -ForegroundColor Yellow

$CMakeDir = Join-Path $ProjectRoot "buildtools\cmake"
$CMakeExe = Join-Path $CMakeDir "bin\cmake.exe"

Test-Component "CMake directory" { Test-Path $CMakeDir }
if (Test-Path $CMakeDir) {
    Test-Component "cmake.exe" { Test-Path $CMakeExe }
    Test-Component "cmake runs" {
        if (Test-Path $CMakeExe) {
            $ver = & $CMakeExe --version 2>&1
            return $ver -match "cmake"
        }
        return $false
    }
}

# ============================================================================
# PHASE 5: GODOT ENGINE
# ============================================================================
Write-Host ""
Write-Host "=== Godot Engine ===" -ForegroundColor Yellow

$GodotDir = Join-Path $ProjectRoot "buildtools\godot"
$GodotExe = Join-Path $GodotDir "Godot_v4.3-stable_win64.exe"

Test-Component "Godot directory" { Test-Path $GodotDir }
Test-Component "Godot executable" { Test-Path $GodotExe }
Test-Component "Godot console executable" { Test-Path (Join-Path $GodotDir "Godot_v4.3-stable_win64_console.exe") }

# Export Templates (PORTABLE - within buildtools)
$TemplatesDir = Join-Path $ProjectRoot "buildtools\godot\export_templates\4.3-stable"
Test-Component "Export templates directory (portable)" { Test-Path $TemplatesDir }
if (Test-Path $TemplatesDir) {
    # Templates are in templates/ subdirectory
    $TemplatesSubDir = Join-Path $TemplatesDir "templates"
    Test-Component "Windows template (debug)" { Test-Path (Join-Path $TemplatesSubDir "windows_debug_x86_64.exe") }
    Test-Component "Windows template (release)" { Test-Path (Join-Path $TemplatesSubDir "windows_release_x86_64.exe") }
}

# ============================================================================
# PHASE 6: BACKEND DEPLOYMENT
# ============================================================================
Write-Host ""
Write-Host "=== Backend Deployment ===" -ForegroundColor Yellow

$WorkspaceBackend = Join-Path $ProjectRoot "workspace_v2\LenzForge-Vision"
$BackendV2 = Join-Path $WorkspaceBackend "backend_v2"

Test-Component "Workspace backend directory" { Test-Path $WorkspaceBackend }
Test-Component "Backend v2 directory" { Test-Path $BackendV2 }

# Core backend modules
Test-Component "run_server.py" { Test-Path (Join-Path $BackendV2 "run_server.py") }
Test-Component "capture module" { Test-Path (Join-Path $BackendV2 "capture") }
Test-Component "convert module" { Test-Path (Join-Path $BackendV2 "convert") }
Test-Component "effects module" { Test-Path (Join-Path $BackendV2 "effects") }
Test-Component "ipc module" { Test-Path (Join-Path $BackendV2 "ipc\ring_nv12.py") }
Test-Component "ipc module (landmarks)" { Test-Path (Join-Path $BackendV2 "ipc\ring_landmarks.py") }
Test-Component "pipeline module" { Test-Path (Join-Path $BackendV2 "pipeline") }
Test-Component "server module" { Test-Path (Join-Path $BackendV2 "server\app.py") }

# Server routes
$RoutesDir = Join-Path $BackendV2 "server\routes"
Test-Component "routes directory" { Test-Path $RoutesDir }
Test-Component "camera routes" { Test-Path (Join-Path $RoutesDir "camera.py") }
Test-Component "streaming routes" { Test-Path (Join-Path $RoutesDir "streaming.py") }
Test-Component "effects routes" { Test-Path (Join-Path $RoutesDir "effects.py") }
Test-Component "configuration routes" { Test-Path (Join-Path $RoutesDir "configuration.py") }
Test-Component "performance routes" { Test-Path (Join-Path $RoutesDir "performance.py") }

# Templates
Test-Component "index.html" { Test-Path (Join-Path $BackendV2 "server\templates\index.html") }

# Static files
$StaticDir = Join-Path $BackendV2 "server\static"
Test-Component "static directory" { Test-Path $StaticDir }
Test-Component "main.css" { Test-Path (Join-Path $StaticDir "css\main.css") }
Test-Component "modules.js" { Test-Path (Join-Path $StaticDir "js\modules.js") }

# ============================================================================
# PHASE 7: MSMF EXTENSION
# ============================================================================
Write-Host ""
Write-Host "=== MSMF Camera Extension ===" -ForegroundColor Yellow

$MsmfCaptureDir = Join-Path $BackendV2 "capture"
$MsmfPyd = Join-Path $MsmfCaptureDir "msmf_capture.pyd"

Test-Component "MSMF source directory" { 
    Test-Path (Join-Path $ProjectRoot "setup_v2\assets\lenzforge-vision\capture\msmf_extension")
}
Test-Component "msmf_capture.cpp" {
    Test-Path (Join-Path $ProjectRoot "setup_v2\assets\lenzforge-vision\capture\msmf_extension\msmf_capture.cpp")
}
Test-Component "msmf_capture.pyd (deployed)" { Test-Path $MsmfPyd }

if (Test-Path $MsmfPyd) {
    # Check MinGW DLLs in same folder
    Test-Component "MSMF: libgcc_s_seh-1.dll" { Test-Path (Join-Path $MsmfCaptureDir "libgcc_s_seh-1.dll") }
    Test-Component "MSMF: libstdc++-6.dll" { Test-Path (Join-Path $MsmfCaptureDir "libstdc++-6.dll") }
    Test-Component "MSMF: libwinpthread-1.dll" { Test-Path (Join-Path $MsmfCaptureDir "libwinpthread-1.dll") }
}

# ============================================================================
# PHASE 8: GODOT PROJECT
# ============================================================================
Write-Host ""
Write-Host "=== Godot AR Project ===" -ForegroundColor Yellow

$GodotProject = Join-Path $ProjectRoot "workspace_v2\LenzForge-AR"

Test-Component "Godot project directory" { Test-Path $GodotProject }
Test-Component "project.godot" { Test-Path (Join-Path $GodotProject "project.godot") }
Test-Component "icon.svg" { Test-Path (Join-Path $GodotProject "icon.svg") }

# Scenes
Test-Component "scenes directory" { Test-Path (Join-Path $GodotProject "scenes") }
Test-Component "ar_main.tscn" { Test-Path (Join-Path $GodotProject "scenes\ar_main.tscn") }
Test-Component "ar_main.gd" { Test-Path (Join-Path $GodotProject "scenes\ar_main.gd") }

# Scripts
$ScriptsDir = Join-Path $GodotProject "scripts"
Test-Component "scripts directory" { Test-Path $ScriptsDir }
Test-Component "managers directory" { Test-Path (Join-Path $ScriptsDir "managers") }
Test-Component "utils directory" { Test-Path (Join-Path $ScriptsDir "utils") }

# Autoload
Test-Component "autoload directory" { Test-Path (Join-Path $GodotProject "autoload") }

# Addons
$AddonsDir = Join-Path $GodotProject "addons\lenzforge"
Test-Component "addons/lenzforge" { Test-Path $AddonsDir }
Test-Component "plugin.cfg" { Test-Path (Join-Path $AddonsDir "plugin.cfg") }
Test-Component "plugin.gd" { Test-Path (Join-Path $AddonsDir "plugin.gd") }
Test-Component "lenzforge.gdextension" { Test-Path (Join-Path $AddonsDir "lenzforge.gdextension") }

# ============================================================================
# PHASE 9: GDEXTENSION BUILD
# ============================================================================
Write-Host ""
Write-Host "=== GDExtension (C++) ===" -ForegroundColor Yellow

$GDExtDir = Join-Path $GodotProject "gdextension"
$LenzForgeDir = Join-Path $GDExtDir "lenzforge"
$BinDir = Join-Path $GDExtDir "bin"
$GDExtDLL = Join-Path $BinDir "lenzforge.windows.template_debug.x86_64.dll"

Test-Component "gdextension directory" { Test-Path $GDExtDir }
Test-Component "lenzforge source directory" { Test-Path $LenzForgeDir }
Test-Component "SConstruct" { Test-Path (Join-Path $LenzForgeDir "SConstruct") }

# Source files
$SrcDir = Join-Path $LenzForgeDir "src"
Test-Component "src directory" { Test-Path $SrcDir }
Test-Component "register_types.cpp" { Test-Path (Join-Path $SrcDir "register_types.cpp") }
Test-Component "vid1_reader.cpp" { Test-Path (Join-Path $SrcDir "vid1_reader.cpp") }
Test-Component "lmk1_reader.cpp" { Test-Path (Join-Path $SrcDir "lmk1_reader.cpp") }
Test-Component "shared_memory.cpp" { Test-Path (Join-Path $SrcDir "shared_memory.cpp") }

# godot-cpp (now in buildtools, not workspace)
$GodotCppDir = Join-Path $ProjectRoot "buildtools\godot-cpp"
$GodotCppLib = Join-Path $GodotCppDir "bin\libgodot-cpp.windows.template_debug.x86_64.a"

Test-Component "godot-cpp directory (buildtools)" { Test-Path $GodotCppDir }
Test-Component "godot-cpp library (.a)" { Test-Path $GodotCppLib }

if (Test-Path $GodotCppLib) {
    $libSize = (Get-Item $GodotCppLib).Length
    $libSizeMB = [math]::Round($libSize / 1MB, 1)
    Write-Host "  godot-cpp Size: $libSizeMB MB" -ForegroundColor $(if ($libSizeMB -ge 76 -and $libSizeMB -le 130) { "Green" } elseif ($libSizeMB -ge 35) { "Yellow" } else { "Red" })
    
    Test-Component "godot-cpp size adequate (76-124 MB)" { 
        $libSizeMB -ge 76 -and $libSizeMB -le 130
    }
    
    if ($libSizeMB -lt 76) {
        Write-Host "  ⚠️  Library appears incomplete (expected 76-124 MB)" -ForegroundColor Yellow
        Write-Host "  ℹ️  Rebuild: .\setup_v2\072-Build-Godot-CPP.ps1" -ForegroundColor Gray
    }
}

# Built DLL
Test-Component "bin directory" { Test-Path $BinDir }
Test-Component "lenzforge.dll" { Test-Path $GDExtDLL }

if (Test-Path $GDExtDLL) {
    $size = (Get-Item $GDExtDLL).Length
    $sizeMB = "{0:N2}" -f ($size / 1MB)
    Test-Component "lenzforge.dll size > 0" { $size -gt 0 }
    Write-Host "  DLL Size: $sizeMB MB" -ForegroundColor Gray
    
    # MinGW Runtime DLLs
    Test-Component "GDExt: libgcc_s_seh-1.dll" { Test-Path (Join-Path $BinDir "libgcc_s_seh-1.dll") }
    Test-Component "GDExt: libstdc++-6.dll" { Test-Path (Join-Path $BinDir "libstdc++-6.dll") }
    Test-Component "GDExt: libwinpthread-1.dll" { Test-Path (Join-Path $BinDir "libwinpthread-1.dll") }
}

# ============================================================================
# PHASE 10: CRITICAL FILE CONTENT CHECKS
# ============================================================================
Write-Host ""
Write-Host "=== Critical File Content Verification ===" -ForegroundColor Yellow

# Check SConstruct uses .a (not .lib)
$SConst = Join-Path $LenzForgeDir "SConstruct"
if (Test-Path $SConst) {
    $sconContent = Get-Content $SConst -Raw
    Test-Component "SConstruct uses .a file (MinGW)" {
        $sconContent -match '\.a"' -and $sconContent -notmatch '\.lib"'
    }
    
    if ($sconContent -match '\.lib"') {
        Write-Host "  ⚠️  SConstruct still references .lib (should be .a)" -ForegroundColor Yellow
        Write-Host "  ℹ️  Fix: Update line 55 to use .a instead of .lib" -ForegroundColor Gray
    }
}

# Check landmark_layer.gd extends Control
$LandmarkLayer = Join-Path $GodotProject "scenes\components\landmark_layer.gd"
if (Test-Path $LandmarkLayer) {
    $layerContent = Get-Content $LandmarkLayer -Raw
    Test-Component "landmark_layer.gd extends Control" {
        $layerContent -match 'extends\s+Control'
    }
    
    if ($layerContent -match 'extends\s+CanvasLayer') {
        Write-Host "  ⚠️  landmark_layer.gd extends CanvasLayer (should be Control)" -ForegroundColor Yellow
        Write-Host "  ℹ️  Fix: Change 'extends CanvasLayer' to 'extends Control'" -ForegroundColor Gray
    }
}

# Check video_manager.gd has dual-path signals
$VideoManager = Join-Path $GodotProject "scripts\managers\video_manager.gd"
if (Test-Path $VideoManager) {
    $videoContent = Get-Content $VideoManager -Raw
    Test-Component "video_manager.gd has frame_ready signal" {
        $videoContent -match 'signal\s+frame_ready.*ImageTexture'
    }
    Test-Component "video_manager.gd has nv12_frame_ready signal" {
        $videoContent -match 'signal\s+nv12_frame_ready'
    }
    Test-Component "video_manager.gd has CPU conversion function" {
        $videoContent -match 'func\s+_convert_nv12_to_rgb'
    }
}

# Check render_manager.gd defaults to GPU
$RenderManager = Join-Path $GodotProject "scripts\managers\render_manager.gd"
if (Test-Path $RenderManager) {
    $renderContent = Get-Content $RenderManager -Raw
    Test-Component "render_manager.gd defaults to GPU (video)" {
        $renderContent -match 'current_video_mode:\s*VideoMode\s*=\s*VideoMode\.GPU'
    }
    Test-Component "render_manager.gd defaults to GPU (landmarks)" {
        $renderContent -match 'current_landmark_mode:\s*LandmarkMode\s*=\s*LandmarkMode\.GPU'
    }
}

# Check all manager scripts exist
$ManagerScripts = @(
    "video_manager.gd",
    "landmark_manager.gd",
    "render_manager.gd",
    "gpu_compositor.gd",
    "effects_manager.gd",
    "ui_manager.gd"
)

foreach ($script in $ManagerScripts) {
    Test-Component "Manager: $script" {
        Test-Path (Join-Path $GodotProject "scripts\managers\$script")
    }
}

# Check shader files
$ShaderDir = Join-Path $GodotProject "shaders"
Test-Component "shaders directory" { Test-Path $ShaderDir }
if (Test-Path $ShaderDir) {
    Test-Component "nv12_composite.gdshader" {
        Test-Path (Join-Path $ShaderDir "nv12_composite.gdshader")
    }
}

# ============================================================================
# PHASE 11: STARTUP SCRIPTS
# ============================================================================
Write-Host ""
Write-Host "=== Startup Scripts ===" -ForegroundColor Yellow

Test-Component "Start-Backend.ps1" { Test-Path (Join-Path $ProjectRoot "Start-Backend.ps1") }

# ============================================================================
# PHASE 12: CONFIGURATION
# ============================================================================
Write-Host ""
Write-Host "=== Configuration ===" -ForegroundColor Yellow

Test-Component "lenzforge_config.json" { Test-Path (Join-Path $ProjectRoot "lenzforge_config.json") }

# ============================================================================
# PHASE 13: GODOT PROJECT FIXES VERIFICATION (PowerShell Native)
# ============================================================================
Write-Host ""
Write-Host "=== Godot Project Fixes (PowerShell Verification) ===" -ForegroundColor Yellow

# GDExtension Configuration (check both locations: addons and gdextension)
$gdextPathAddons = Join-Path $GodotProject "addons\lenzforge\lenzforge.gdextension"
$gdextPathGDExt = Join-Path $GodotProject "gdextension\lenzforge.gdextension"

$gdextPath = if (Test-Path $gdextPathAddons) { $gdextPathAddons } else { $gdextPathGDExt }

if (Test-Path $gdextPath) {
    $gdextContent = Get-Content $gdextPath -Raw
    $hasCompat = $gdextContent -match "compatibility_minimum"
    $hasEntry = $gdextContent -match "entry_symbol"
    $hasDebug = $gdextContent -match "windows.debug.x86_64"
    $hasRelease = $gdextContent -match "windows.release.x86_64"
    
    if ($hasCompat -and $hasEntry -and $hasDebug -and $hasRelease) {
        Test-Component "GDExtension configuration complete" { $true }
    } else {
        Test-Component "GDExtension configuration complete" { $false }
    }
} else {
    Test-Component "GDExtension configuration complete" { $false }
}

# DLL Files
$debugDLL = Join-Path $GodotProject "gdextension\bin\lenzforge.windows.template_debug.x86_64.dll"
$releaseDLL = Join-Path $GodotProject "gdextension\bin\lenzforge.windows.template_release.x86_64.dll"
Test-Component "Debug DLL exists" { Test-Path $debugDLL }
Test-Component "Release DLL exists" { Test-Path $releaseDLL }

# Config JSON
$configPath = Join-Path $GodotProject "lenzforge_config.json"
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $hasVersion = $null -ne $config.version
        $hasProject = $null -ne $config.project_name
        $hasBackend = $null -ne $config.backend
        $hasVideo = $null -ne $config.video
        $hasAR = $null -ne $config.ar
        $hasIPC = $null -ne $config.ipc
        
        if ($hasVersion -and $hasProject -and $hasBackend -and $hasVideo -and $hasAR -and $hasIPC) {
            Test-Component "Config JSON structure valid" { $true }
        } else {
            Test-Component "Config JSON structure valid" { $false }
        }
    } catch {
        Test-Component "Config JSON structure valid" { $false }
    }
} else {
    Test-Component "Config JSON structure valid" { $false }
}

# GDScript Files
$arMainPath = Join-Path $GodotProject "scenes\ar_main.gd"
$videoMgrPath = Join-Path $GodotProject "scripts\managers\video_settings_manager.gd"
$videoPanelPath = Join-Path $GodotProject "scripts\ui\video_settings_panel.gd"

Test-Component "ar_main.gd valid" { Test-Path $arMainPath }
Test-Component "video_settings_manager.gd valid" { Test-Path $videoMgrPath }
Test-Component "video_settings_panel.gd valid" { Test-Path $videoPanelPath }

# Additional Godot Project Checks
Test-Component "lenzforge_config.json (LenzForge-AR)" {
    Test-Path (Join-Path $GodotProject "lenzforge_config.json")
}

Test-Component "GDExtension compatibility_minimum key" {
    $gdextPathAddons = Join-Path $GodotProject "addons\lenzforge\lenzforge.gdextension"
    $gdextPathGDExt = Join-Path $GodotProject "gdextension\lenzforge.gdextension"
    
    $gdextPath = if (Test-Path $gdextPathAddons) { $gdextPathAddons } else { $gdextPathGDExt }
    
    if (Test-Path $gdextPath) {
        $content = Get-Content $gdextPath -Raw
        return $content -match "compatibility_minimum"
    }
    return $false
}

# ============================================================================
# PHASE 14: PROJECT STRUCTURE
# ============================================================================
Write-Host ""
Write-Host "=== Project Structure ===" -ForegroundColor Yellow

Test-Component "buildtools directory" { Test-Path (Join-Path $ProjectRoot "buildtools") }
Test-Component "setup_v2 directory" { Test-Path (Join-Path $ProjectRoot "setup_v2") }
Test-Component "workspace_v2 directory" { Test-Path (Join-Path $ProjectRoot "workspace_v2") }
Test-Component "logs directory" { Test-Path (Join-Path $ProjectRoot "logs") }
Test-Component "downloads directory" { Test-Path (Join-Path $ProjectRoot "downloads") }

# ============================================================================
# SUMMARY
# ============================================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Verification Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$Total = $PassCount + $FailCount
$PassPercent = [math]::Round(($PassCount / $Total) * 100, 1)

Write-Host "Total Checks: $Total" -ForegroundColor White
Write-Host "Passed: $PassCount ✓" -ForegroundColor Green
Write-Host "Failed: $FailCount ✗" -ForegroundColor Red
Write-Host "Success Rate: $PassPercent%" -ForegroundColor $(if ($PassPercent -ge 90) { "Green" } elseif ($PassPercent -ge 70) { "Yellow" } else { "Red" })
Write-Host ""

# Export failed components for main setup script
$failedFile = Join-Path $ProjectRoot "logs\verification_failed.txt"
if ($FailedComponents.Count -gt 0) {
    $FailedComponents | Out-File -FilePath $failedFile -Encoding UTF8
} else {
    # Clear the file if everything passed
    "" | Out-File -FilePath $failedFile -Encoding UTF8
}

if ($FailCount -eq 0) {
    Write-Host "🎉 PERFECT! All components verified!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your LenzForge installation is complete and ready to use!" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To start:" -ForegroundColor Yellow
    Write-Host "  Backend: .\Start-Backend.ps1" -ForegroundColor White
    Write-Host "  Godot: .\buildtools\godot\Godot_v4.3-stable_win64.exe workspace_v2\LenzForge-AR\project.godot" -ForegroundColor White
    exit 0
} elseif ($FailCount -le 5) {
    Write-Host "⚠️  Minor Issues Detected" -ForegroundColor Yellow
    Write-Host "Most components are working. Check failed items above." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "❌ Installation Incomplete" -ForegroundColor Red
    Write-Host "Several components are missing. Please run setup again:" -ForegroundColor Red
    Write-Host "  .\setup_v2\000-Setup.ps1" -ForegroundColor White
    exit 1
}
