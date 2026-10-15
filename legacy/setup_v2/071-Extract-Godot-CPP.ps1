$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Extracting Godot-CPP Headers" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$DownloadFile = Join-Path $ProjectRoot "buildtools\downloads\godot-cpp-4.3.zip"
$ExtractPath = Join-Path $ProjectRoot "buildtools\godot-cpp"

Write-Host "[INFO] Checking Godot-CPP extraction..." -ForegroundColor Yellow

if (Test-Path $ExtractPath) {
    Write-Host "[INFO] Godot-CPP already extracted" -ForegroundColor Green
    Write-Host "[INFO] Location: $ExtractPath" -ForegroundColor Gray
    exit 0
}

if (-not (Test-Path $DownloadFile)) {
    Write-Host "[ERROR] Godot-CPP download not found" -ForegroundColor Red
    Write-Host "[INFO] Please run 18-Download-Godot-CPP.ps1 first" -ForegroundColor Yellow
    exit 1
}

Write-Host "[INFO] Extracting Godot-CPP headers..." -ForegroundColor Yellow
Write-Host "[INFO] Source: $DownloadFile" -ForegroundColor Gray
Write-Host "[INFO] Target: $ExtractPath" -ForegroundColor Gray
Write-Host ""

try {
    Expand-Archive -Path $DownloadFile -DestinationPath "$ExtractPath-temp" -Force
    
    $ExtractedFolder = Get-ChildItem -Path "$ExtractPath-temp" -Directory | Select-Object -First 1
    Move-Item -Path $ExtractedFolder.FullName -Destination $ExtractPath -Force
    
    Remove-Item -Path "$ExtractPath-temp" -Recurse -Force
    
    Write-Host "[SUCCESS] Godot-CPP extracted successfully" -ForegroundColor Green
    Write-Host "[INFO] Location: $ExtractPath" -ForegroundColor Gray
}
catch {
    Write-Host "[ERROR] Extraction failed: $_" -ForegroundColor Red
    if (Test-Path "$ExtractPath-temp") {
        Remove-Item -Path "$ExtractPath-temp" -Recurse -Force -ErrorAction SilentlyContinue
    }
    exit 1
}

exit 0
