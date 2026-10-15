Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Testing C++ Viewer System" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$PythonExe = Join-Path $ProjectRoot "buildtools\python\python.exe"
$BackendScript = Join-Path $ProjectRoot "workspace\cpp-viewer\backend_server.py"
$ViewerExe = Join-Path $ProjectRoot "workspace\cpp-viewer\build\bin\FaceMeshViewer.exe"

Write-Host "[INFO] Validating components..." -ForegroundColor Cyan

if (-not (Test-Path $PythonExe)) {
    Write-Host "[ERROR] Python not found: $PythonExe" -ForegroundColor Red
    Write-Host "[INFO] Please run 00-Setup.ps1 first" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $BackendScript)) {
    Write-Host "[ERROR] Backend script not found: $BackendScript" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $ViewerExe)) {
    Write-Host "[ERROR] C++ Viewer not found: $ViewerExe" -ForegroundColor Red
    Write-Host "[INFO] Please run 00-Setup-CPP.ps1 first" -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Python: $PythonExe" -ForegroundColor Green
Write-Host "[OK] Backend: $BackendScript" -ForegroundColor Green
Write-Host "[OK] Viewer: $ViewerExe" -ForegroundColor Green
Write-Host ""

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  TESTING INSTRUCTIONS" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "This will launch BOTH processes:" -ForegroundColor Cyan
Write-Host "  1. Python Backend (MediaPipe face mesh)" -ForegroundColor White
Write-Host "  2. C++ Frontend (OpenCV display)" -ForegroundColor White
Write-Host ""
Write-Host "The Python backend will:" -ForegroundColor Cyan
Write-Host "  - Enumerate cameras" -ForegroundColor Gray
Write-Host "  - Ask you to select a camera" -ForegroundColor Gray
Write-Host "  - Process face mesh via MediaPipe" -ForegroundColor Gray
Write-Host "  - Write to shared memory" -ForegroundColor Gray
Write-Host ""
Write-Host "The C++ frontend will:" -ForegroundColor Cyan
Write-Host "  - Read from shared memory" -ForegroundColor Gray
Write-Host "  - Display video + face mesh" -ForegroundColor Gray
Write-Host "  - Press 'm' to toggle mesh" -ForegroundColor Gray
Write-Host "  - Press 'q' to quit" -ForegroundColor Gray
Write-Host ""
Write-Host "Press any key to start the Python backend..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host ""
Write-Host "[INFO] Starting Python backend..." -ForegroundColor Cyan
Write-Host "[INFO] Select a camera when prompted" -ForegroundColor Yellow
Write-Host ""

$BackendProcess = Start-Process -FilePath $PythonExe -ArgumentList $BackendScript -PassThru -NoNewWindow
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "[INFO] Python backend should be running now" -ForegroundColor Green
Write-Host "[INFO] Starting C++ frontend..." -ForegroundColor Cyan
Write-Host ""

try {
    & $ViewerExe
}
catch {
    Write-Host "[ERROR] C++ viewer failed: $_" -ForegroundColor Red
}

if ($BackendProcess -and !$BackendProcess.HasExited) {
    Write-Host ""
    Write-Host "[INFO] Stopping Python backend..." -ForegroundColor Yellow
    Stop-Process -Id $BackendProcess.Id -Force
    Write-Host "[OK] Backend stopped" -ForegroundColor Green
}

Write-Host ""
Write-Host "[INFO] Test complete" -ForegroundColor Cyan
exit 0
