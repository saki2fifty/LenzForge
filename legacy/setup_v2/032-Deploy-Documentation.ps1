$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deploying Documentation Files" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$SourceRoot = $ScriptDir
$TargetRoot = $ProjectRoot

# List of documentation files to deploy
$DocFiles = @(
    "TCP_MEMMAP_IMPLEMENTATION.md",
    "FLASK_INTEGRATION_COMPLETE.md",
    "BACKEND_GUI_CLI.md"
)

Write-Host "[INFO] Deploying documentation files..." -ForegroundColor Yellow

foreach ($File in $DocFiles) {
    $SourceFile = Join-Path $SourceRoot "assets\docs\$File"
    $TargetFile = Join-Path $TargetRoot $File
    
    if (Test-Path $SourceFile) {
        Copy-Item $SourceFile $TargetFile -Force
        Write-Host "[OK] Deployed: $File" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Source file not found: $File" -ForegroundColor Yellow
        Write-Host "[INFO] Expected at: $SourceFile" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "[SUCCESS] Documentation deployment complete" -ForegroundColor Green
Write-Host "[INFO] Files deployed to: $TargetRoot" -ForegroundColor Cyan

exit 0
