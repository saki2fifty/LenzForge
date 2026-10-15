$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Testing Godot Integration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$GodotExe = Join-Path $ProjectRoot "buildtools\godot\Godot_v4.3-stable_win64.exe"
$ProjectFile = Join-Path $ProjectRoot "workspace\godot-facemesh\project.godot"
$BackendScript = Join-Path $ProjectRoot "workspace\cpp-viewer\backend_server.py"
$PythonExe = Join-Path $ProjectRoot "buildtools\python\python.exe"

Write-Host "[INFO] Checking components..." -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path $GodotExe)) {
    Write-Host "[ERROR] Godot not found. Run 00-Setup-Godot.ps1 first" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Godot Engine found" -ForegroundColor Green

if (-not (Test-Path $ProjectFile)) {
    Write-Host "[ERROR] Godot project not found. Run 22-Deploy-Godot-Project.ps1 first" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Godot project found" -ForegroundColor Green

if (-not (Test-Path $PythonExe)) {
    Write-Host "[ERROR] Python not found. Run 00-Setup.ps1 first" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Python found" -ForegroundColor Green

if (-not (Test-Path $BackendScript)) {
    Write-Host "[ERROR] Backend script not found" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Backend script found" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Starting Godot Integration Test" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "[INFO] Starting Python backend..." -ForegroundColor Yellow
Write-Host "[IMPORTANT] When prompted, answer 'y' to enable JSON export!" -ForegroundColor Magenta
Write-Host ""

$BackendProcess = Start-Process -FilePath $PythonExe -ArgumentList $BackendScript -PassThru -NoNewWindow

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "[INFO] Launching Godot project..." -ForegroundColor Yellow
Write-Host ""

try {
    & $GodotExe --path (Split-Path $ProjectFile -Parent)
    
    Write-Host ""
    Write-Host "[INFO] Godot closed" -ForegroundColor Yellow
}
finally {
    if ($BackendProcess -and -not $BackendProcess.HasExited) {
        Write-Host "[INFO] Stopping Python backend..." -ForegroundColor Yellow
        $BackendProcess.Kill()
        $BackendProcess.WaitForExit(5000)
        Write-Host "[OK] Backend stopped" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "[SUCCESS] Test completed" -ForegroundColor Green

exit 0
