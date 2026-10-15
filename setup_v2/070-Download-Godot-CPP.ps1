$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Downloading Godot-CPP Headers" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$DownloadDir = Join-Path $ProjectRoot "buildtools\downloads"
$OutputFile = Join-Path $DownloadDir "godot-cpp-4.3.zip"
$Url = "https://github.com/godotengine/godot-cpp/archive/refs/tags/godot-4.3-stable.zip"

Write-Host "[INFO] Checking for Godot-CPP headers..." -ForegroundColor Yellow

if (Test-Path $OutputFile) {
    Write-Host "[INFO] Godot-CPP already downloaded" -ForegroundColor Green
    Write-Host "[INFO] Location: $OutputFile" -ForegroundColor Gray
    exit 0
}

Write-Host "[INFO] Creating downloads directory..." -ForegroundColor Yellow
if (-not (Test-Path $DownloadDir)) {
    New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
}

Write-Host "[INFO] Downloading Godot-CPP 4.3 headers..." -ForegroundColor Yellow
Write-Host "[INFO] URL: $Url" -ForegroundColor Gray
Write-Host "[INFO] This may take a few minutes (~50 MB)..." -ForegroundColor Gray
Write-Host ""

try {
    Invoke-WebRequest -Uri $Url -OutFile $OutputFile -UseBasicParsing
    
    $FileSize = (Get-Item $OutputFile).Length / 1MB
    Write-Host ""
    Write-Host "[SUCCESS] Downloaded successfully" -ForegroundColor Green
    Write-Host "[INFO] Size: $($FileSize.ToString('F2')) MB" -ForegroundColor Gray
    Write-Host "[INFO] Location: $OutputFile" -ForegroundColor Gray
}
catch {
    Write-Host "[ERROR] Download failed: $_" -ForegroundColor Red
    exit 1
}

exit 0
