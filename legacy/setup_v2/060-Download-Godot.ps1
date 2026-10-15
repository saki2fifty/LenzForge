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

$DownloadsDir = Join-Path $ProjectRoot "buildtools\downloads"
$GodotUrl = "https://github.com/godotengine/godot/releases/download/$VersionTag/Godot_v${VersionTag}_win64.exe.zip"
$GodotZip = Join-Path $DownloadsDir "godot-$VersionClean.zip"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Downloading Godot Engine $VersionTag" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $DownloadsDir)) {
    New-Item -ItemType Directory -Path $DownloadsDir -Force | Out-Null
}

if (Test-Path $GodotZip) {
    Write-Host "[INFO] Godot already downloaded" -ForegroundColor Green
    Write-Host "[INFO] File: $GodotZip" -ForegroundColor Gray
    exit 0
}

Write-Host "[INFO] Downloading Godot 4.3 Stable..." -ForegroundColor Yellow
Write-Host "[INFO] URL: $GodotUrl" -ForegroundColor Gray
Write-Host "[INFO] This may take a few minutes..." -ForegroundColor Gray
Write-Host ""

try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $GodotUrl -OutFile $GodotZip -UseBasicParsing
    $ProgressPreference = 'Continue'
    
    if (Test-Path $GodotZip) {
        $FileSize = (Get-Item $GodotZip).Length / 1MB
        Write-Host "[SUCCESS] Downloaded successfully" -ForegroundColor Green
        Write-Host "[INFO] Size: $([math]::Round($FileSize, 2)) MB" -ForegroundColor Gray
        Write-Host "[INFO] Location: $GodotZip" -ForegroundColor Gray
        exit 0
    } else {
        Write-Host "[ERROR] Download completed but file not found" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "[ERROR] Download failed: $_" -ForegroundColor Red
    if (Test-Path $GodotZip) {
        Remove-Item $GodotZip -Force
    }
    exit 1
}
