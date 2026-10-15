$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$PythonZip = Join-Path $ProjectRoot "downloads\python\python-3.11.9-embed-amd64.zip"
$BuildToolsDir = Join-Path $ProjectRoot "buildtools\python"

Write-Host "[INFO] Checking Python extraction..." -ForegroundColor Cyan

if (-not (Test-Path $PythonZip)) {
    Write-Host "[ERROR] Python ZIP not found at: $PythonZip" -ForegroundColor Red
    Write-Host "[ERROR] Please run 01-Download-Python.ps1 first" -ForegroundColor Red
    exit 1
}

if (Test-Path (Join-Path $BuildToolsDir "python.exe")) {
    Write-Host "[OK] Python already extracted" -ForegroundColor Green
    Write-Host "[INFO] Location: $BuildToolsDir" -ForegroundColor Gray
    Write-Host "[INFO] Skipping extraction (python.exe exists)" -ForegroundColor Gray
    exit 0
}

Write-Host "[INFO] Extracting Python to buildtools..." -ForegroundColor Yellow
Write-Host "[INFO] Source: $PythonZip" -ForegroundColor Gray
Write-Host "[INFO] Destination: $BuildToolsDir" -ForegroundColor Gray

try {
    if (-not (Test-Path $BuildToolsDir)) {
        New-Item -ItemType Directory -Path $BuildToolsDir -Force | Out-Null
    }
    
    Expand-Archive -Path $PythonZip -DestinationPath $BuildToolsDir -Force
    
    if (Test-Path (Join-Path $BuildToolsDir "python.exe")) {
        Write-Host "[SUCCESS] Python extracted successfully" -ForegroundColor Green
        
        $PythonExe = Join-Path $BuildToolsDir "python.exe"
        $Version = & $PythonExe --version 2>&1
        Write-Host "[INFO] Python version: $Version" -ForegroundColor Gray
        
        exit 0
    } else {
        Write-Host "[ERROR] Extraction failed - python.exe not found" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "[ERROR] Extraction failed: $_" -ForegroundColor Red
    exit 1
}
