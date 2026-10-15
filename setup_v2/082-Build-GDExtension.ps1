$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building GDExtension" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$CMakePath = Join-Path $ProjectRoot "buildtools\cmake\bin\cmake.exe"
$SourceDir = Join-Path $ProjectRoot "workspace_v2\godot-extension"
$BuildDir = Join-Path $SourceDir "build"

if (-not (Test-Path $CMakePath)) {
    Write-Host "[ERROR] CMake not found" -ForegroundColor Red
    Write-Host "[INFO] Please run 08-Download-CMake.ps1 and 10-Extract-CMake.ps1 first" -ForegroundColor Yellow
    exit 1
}

Write-Host "[INFO] CMake: $CMakePath" -ForegroundColor Gray
Write-Host "[INFO] Source: $SourceDir" -ForegroundColor Gray
Write-Host "[INFO] Build: $BuildDir" -ForegroundColor Gray
Write-Host ""

Write-Host "[INFO] Creating build directory..." -ForegroundColor Yellow
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
}

Set-Location $BuildDir

# Check for portable MinGW (preferred) or Visual Studio (fallback)
$MinGWPath = Join-Path $ProjectRoot "buildtools\mingw\bin"
$MinGWMake = Join-Path $MinGWPath "mingw32-make.exe"

$useMinGW = $false
if (Test-Path $MinGWMake) {
    Write-Host "[OK] Found portable MinGW at: $MinGWPath" -ForegroundColor Green
    $env:PATH = "$MinGWPath;$env:PATH"
    $useMinGW = $true
}

Write-Host "[INFO] Configuring with CMake..." -ForegroundColor Yellow

if ($useMinGW) {
    Write-Host "[INFO] Using MinGW Makefiles generator" -ForegroundColor Gray
    try {
        & $CMakePath -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release $SourceDir
        
        if ($LASTEXITCODE -ne 0) {
            throw "CMake configuration failed"
        }
        
        Write-Host "[SUCCESS] CMake configuration complete" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] CMake configuration failed: $_" -ForegroundColor Red
        Write-Host "[INFO] MinGW build failed" -ForegroundColor Yellow
        exit 1
    }
} else {
    # Fallback to Visual Studio
    try {
        & $CMakePath -G "Visual Studio 17 2022" -A x64 $SourceDir
        
        if ($LASTEXITCODE -ne 0) {
            throw "CMake configuration failed"
        }
        
        Write-Host "[SUCCESS] CMake configuration complete" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] CMake configuration failed: $_" -ForegroundColor Red
        Write-Host "[INFO] Trying Visual Studio 16 2019..." -ForegroundColor Yellow
        
        try {
            & $CMakePath -G "Visual Studio 16 2019" -A x64 $SourceDir
            
            if ($LASTEXITCODE -ne 0) {
                throw "CMake configuration failed with VS2019 too"
            }
            
            Write-Host "[SUCCESS] CMake configuration complete" -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] CMake configuration failed with VS2019 too" -ForegroundColor Red
            Write-Host "[INFO] You may need to install Visual Studio with C++ support or run setup scripts 010-011 for MinGW" -ForegroundColor Yellow
            exit 1
        }
    }
}

Write-Host ""
Write-Host "[INFO] Building extension..." -ForegroundColor Yellow
Write-Host "[INFO] This may take 5-10 minutes (first build compiles godot-cpp)..." -ForegroundColor Yellow

if ($useMinGW) {
    # Use MinGW make directly
    try {
        & $MinGWMake
        
        if ($LASTEXITCODE -ne 0) {
            throw "Build failed"
        }
        
        Write-Host "[SUCCESS] Build complete" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Build failed: $_" -ForegroundColor Red
        exit 1
    }
} else {
    # Use CMake build for Visual Studio
    try {
        & $CMakePath --build . --config Release
        
        if ($LASTEXITCODE -ne 0) {
            throw "Build failed"
        }
        
        Write-Host "[SUCCESS] Build complete" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Build failed: $_" -ForegroundColor Red
        exit 1
    }
}

$DllPath = Join-Path $SourceDir "bin\Release\LenzForge_video.dll"
if (Test-Path $DllPath) {
    Write-Host ""
    Write-Host "[SUCCESS] Extension DLL created" -ForegroundColor Green
    Write-Host "[INFO] Location: $DllPath" -ForegroundColor Gray
} else {
    Write-Host "[WARNING] Extension DLL not found at $DllPath" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[INFO] Installing to Godot project..." -ForegroundColor Yellow

$InstallScript = Join-Path $ScriptDir "21-Install-Extension-To-Godot.ps1"
if (Test-Path $InstallScript) {
    & $InstallScript
} else {
    Write-Host "[ERROR] Install script not found: $InstallScript" -ForegroundColor Red
    exit 1
}

exit 0
