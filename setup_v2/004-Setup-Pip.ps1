$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$BuildToolsDir = Join-Path $ProjectRoot "buildtools\python"
$PythonExe = Join-Path $BuildToolsDir "python.exe"
$GetPipFile = Join-Path $ProjectRoot "downloads\python\get-pip.py"
$PthFile = Join-Path $BuildToolsDir "python311._pth"

Write-Host "[INFO] Setting up pip for portable Python..." -ForegroundColor Cyan

if (-not (Test-Path $PythonExe)) {
    Write-Host "[ERROR] Python not found at: $PythonExe" -ForegroundColor Red
    Write-Host "[ERROR] Please run 02-Extract-Python.ps1 first" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $GetPipFile)) {
    Write-Host "[ERROR] get-pip.py not found at: $GetPipFile" -ForegroundColor Red
    Write-Host "[ERROR] Please run 01-Download-GetPip.ps1 first" -ForegroundColor Red
    exit 1
}

$PipExe = Join-Path $BuildToolsDir "Scripts\pip.exe"
if (Test-Path $PipExe) {
    Write-Host "[OK] pip already installed" -ForegroundColor Green
    $PipVersion = & $PipExe --version 2>&1
    Write-Host "[INFO] pip version: $PipVersion" -ForegroundColor Gray
    exit 0
}

Write-Host "[INFO] Configuring Python to enable site-packages..." -ForegroundColor Yellow

if (Test-Path $PthFile) {
    $Content = Get-Content $PthFile
    if ($Content -notcontains "import site") {
        Write-Host "[INFO] Adding 'import site' to $PthFile" -ForegroundColor Gray
        Add-Content -Path $PthFile -Value "`nimport site"
    } else {
        Write-Host "[INFO] 'import site' already configured" -ForegroundColor Gray
    }
} else {
    Write-Host "[WARNING] Python ._pth file not found, creating one..." -ForegroundColor Yellow
    @"
python311.zip
.
import site
"@ | Set-Content -Path $PthFile
}

Write-Host "[INFO] Installing pip..." -ForegroundColor Yellow
Write-Host "[INFO] Running: python.exe get-pip.py" -ForegroundColor Gray
Write-Host "[INFO] (PATH warnings are expected and safe for portable Python)" -ForegroundColor Gray

# Temporarily disable strict error handling for pip installation (warnings are expected)
$PrevErrorPref = $ErrorActionPreference
$ErrorActionPreference = "Continue"

# Run pip installation with --no-warn-script-location to suppress PATH warnings
Start-Process -FilePath $PythonExe -ArgumentList "$GetPipFile --no-warn-script-location" -NoNewWindow -Wait

# Restore error preference
$ErrorActionPreference = $PrevErrorPref

# Check if pip was actually installed (the real test)
if (Test-Path $PipExe) {
    Write-Host "[SUCCESS] pip installed successfully" -ForegroundColor Green
    
    $PipVersion = & $PipExe --version 2>&1
    Write-Host "[INFO] pip version: $PipVersion" -ForegroundColor Gray
    
    Write-Host "[INFO] Upgrading pip to latest version..." -ForegroundColor Yellow
    $null = & $PythonExe -m pip install --upgrade pip --quiet 2>&1
    
    exit 0
} else {
    Write-Host "[ERROR] pip installation failed - pip.exe not found" -ForegroundColor Red
    exit 1
}
