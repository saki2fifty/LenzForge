# Prepare GDExtension Assets
# Ensures MinGW runtime DLLs are in the source assets folder
# so they get deployed automatically every time

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Prepare GDExtension Assets" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$MinGWBin = Join-Path $ProjectRoot "buildtools\mingw\bin"
$AssetsBin = Join-Path $ScriptDir "assets\lenzforge-ar\gdextension\bin"

# Check if MinGW exists
if (-not (Test-Path $MinGWBin)) {
    Write-Host "[ERROR] MinGW not found at: $MinGWBin" -ForegroundColor Red
    Write-Host "[INFO] Please run: .\010-Download-MinGW.ps1 and .\011-Extract-MinGW.ps1" -ForegroundColor Yellow
    exit 1
}

# Create bin directory in assets if it doesn't exist
if (-not (Test-Path $AssetsBin)) {
    Write-Host "[INFO] Creating bin directory in assets..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $AssetsBin -Force | Out-Null
}

Write-Host "[INFO] Copying MinGW runtime DLLs to assets..." -ForegroundColor Cyan

$dllsToCopy = @(
    "libgcc_s_seh-1.dll",
    "libstdc++-6.dll",
    "libwinpthread-1.dll"
)

$copiedCount = 0
foreach ($dll in $dllsToCopy) {
    $sourceDll = Join-Path $MinGWBin $dll
    $targetDll = Join-Path $AssetsBin $dll
    
    if (Test-Path $sourceDll) {
        Copy-Item $sourceDll $targetDll -Force
        Write-Host "[OK] Copied: $dll" -ForegroundColor Green
        $copiedCount++
    } else {
        Write-Host "[ERROR] DLL not found: $dll" -ForegroundColor Red
    }
}

Write-Host ""
if ($copiedCount -eq $dllsToCopy.Count) {
    Write-Host "[SUCCESS] All runtime DLLs copied to assets!" -ForegroundColor Green
    Write-Host "[INFO] These will now be deployed automatically with the project" -ForegroundColor Cyan
} else {
    Write-Host "[WARNING] Some DLLs were not copied" -ForegroundColor Yellow
}

Write-Host ""
exit 0
