# Extract MinGW-w64 Compiler
# Part of LenzForge setup system

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Extracting MinGW-w64 Compiler" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$MinGWArchive = Join-Path $ProjectRoot "downloads\mingw\mingw-w64.7z"
$BuildToolsDir = Join-Path $ProjectRoot "buildtools\mingw"

# Check if already extracted
if (Test-Path (Join-Path $BuildToolsDir "bin\gcc.exe")) {
    Write-Host "[OK] MinGW already extracted" -ForegroundColor Green
    Write-Host "[INFO] Location: $BuildToolsDir" -ForegroundColor Gray
    Write-Host "[INFO] Skipping extraction (gcc.exe exists)" -ForegroundColor Gray
    
    # Show version
    $gccPath = Join-Path $BuildToolsDir "bin\gcc.exe"
    $Version = & $gccPath --version 2>&1 | Select-Object -First 1
    Write-Host "[INFO] GCC Version: $Version" -ForegroundColor Gray
    exit 0
}

Write-Host "[INFO] Source: $MinGWArchive" -ForegroundColor Gray
Write-Host "[INFO] Destination: $BuildToolsDir" -ForegroundColor Gray

# Check if archive exists
if (-not (Test-Path $MinGWArchive)) {
    Write-Host "[ERROR] MinGW archive not found: $MinGWArchive" -ForegroundColor Red
    Write-Host "[INFO] Please run 010-Download-MinGW.ps1 first" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "[INFO] Extracting MinGW (~400 MB extracted)..." -ForegroundColor Yellow
Write-Host "[INFO] This may take a few minutes..." -ForegroundColor Gray

try {
    # Create build tools directory
    if (-not (Test-Path $BuildToolsDir)) {
        New-Item -ItemType Directory -Path $BuildToolsDir -Force | Out-Null
    }
    
    # Extract using 7-Zip (built into Windows 10+) or Expand-Archive
    $TempExtract = Join-Path $ProjectRoot "downloads\mingw\temp"
    
    # Try using tar (available in Windows 10+)
    Write-Host "[INFO] Extracting with tar..." -ForegroundColor Gray
    & tar -xf $MinGWArchive -C (Split-Path $TempExtract)
    
    # Find the extracted mingw64 folder
    $ExtractedFolder = Get-ChildItem -Path (Split-Path $TempExtract) -Directory | Where-Object { $_.Name -like "*mingw*" } | Select-Object -First 1
    
    if ($ExtractedFolder) {
        # Move contents to buildtools
        Move-Item -Path "$($ExtractedFolder.FullName)\*" -Destination $BuildToolsDir -Force
        Remove-Item -Path $ExtractedFolder.FullName -Recurse -Force
    }
    
    # Verify extraction
    if (Test-Path (Join-Path $BuildToolsDir "bin\gcc.exe")) {
        Write-Host ""
        Write-Host "[SUCCESS] MinGW extracted successfully" -ForegroundColor Green
        Write-Host "[INFO] Location: $BuildToolsDir" -ForegroundColor Gray
        
        # Show GCC version
        $gccPath = Join-Path $BuildToolsDir "bin\gcc.exe"
        $Version = & $gccPath --version 2>&1 | Select-Object -First 1
        Write-Host "[INFO] GCC Version: $Version" -ForegroundColor Gray
        exit 0
    } else {
        Write-Host "[ERROR] Extraction completed but gcc.exe not found" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "[ERROR] Failed to extract MinGW: $_" -ForegroundColor Red
    Write-Host "[INFO] You may need to extract manually" -ForegroundColor Yellow
    exit 1
}
