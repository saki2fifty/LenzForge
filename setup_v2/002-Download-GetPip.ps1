$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$DownloadDir = Join-Path $ProjectRoot "downloads\python"
$GetPipFile = Join-Path $DownloadDir "get-pip.py"
$GetPipUrl = "https://bootstrap.pypa.io/get-pip.py"

Write-Host "[INFO] Checking for get-pip.py..." -ForegroundColor Cyan

if (-not (Test-Path $DownloadDir)) {
    Write-Host "[INFO] Creating downloads directory..." -ForegroundColor Gray
    New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
}

if (Test-Path $GetPipFile) {
    $FileSize = (Get-Item $GetPipFile).Length / 1KB
    Write-Host "[OK] get-pip.py already downloaded ($([math]::Round($FileSize, 2)) KB)" -ForegroundColor Green
    Write-Host "[INFO] Skipping download (file exists)" -ForegroundColor Gray
    exit 0
}

Write-Host "[INFO] Downloading get-pip.py..." -ForegroundColor Yellow
Write-Host "[INFO] URL: $GetPipUrl" -ForegroundColor Gray
Write-Host "[INFO] Destination: $GetPipFile" -ForegroundColor Gray

try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $GetPipUrl -OutFile $GetPipFile -UseBasicParsing
    $ProgressPreference = 'Continue'
    
    if (Test-Path $GetPipFile) {
        $FileSize = (Get-Item $GetPipFile).Length / 1KB
        Write-Host "[SUCCESS] get-pip.py downloaded successfully ($([math]::Round($FileSize, 2)) KB)" -ForegroundColor Green
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
