# Download Windows SDK Components (Headers & Libs for MSMF)
# Part of LenzForge setup system - Required for MSMF extension compilation

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Downloading Windows SDK Components" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Check if system SDK already exists (prefer system installation)
$SystemSDKPaths = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\Include",
    "${env:ProgramFiles}\Windows Kits\10\Include"
)

foreach ($sdkPath in $SystemSDKPaths) {
    if (Test-Path $sdkPath) {
        $sdkVersions = Get-ChildItem $sdkPath -Directory | Where-Object { $_.Name -match '^\d+\.\d+' }
        foreach ($version in $sdkVersions) {
            $mfapiPath = Join-Path $version.FullName "um\mfapi.h"
            if (Test-Path $mfapiPath) {
                Write-Host "[OK] Windows SDK found on system: $($version.Name)" -ForegroundColor Green
                Write-Host "[INFO] Location: $sdkPath" -ForegroundColor Gray
                Write-Host "[INFO] Skipping download - will use system SDK" -ForegroundColor Gray
                exit 0
            }
        }
    }
}

Write-Host "[INFO] System SDK not found, will download portable SDK components" -ForegroundColor Yellow
Write-Host ""

# Windows SDK 10.0.22621.0 (Windows 11 SDK)
$SDKVersion = "10.0.22621.0"
$SDKUrl = "https://go.microsoft.com/fwlink/?linkid=2196241"  # Windows 11 SDK installer
$DownloadDir = Join-Path $ProjectRoot "downloads\winsdk"
$SDKInstaller = Join-Path $DownloadDir "winsdksetup.exe"

Write-Host "[INFO] SDK Version: $SDKVersion" -ForegroundColor Gray
Write-Host "[INFO] Download URL: $SDKUrl" -ForegroundColor Gray
Write-Host "[INFO] Download location: $DownloadDir" -ForegroundColor Gray
Write-Host ""

# Check if already downloaded
if (Test-Path $SDKInstaller) {
    $FileSize = (Get-Item $SDKInstaller).Length / 1MB
    Write-Host "[OK] Windows SDK installer already downloaded ($([math]::Round($FileSize, 2)) MB)" -ForegroundColor Green
    Write-Host "[INFO] Skipping download" -ForegroundColor Gray
    exit 0
}

# Create download directory
if (-not (Test-Path $DownloadDir)) {
    New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
}

# Download SDK installer
Write-Host "[INFO] Downloading Windows SDK installer (~2 MB)..." -ForegroundColor Yellow
Write-Host "[INFO] This is just the installer, not the full SDK" -ForegroundColor Gray
Write-Host "[INFO] Next script will install only needed components (~50 MB)" -ForegroundColor Gray

try {
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($SDKUrl, $SDKInstaller)
    
    if (Test-Path $SDKInstaller) {
        $FileSize = (Get-Item $SDKInstaller).Length / 1MB
        Write-Host ""
        Write-Host "[SUCCESS] Windows SDK installer downloaded" -ForegroundColor Green
        Write-Host "[INFO] Size: $([math]::Round($FileSize, 2)) MB" -ForegroundColor Gray
        Write-Host "[INFO] Location: $SDKInstaller" -ForegroundColor Gray
        exit 0
    } else {
        Write-Host "[ERROR] Download completed but installer not found" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "[ERROR] Failed to download Windows SDK: $_" -ForegroundColor Red
    Write-Host "[INFO] Please check your internet connection" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "[ALTERNATIVE] You can install Windows SDK manually:" -ForegroundColor Cyan
    Write-Host "  1. Download from: https://developer.microsoft.com/windows/downloads/windows-sdk/" -ForegroundColor Gray
    Write-Host "  2. Run installer" -ForegroundColor Gray
    Write-Host "  3. Select only: Windows SDK for Desktop C++ Development" -ForegroundColor Gray
    exit 1
}
