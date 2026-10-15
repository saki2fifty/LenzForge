# Download MinGW-w64 (Portable GCC Compiler for Windows)
# Part of LenzForge setup system - Enables portable C++ compilation

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Downloading MinGW-w64 Compiler" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Load version helper
. "$ScriptDir\XX-Get-Latest-Version.ps1"

# Try to get latest MinGW from GitHub
$FallbackUrl = "https://github.com/brechtsanders/winlibs_mingw/releases/download/15.2.0posix-13.0.0-ucrt-r2/winlibs-x86_64-posix-seh-gcc-15.2.0-mingw-w64ucrt-13.0.0-r2.7z"
$VersionInfo = Get-LatestGitHubRelease `
    -Repo "brechtsanders/winlibs_mingw" `
    -AssetPattern "x86_64-posix-seh-gcc.*mingw-w64ucrt.*\.7z$" `
    -FallbackUrl $FallbackUrl

$MinGWUrl = $VersionInfo.Url
$MinGWVersion = $VersionInfo.Version
$DownloadDir = Join-Path $ProjectRoot "downloads\mingw"
$MinGWArchive = Join-Path $DownloadDir "mingw-w64.7z"

Write-Host "[INFO] MinGW Version: GCC $MinGWVersion" -ForegroundColor Gray
Write-Host "[INFO] Download URL: $MinGWUrl" -ForegroundColor Gray
Write-Host "[INFO] Download location: $DownloadDir" -ForegroundColor Gray
Write-Host ""

# Check if already downloaded
if (Test-Path $MinGWArchive) {
    $FileSize = (Get-Item $MinGWArchive).Length / 1MB
    Write-Host "[OK] MinGW already downloaded ($([math]::Round($FileSize, 2)) MB)" -ForegroundColor Green
    Write-Host "[INFO] Skipping download" -ForegroundColor Gray
    exit 0
}

# Create download directory
if (-not (Test-Path $DownloadDir)) {
    New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
}

# Download MinGW
Write-Host "[INFO] Downloading MinGW-w64 (~100 MB)..." -ForegroundColor Yellow
Write-Host "[INFO] This may take a few minutes..." -ForegroundColor Gray

try {
    # Use WebClient for progress
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($MinGWUrl, $MinGWArchive)
    
    if (Test-Path $MinGWArchive) {
        $FileSize = (Get-Item $MinGWArchive).Length / 1MB
        Write-Host ""
        Write-Host "[SUCCESS] MinGW downloaded successfully" -ForegroundColor Green
        Write-Host "[INFO] Size: $([math]::Round($FileSize, 2)) MB" -ForegroundColor Gray
        Write-Host "[INFO] Location: $MinGWArchive" -ForegroundColor Gray
        exit 0
    } else {
        Write-Host "[ERROR] Download completed but file not found" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "[ERROR] Failed to download MinGW: $_" -ForegroundColor Red
    Write-Host "[INFO] Please check your internet connection" -ForegroundColor Yellow
    exit 1
}
