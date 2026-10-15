# Build Godot-CPP Library
# Part of LenzForge setup system

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Build Godot-CPP Library" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$GodotCppPath = Join-Path $ProjectRoot "buildtools\godot-cpp"
$MinGWBin = Join-Path $ProjectRoot "buildtools\mingw\bin"
$PythonScripts = Join-Path $ProjectRoot "buildtools\python\Scripts"
$SconsExe = Join-Path $PythonScripts "scons.exe"

# Check if godot-cpp exists
if (-not (Test-Path $GodotCppPath)) {
    Write-Host "[ERROR] Godot-CPP not found at: $GodotCppPath" -ForegroundColor Red
    Write-Host "[INFO] Please run: .\071-Extract-Godot-CPP.ps1" -ForegroundColor Yellow
    exit 1
}

# Check if already built (both debug and release)
$DebugLib = Join-Path $GodotCppPath "bin\libgodot-cpp.windows.template_debug.x86_64.a"
$ReleaseLib = Join-Path $GodotCppPath "bin\libgodot-cpp.windows.template_release.x86_64.a"

$debugExists = Test-Path $DebugLib
$releaseExists = Test-Path $ReleaseLib

if ($debugExists -and $releaseExists) {
    Write-Host "[INFO] Godot-CPP already built (DEBUG + RELEASE)" -ForegroundColor Green
    $debugSize = (Get-Item $DebugLib).Length
    $releaseSize = (Get-Item $ReleaseLib).Length
    Write-Host "[INFO] Debug library: $("{0:N1} MB" -f ($debugSize / 1MB))" -ForegroundColor Gray
    Write-Host "[INFO] Release library: $("{0:N1} MB" -f ($releaseSize / 1MB))" -ForegroundColor Gray
    exit 0
}

# Check for MinGW
if (-not (Test-Path "$MinGWBin\g++.exe")) {
    Write-Host "[ERROR] MinGW compiler not found!" -ForegroundColor Red
    Write-Host "[INFO] Please run setup scripts 010-011 to install MinGW" -ForegroundColor Yellow
    exit 1
}

# Check for SCons
if (-not (Test-Path $SconsExe)) {
    Write-Host "[INFO] Installing SCons..." -ForegroundColor Yellow
    $PythonExe = Join-Path $ProjectRoot "buildtools\python\python.exe"
    & $PythonExe -m pip install scons
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to install SCons" -ForegroundColor Red
        exit 1
    }
}

Write-Host "[INFO] Building Godot-CPP library..." -ForegroundColor Cyan
Write-Host "[INFO] Source: $GodotCppPath" -ForegroundColor Gray
Write-Host "[INFO] This will take 5-10 minutes (compiling 900+ files)..." -ForegroundColor Yellow
Write-Host ""

# Add MinGW to PATH
$env:PATH = "$MinGWBin;$env:PATH"

# Verify compiler
try {
    $gccVersion = & "$MinGWBin\g++.exe" --version 2>&1 | Select-Object -First 1
    Write-Host "[OK] GCC: $gccVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] GCC not accessible" -ForegroundColor Red
    exit 1
}

# Change to godot-cpp directory
Push-Location $GodotCppPath

try {
    Write-Host "[INFO] Starting SCons build with MinGW toolchain..." -ForegroundColor Cyan
    Write-Host "[INFO] Forcing MinGW to prevent MSVC detection..." -ForegroundColor Gray
    Write-Host ""
    
    # CRITICAL: Force MinGW toolchain explicitly
    # This prevents SCons from auto-detecting MSVC if installed
    $env:CC = Join-Path $MinGWBin "gcc.exe"
    $env:CXX = Join-Path $MinGWBin "g++.exe"
    $env:AR = Join-Path $MinGWBin "ar.exe"
    $env:LINK = Join-Path $MinGWBin "g++.exe"
    
    Write-Host "[OK] CC: $env:CC" -ForegroundColor Green
    Write-Host "[OK] CXX: $env:CXX" -ForegroundColor Green
    Write-Host ""
    
    # Build DEBUG version if missing
    if (-not $debugExists) {
        Write-Host "[INFO] Building DEBUG library (5-10 minutes)..." -ForegroundColor Cyan
        $process = Start-Process -FilePath $SconsExe `
            -ArgumentList "platform=windows", "target=template_debug", "use_mingw=yes", "-j4" `
            -NoNewWindow -PassThru -Wait
        
        if ($process.ExitCode -ne 0) {
            Write-Host "[ERROR] DEBUG build failed" -ForegroundColor Red
            Pop-Location
            exit 1
        }
        
        if (Test-Path $DebugLib) {
            $size = (Get-Item $DebugLib).Length
            Write-Host "[OK] DEBUG library: $("{0:N1} MB" -f ($size / 1MB))" -ForegroundColor Green
        }
    } else {
        Write-Host "[OK] DEBUG library already exists" -ForegroundColor Green
    }
    
    Write-Host ""
    
    # Build RELEASE version if missing
    if (-not $releaseExists) {
        Write-Host "[INFO] Building RELEASE library (5-10 minutes)..." -ForegroundColor Cyan
        $process = Start-Process -FilePath $SconsExe `
            -ArgumentList "platform=windows", "target=template_release", "use_mingw=yes", "-j4" `
            -NoNewWindow -PassThru -Wait
        
        if ($process.ExitCode -ne 0) {
            Write-Host "[ERROR] RELEASE build failed" -ForegroundColor Red
            Pop-Location
            exit 1
        }
        
        if (Test-Path $ReleaseLib) {
            $size = (Get-Item $ReleaseLib).Length
            Write-Host "[OK] RELEASE library: $("{0:N1} MB" -f ($size / 1MB))" -ForegroundColor Green
        }
    } else {
        Write-Host "[OK] RELEASE library already exists" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "[SUCCESS] Godot-CPP library built successfully (DEBUG + RELEASE)!" -ForegroundColor Green
    Write-Host "[INFO] Location: buildtools\godot-cpp\bin\" -ForegroundColor Cyan
} catch {
    Write-Host ""
    Write-Host "[ERROR] Build failed: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}

Pop-Location

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Godot-CPP Library Built" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

exit 0
