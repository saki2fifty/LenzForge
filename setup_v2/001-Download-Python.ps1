$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$DownloadDir = Join-Path $ProjectRoot "downloads\python"
$PythonZip = Join-Path $DownloadDir "python-3.11.9-embed-amd64.zip"
$PythonUrl = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip"

Write-Host "[INFO] Checking for Python embeddable package..." -ForegroundColor Cyan

if (-not (Test-Path $DownloadDir)) {
    Write-Host "[INFO] Creating downloads directory..." -ForegroundColor Gray
    New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
}

if (Test-Path $PythonZip) {
    $FileSize = (Get-Item $PythonZip).Length / 1MB
    Write-Host "[OK] Python already downloaded ($([math]::Round($FileSize, 2)) MB)" -ForegroundColor Green
    Write-Host "[INFO] Skipping download (file exists)" -ForegroundColor Gray
    exit 0
}

Write-Host "[INFO] Downloading Python 3.11.9 embeddable..." -ForegroundColor Yellow
Write-Host "[INFO] URL: $PythonUrl" -ForegroundColor Gray
Write-Host "[INFO] Destination: $PythonZip" -ForegroundColor Gray

try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $PythonUrl -OutFile $PythonZip -UseBasicParsing
    $ProgressPreference = 'Continue'
    
    if (Test-Path $PythonZip) {
        $FileSize = (Get-Item $PythonZip).Length / 1MB
        Write-Host "[SUCCESS] Python downloaded successfully ($([math]::Round($FileSize, 2)) MB)" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "[ERROR] Download failed - file not found after download" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "[ERROR] Download failed: $_" -ForegroundColor Red
    exit 1
}
