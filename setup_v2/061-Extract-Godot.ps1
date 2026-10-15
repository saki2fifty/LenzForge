param(
    [string]$GodotVersion = "4.3"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Handle version format - if it already has "-stable", don't add it again
if ($GodotVersion -like "*-stable") {
    $VersionTag = $GodotVersion
    $VersionClean = $GodotVersion
} else {
    $VersionTag = "$GodotVersion-stable"
    $VersionClean = "$GodotVersion-stable"
}

$GodotZip = Join-Path $ProjectRoot "buildtools\downloads\godot-$VersionClean.zip"
$GodotDir = Join-Path $ProjectRoot "buildtools\godot"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Extracting Godot Engine $VersionTag" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $GodotZip)) {
    Write-Host "[ERROR] Godot ZIP not found: $GodotZip" -ForegroundColor Red
    Write-Host "[ERROR] Please run 060-Download-Godot.ps1 first" -ForegroundColor Red
    exit 1
}

# Create godot subdirectory
if (-not (Test-Path $GodotDir)) {
    New-Item -ItemType Directory -Path $GodotDir -Force | Out-Null
}

$GodotExe = Join-Path $GodotDir "Godot_v${VersionTag}_win64.exe"
if (Test-Path $GodotExe) {
    Write-Host "[INFO] Godot already extracted" -ForegroundColor Green
    Write-Host "[INFO] Location: $GodotExe" -ForegroundColor Gray
    exit 0
}

Write-Host "[INFO] Extracting Godot..." -ForegroundColor Yellow
Write-Host "[INFO] Source: $GodotZip" -ForegroundColor Gray
Write-Host "[INFO] Target: $GodotDir" -ForegroundColor Gray
Write-Host ""

try {
    Expand-Archive -Path $GodotZip -DestinationPath $GodotDir -Force
    
    if (Test-Path $GodotExe) {
        Write-Host "[SUCCESS] Godot extracted successfully" -ForegroundColor Green
        Write-Host "[INFO] Executable: $GodotExe" -ForegroundColor Gray
        exit 0
    } else {
        Write-Host "[ERROR] Godot executable not found after extraction" -ForegroundColor Red
        Write-Host "[ERROR] Expected: $GodotExe" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "[ERROR] Extraction failed: $_" -ForegroundColor Red
    exit 1
}
