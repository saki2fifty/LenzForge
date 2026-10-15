# Download CMake (Portable Build Tool)
# Required for building GDExtension

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Downloading CMake" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Load version helper
. "$ScriptDir\XX-Get-Latest-Version.ps1"

# CMake download (using known stable version, can add dynamic later)
$CMakeVersion = "3.27.7"
$CMakeUrl = "https://github.com/Kitware/CMake/releases/download/v$CMakeVersion/cmake-$CMakeVersion-windows-x86_64.zip"
$DownloadDir = Join-Path $ProjectRoot "downloads\cmake"
$CMakeArchive = Join-Path $DownloadDir "cmake.zip"

Write-Host "[INFO] CMake Version: $CMakeVersion" -ForegroundColor Gray
Write-Host "[INFO] Download URL: $CMakeUrl" -ForegroundColor Gray
Write-Host "[INFO] Download location: $DownloadDir" -ForegroundColor Gray
Write-Host ""

# Check if already downloaded
if (Test-Path $CMakeArchive) {
    $FileSize = (Get-Item $CMakeArchive).Length / 1MB
    Write-Host "[OK] CMake already downloaded ($([math]::Round($FileSize, 2)) MB)" -ForegroundColor Green
    Write-Host "[INFO] Skipping download" -ForegroundColor Gray
    exit 0
}

# Create download directory
if (-not (Test-Path $DownloadDir)) {
    New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
}

# Download CMake
Write-Host "[INFO] Downloading CMake (~40 MB)..." -ForegroundColor Yellow
Write-Host "[INFO] This may take a few minutes..." -ForegroundColor Gray

try {
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($CMakeUrl, $CMakeArchive)
    
    if (Test-Path $CMakeArchive) {
        $FileSize = (Get-Item $CMakeArchive).Length / 1MB
        Write-Host ""
        Write-Host "[SUCCESS] CMake downloaded successfully" -ForegroundColor Green
        Write-Host "[INFO] Size: $([math]::Round($FileSize, 2)) MB" -ForegroundColor Gray
        Write-Host "[INFO] Location: $CMakeArchive" -ForegroundColor Gray
        exit 0
    } else {
        Write-Host "[ERROR] Download completed but file not found" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "[ERROR] Failed to download CMake: $_" -ForegroundColor Red
    Write-Host "[INFO] Please check your internet connection" -ForegroundColor Yellow
    exit 1
}
