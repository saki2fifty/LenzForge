$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deploying GDExtension Files" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$AssetsDir = Join-Path $ScriptDir "assets\godot-extension"
$WorkspaceDir = Join-Path $ProjectRoot "workspace_v2\godot-extension"

if (-not (Test-Path $AssetsDir)) {
    Write-Host "[ERROR] GDExtension assets not found: $AssetsDir" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Creating workspace directory..." -ForegroundColor Yellow
if (-not (Test-Path $WorkspaceDir)) {
    New-Item -ItemType Directory -Path $WorkspaceDir -Force | Out-Null
}

Write-Host "[INFO] Copying GDExtension files..." -ForegroundColor Yellow

Copy-Item -Path "$AssetsDir\*" -Destination $WorkspaceDir -Recurse -Force

Write-Host "[OK] GDExtension files deployed" -ForegroundColor Green
Write-Host "[INFO] Extension file: LenzForge_video.gdextension" -ForegroundColor Gray
Write-Host "[INFO] Location: $WorkspaceDir" -ForegroundColor Gray

exit 0
