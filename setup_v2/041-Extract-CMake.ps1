# Extract CMake (Portable Build Tool)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Extracting CMake" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$CMakeArchive = Join-Path $ProjectRoot "downloads\cmake\cmake.zip"
$ExtractDir = Join-Path $ProjectRoot "buildtools"
$CMakeFinalDir = Join-Path $ExtractDir "cmake"

Write-Host "[INFO] Source: $CMakeArchive" -ForegroundColor Gray
Write-Host "[INFO] Destination: $CMakeFinalDir" -ForegroundColor Gray
Write-Host ""

# Check if already extracted
if (Test-Path (Join-Path $CMakeFinalDir "bin\cmake.exe")) {
    Write-Host "[OK] CMake already extracted" -ForegroundColor Green
    Write-Host "[INFO] Location: $CMakeFinalDir" -ForegroundColor Gray
    exit 0
}

# Check if archive exists
if (-not (Test-Path $CMakeArchive)) {
    Write-Host "[ERROR] CMake archive not found: $CMakeArchive" -ForegroundColor Red
    Write-Host "[INFO] Please run 040-Download-CMake.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Create buildtools directory
if (-not (Test-Path $ExtractDir)) {
    New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
}

# Extract
Write-Host "[INFO] Extracting CMake..." -ForegroundColor Yellow
Write-Host "[INFO] This may take a moment..." -ForegroundColor Gray

try {
    Expand-Archive -Path $CMakeArchive -DestinationPath $ExtractDir -Force
    
    # Find extracted directory (cmake-X.Y.Z-windows-x86_64)
    $ExtractedDir = Get-ChildItem -Path $ExtractDir -Directory | Where-Object { $_.Name -like "cmake-*" } | Select-Object -First 1
    
    if ($ExtractedDir) {
        # Remove old cmake dir if exists
        if (Test-Path $CMakeFinalDir) {
            Remove-Item -Path $CMakeFinalDir -Recurse -Force
        }
        
        # Rename to 'cmake'
        Rename-Item -Path $ExtractedDir.FullName -NewName "cmake" -Force
        
        Write-Host ""
        Write-Host "[SUCCESS] CMake extracted successfully" -ForegroundColor Green
        Write-Host "[INFO] Location: $CMakeFinalDir" -ForegroundColor Gray
        Write-Host "[INFO] Executable: $(Join-Path $CMakeFinalDir 'bin\cmake.exe')" -ForegroundColor Gray
        exit 0
    } else {
        Write-Host "[ERROR] CMake directory not found after extraction" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "[ERROR] Extraction failed: $_" -ForegroundColor Red
    exit 1
}
