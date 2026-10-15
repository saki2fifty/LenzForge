# LenzForge V2 - Run Web Server
# Starts the Flask web UI server

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "================================" -ForegroundColor Cyan
Write-Host "  LenzForge V2 Web Server" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

$pythonExe = Join-Path $ProjectRoot "buildtools\python\python.exe"
$serverModule = Join-Path $ProjectRoot "workspace_v2\cpp-viewer\backend_v2\server\app.py"

# Check Python
if (-not (Test-Path $pythonExe)) {
    Write-Host "[ERROR] Python not found at: $pythonExe" -ForegroundColor Red
    Write-Host "[INFO] Please run: setup_v2\01-Install-Python.ps1" -ForegroundColor Yellow
    exit 1
}

# Check Flask dependencies
Write-Host "[INFO] Checking Flask dependencies..." -ForegroundColor Yellow
$flaskCheck = & $pythonExe -c "import flask; print(flask.__version__)" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Flask not installed" -ForegroundColor Red
    Write-Host "[INFO] Please run: setup_v2\04-Install-Flask-Dependencies.ps1" -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] Flask $flaskCheck detected" -ForegroundColor Green

# Check backend_v2 deployment
if (-not (Test-Path $serverModule)) {
    Write-Host "[ERROR] Backend server not deployed" -ForegroundColor Red
    Write-Host "[INFO] Please run: setup_v2\06-Deploy-Backend.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Starting Flask web server..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Server will be available at:" -ForegroundColor Cyan
Write-Host "  http://localhost:5000" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Gray
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Run the server using the launcher script
$launcherScript = Join-Path $ProjectRoot "workspace_v2\cpp-viewer\backend_v2\run_server.py"
& $pythonExe $launcherScript
