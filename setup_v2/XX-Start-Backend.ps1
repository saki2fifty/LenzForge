# Start Backend Server
# Uses portable Python with all packages installed

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Starting LenzForge Backend Server" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# If script is in setup_v2, project root is parent
# If script is in project root, project root is script dir
if ((Split-Path -Leaf $ScriptDir) -eq "setup_v2") {
    $ProjectRoot = Split-Path -Parent $ScriptDir
} else {
    $ProjectRoot = $ScriptDir
}

# Check for portable Python
$PortablePython = Join-Path $ProjectRoot "buildtools\python\python.exe"
$BackendDir = Join-Path $ProjectRoot "workspace_v2\LenzForge-Vision\backend_v2"
$RunScript = Join-Path $BackendDir "run_server.py"

Write-Host "[INFO] Project Root: $ProjectRoot" -ForegroundColor Gray
Write-Host "[INFO] Backend Directory: $BackendDir" -ForegroundColor Gray
Write-Host ""

# Check if portable Python exists
if (Test-Path $PortablePython) {
    Write-Host "[OK] Using portable Python: $PortablePython" -ForegroundColor Green
    $PythonExe = $PortablePython
} else {
    Write-Host "[WARN] Portable Python not found, using system Python" -ForegroundColor Yellow
    Write-Host "[INFO] To install portable Python, run: .\000-Setup.ps1" -ForegroundColor Gray
    $PythonExe = "python"
}

# Check if backend directory exists
if (-not (Test-Path $BackendDir)) {
    Write-Host "[ERROR] Backend not found at: $BackendDir" -ForegroundColor Red
    Write-Host "[INFO] Please run: .\030-Deploy-Backend.ps1" -ForegroundColor Yellow
    exit 1
}

# Check if run script exists
if (-not (Test-Path $RunScript)) {
    Write-Host "[ERROR] Run script not found: $RunScript" -ForegroundColor Red
    Write-Host "[INFO] Please run: .\030-Deploy-Backend.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "[INFO] Starting Flask server..." -ForegroundColor Cyan
Write-Host "[INFO] Server will run on: http://localhost:5000" -ForegroundColor Cyan
Write-Host "[INFO] Viewer page: http://localhost:5000/viewer" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press CTRL+C to stop the server" -ForegroundColor Yellow
Write-Host ""

# Change to backend directory and run
Set-Location $BackendDir

try {
    & $PythonExe $RunScript
}
catch {
    Write-Host ""
    Write-Host "[ERROR] Failed to start server: $_" -ForegroundColor Red
    
    # Check if Flask is installed
    Write-Host ""
    Write-Host "[INFO] Checking if Flask is installed..." -ForegroundColor Cyan
    & $PythonExe -c "import flask" 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Flask is not installed!" -ForegroundColor Red
        Write-Host ""
        Write-Host "To install Flask, run:" -ForegroundColor Yellow
        Write-Host "  python -m pip install flask flask-cors flask-socketio" -ForegroundColor White
        Write-Host ""
        Write-Host "Or install the full environment:" -ForegroundColor Yellow
        Write-Host "  .\setup_v2\000-Setup.ps1" -ForegroundColor White
    }
    
    exit 1
}

# Return to original directory
Set-Location $ProjectRoot
