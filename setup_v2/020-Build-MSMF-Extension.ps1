# Build MSMF Camera Capture Python Extension
# Part of LenzForge setup system

Write-Host "================================" -ForegroundColor Cyan
Write-Host "  Build MSMF Extension" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"
$extensionDir = "$PSScriptRoot\assets\lenzforge-vision\capture\msmf_extension"

# Check Python - USE SYSTEM PYTHON FOR BUILDING (has dev headers)
Write-Host "[INFO] Checking Python for C++ extension build..." -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# For building C++ extensions, we MUST use system Python (embeddable has no headers)
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Host "[ERROR] System Python not found!" -ForegroundColor Red
    Write-Host "[INFO] C++ extension build requires full Python installation (not embeddable)" -ForegroundColor Yellow
    Write-Host "[INFO] Please install Python from python.org" -ForegroundColor Yellow
    exit 1
}

$pythonExe = $python.Source
Write-Host "[OK] Using system Python for build: $pythonExe" -ForegroundColor Green
Write-Host "[INFO] Built extension will work with portable Python at runtime" -ForegroundColor Gray

# Check pybind11
Write-Host "[INFO] Checking pybind11..." -ForegroundColor Cyan
& $pythonExe -c "import pybind11" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] pybind11 not installed, installing..." -ForegroundColor Yellow
    & $pythonExe -m pip install pybind11
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to install pybind11!" -ForegroundColor Red
        exit 1
    }
}

Write-Host "[OK] pybind11 installed" -ForegroundColor Green

# Check for portable MinGW (preferred) or Visual Studio (fallback)
Write-Host "[INFO] Checking C++ compiler and Windows SDK..." -ForegroundColor Cyan
$MinGWPath = Join-Path $ProjectRoot "buildtools\mingw\bin"
$MinGWGCC = Join-Path $MinGWPath "g++.exe"

$compilerFound = $false
$usingMinGW = $false

# Check for portable MinGW first
if (Test-Path $MinGWGCC) {
    Write-Host "[OK] Found portable MinGW at: $MinGWPath" -ForegroundColor Green
    $env:PATH = "$MinGWPath;$env:PATH"
    $compilerFound = $true
    $usingMinGW = $true
} else {
    # Fallback to Visual Studio
    $vcvars = Get-Command cl.exe -ErrorAction SilentlyContinue
    if ($vcvars) {
        Write-Host "[OK] Using Visual Studio compiler" -ForegroundColor Green
        $compilerFound = $true
    } else {
        # Try to find Visual Studio
        $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        if (Test-Path $vswhere) {
            $vsPath = & $vswhere -latest -property installationPath
            if ($vsPath) {
                Write-Host "[OK] Found Visual Studio at: $vsPath" -ForegroundColor Green
                $compilerFound = $true
            }
        }
    }
}

if (-not $compilerFound) {
    Write-Host "[WARNING] No C++ compiler found!" -ForegroundColor Yellow
    Write-Host "[INFO] MSMF extension requires either:" -ForegroundColor Gray
    Write-Host "  - Portable MinGW (run setup scripts 010-011)" -ForegroundColor Gray
    Write-Host "  - Visual Studio Build Tools" -ForegroundColor Gray
    Write-Host "[INFO] System will use OpenCV fallback (still works!)" -ForegroundColor Yellow
    exit 1
}

# Check for Windows SDK (required for MSMF headers)
Write-Host "[INFO] Checking for Windows SDK..." -ForegroundColor Cyan
$sdkPaths = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\Include",
    "${env:ProgramFiles}\Windows Kits\10\Include"
)

$sdkFound = $false
foreach ($sdkPath in $sdkPaths) {
    if (Test-Path $sdkPath) {
        # Check for MSMF headers
        $sdkVersions = Get-ChildItem $sdkPath -Directory | Where-Object { $_.Name -match '^\d+\.\d+' }
        foreach ($version in $sdkVersions) {
            $mfapiPath = Join-Path $version.FullName "um\mfapi.h"
            if (Test-Path $mfapiPath) {
                Write-Host "[OK] Windows SDK found: $($version.Name)" -ForegroundColor Green
                $sdkFound = $true
                break
            }
        }
        if ($sdkFound) { break }
    }
}

if (-not $sdkFound) {
    Write-Host "[ERROR] Windows SDK with MSMF headers not found!" -ForegroundColor Red
    Write-Host "" -ForegroundColor Yellow
    Write-Host "The MSMF extension requires Windows SDK headers (mfapi.h, mfidl.h, etc.)" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
    Write-Host "To install Windows SDK:" -ForegroundColor Yellow
    Write-Host "  1. Run Visual Studio Installer" -ForegroundColor Yellow
    Write-Host "  2. Modify your installation" -ForegroundColor Yellow
    Write-Host "  3. Under 'Individual components', select:" -ForegroundColor Yellow
    Write-Host "     - Windows 10 SDK or Windows 11 SDK" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
    Write-Host "Or skip MSMF extension (system will use OpenCV fallback)" -ForegroundColor Yellow
    exit 1
}

# Build extension
Write-Host ""
Write-Host "[INFO] Building MSMF extension..." -ForegroundColor Cyan
Write-Host "Location: $extensionDir" -ForegroundColor Gray

Push-Location $extensionDir

try {
    # Force MinGW if available, otherwise use detected compiler
    if ($usingMinGW) {
        Write-Host "[INFO] Using MinGW compiler (GCC)" -ForegroundColor Gray
        
        # Set MinGW environment variables for setuptools
        $env:CC = Join-Path $MinGWPath "gcc.exe"
        $env:CXX = Join-Path $MinGWPath "g++.exe"
        
        Write-Host "[INFO] CC: $env:CC" -ForegroundColor Gray
        Write-Host "[INFO] CXX: $env:CXX" -ForegroundColor Gray
        
        # Don't use --compiler=mingw32, let environment variables handle it
        # This avoids setuptools' broken MinGW configuration
        & $pythonExe setup.py build_ext --inplace
    } else {
        Write-Host "[INFO] Using Visual Studio compiler (MSVC)" -ForegroundColor Gray
        & $pythonExe setup.py build_ext --inplace
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[SUCCESS] Build complete!" -ForegroundColor Green
        
        # Find the built .pyd file
        $pydFile = Get-ChildItem -Filter "msmf_capture*.pyd" | Select-Object -First 1
        
        if ($pydFile) {
            Write-Host "[OK] Built: $($pydFile.Name)" -ForegroundColor Green
            Write-Host "[INFO] Extension built successfully - ready for deployment" -ForegroundColor Cyan
            Write-Host "[INFO] MinGW runtime DLLs will be copied during backend deployment" -ForegroundColor Gray
        } else {
            Write-Host "[WARN] .pyd file not found after build" -ForegroundColor Yellow
        }
    } else {
        Write-Host ""
        Write-Host "[ERROR] Build failed!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Note: System will fallback to OpenCV if extension unavailable" -ForegroundColor Yellow
        Pop-Location
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "[ERROR] Build exception: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}

Pop-Location

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "  MSMF Extension Built" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
