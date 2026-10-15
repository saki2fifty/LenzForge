# Install/Extract Windows SDK Components
# Part of LenzForge setup system

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installing Windows SDK Components" -ForegroundColor Cyan
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

$SystemSDKFound = $false
foreach ($sdkPath in $SystemSDKPaths) {
    if (Test-Path $sdkPath) {
        $sdkVersions = Get-ChildItem $sdkPath -Directory | Where-Object { $_.Name -match '^\d+\.\d+' }
        foreach ($version in $sdkVersions) {
            $mfapiPath = Join-Path $version.FullName "um\mfapi.h"
            if (Test-Path $mfapiPath) {
                Write-Host "[OK] Windows SDK available on system: $($version.Name)" -ForegroundColor Green
                Write-Host "[INFO] Location: $($version.FullName)" -ForegroundColor Gray
                Write-Host "[INFO] MSMF extension will use system SDK" -ForegroundColor Gray
                $SystemSDKFound = $true
                exit 0
            }
        }
    }
}

if (-not $SystemSDKFound) {
    Write-Host "[WARNING] Windows SDK not found on system" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To build the MSMF extension, please install Windows SDK:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Option 1: Use downloaded installer (if available)" -ForegroundColor Yellow
    $SDKInstaller = Join-Path $ProjectRoot "downloads\winsdk\winsdksetup.exe"
    if (Test-Path $SDKInstaller) {
        Write-Host "  Run: $SDKInstaller" -ForegroundColor White
        Write-Host "  Select: Windows SDK for Desktop C++ Development" -ForegroundColor Gray
        Write-Host "  Install to: Default location (C:\Program Files)" -ForegroundColor Gray
    } else {
        Write-Host "  Installer not found. Run 012-Download-WindowsSDK.ps1 first" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Option 2: Manual Download" -ForegroundColor Yellow
    Write-Host "  1. Visit: https://developer.microsoft.com/windows/downloads/windows-sdk/" -ForegroundColor Gray
    Write-Host "  2. Download Windows 11 SDK (or Windows 10 SDK)" -ForegroundColor Gray
    Write-Host "  3. Run installer" -ForegroundColor Gray
    Write-Host "  4. Select: Windows SDK for Desktop C++ Development" -ForegroundColor Gray
    Write-Host "  5. Complete installation" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option 3: Skip MSMF Extension" -ForegroundColor Yellow
    Write-Host "  System will use OpenCV fallback (works perfectly fine!)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[INFO] After installing SDK, re-run 000-Setup.ps1 or 020-Build-MSMF-Extension.ps1" -ForegroundColor Cyan
    exit 1
}
