# LenzForge Backup Script
# Creates timestamped backups of critical project files

param(
    [string]$BackupNote = ""
)

$ErrorActionPreference = "Stop"

# Get project root (parent of setup_v2 folder)
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BackupRoot = Join-Path $ProjectRoot "_backups"

# Create timestamp for backup folder
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BackupFolder = Join-Path $BackupRoot $Timestamp

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  LenzForge Environment Backup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create backup directory
Write-Host "[INFO] Creating backup directory..." -ForegroundColor Gray
New-Item -ItemType Directory -Force -Path $BackupFolder | Out-Null
Write-Host "[OK] Backup location: $BackupFolder" -ForegroundColor Green

# Function to copy with progress
function Copy-WithProgress {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Name
    )
    
    Write-Host "[INFO] Backing up: $Name..." -ForegroundColor Gray
    
    if (Test-Path $Source) {
        try {
            if (Test-Path $Source -PathType Container) {
                # It's a directory
                Copy-Item -Path $Source -Destination $Destination -Recurse -Force
            } else {
                # It's a file
                Copy-Item -Path $Source -Destination $Destination -Force
            }
            Write-Host "[OK] Backed up: $Name" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "[ERROR] Failed to backup $Name : $_" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "[SKIP] Not found: $Name" -ForegroundColor Yellow
        return $false
    }
}

$SuccessCount = 0
$TotalItems = 0

# Backup /setup_v2 folder
$TotalItems++
if (Copy-WithProgress -Source (Join-Path $ProjectRoot "setup_v2") -Destination (Join-Path $BackupFolder "setup_v2") -Name "setup_v2/") {
    $SuccessCount++
}

# Backup /memory-bank folder
$TotalItems++
if (Copy-WithProgress -Source (Join-Path $ProjectRoot "memory-bank") -Destination (Join-Path $BackupFolder "memory-bank") -Name "memory-bank/") {
    $SuccessCount++
}

# Backup .clinerules folder
$TotalItems++
if (Copy-WithProgress -Source (Join-Path $ProjectRoot ".clinerules") -Destination (Join-Path $BackupFolder ".clinerules") -Name ".clinerules/") {
    $SuccessCount++
}

# Backup root level files (all markdown, text, and config files)
Write-Host ""
Write-Host "[INFO] Backing up root level files..." -ForegroundColor Gray

$RootFiles = Get-ChildItem -Path $ProjectRoot -File | Where-Object { 
    $_.Name -notlike ".*" -and  # Exclude hidden files
    $_.Name -ne "_backups" -and  # Exclude backup folder marker
    ($_.Extension -match '\.(md|txt|json|ps1|bat|sh)$' -or $_.Name -eq "LICENSE")
}

foreach ($File in $RootFiles) {
    $TotalItems++
    $DestPath = Join-Path $BackupFolder $File.Name
    
    try {
        Copy-Item -Path $File.FullName -Destination $DestPath -Force
        Write-Host "  [OK] $($File.Name)" -ForegroundColor Green
        $SuccessCount++
    } catch {
        Write-Host "  [ERROR] Failed to backup $($File.Name): $_" -ForegroundColor Red
    }
}

# Create backup manifest
Write-Host ""
Write-Host "[INFO] Creating backup manifest..." -ForegroundColor Gray

$Manifest = @{
    "timestamp" = $Timestamp
    "date" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "note" = $BackupNote
    "items_backed_up" = $SuccessCount
    "total_items" = $TotalItems
    "success" = ($SuccessCount -eq $TotalItems)
    "project_root" = $ProjectRoot
    "contents" = @{
        "setup_v2_folder" = (Test-Path (Join-Path $BackupFolder "setup_v2"))
        "memory_bank_folder" = (Test-Path (Join-Path $BackupFolder "memory-bank"))
        "clinerules_folder" = (Test-Path (Join-Path $BackupFolder ".clinerules"))
        "root_files" = $RootFiles.Count
    }
}

$ManifestPath = Join-Path $BackupFolder "_manifest.json"
$Manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $ManifestPath -Encoding UTF8

Write-Host "[OK] Manifest created: _manifest.json" -ForegroundColor Green

# Calculate backup size
$BackupSize = (Get-ChildItem -Path $BackupFolder -Recurse -File | Measure-Object -Property Length -Sum).Sum
$BackupSizeMB = [math]::Round($BackupSize / 1MB, 2)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Backup Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Location: $BackupFolder" -ForegroundColor White
Write-Host "Items Backed Up: $SuccessCount / $TotalItems" -ForegroundColor White
Write-Host "Backup Size: $BackupSizeMB MB" -ForegroundColor White

if ($BackupNote) {
    Write-Host "Note: $BackupNote" -ForegroundColor White
}

Write-Host ""

if ($SuccessCount -eq $TotalItems) {
    Write-Host "[SUCCESS] Backup completed successfully!" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Backup completed with some items missing" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "To restore from this backup, manually copy files from:" -ForegroundColor Gray
Write-Host "  $BackupFolder" -ForegroundColor Gray
Write-Host ""

# List all backups
$AllBackups = Get-ChildItem -Path $BackupRoot -Directory | Sort-Object Name -Descending
if ($AllBackups.Count -gt 1) {
    Write-Host "Previous backups available:" -ForegroundColor Gray
    $AllBackups | Select-Object -First 5 -Skip 1 | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor DarkGray
    }
    if ($AllBackups.Count -gt 6) {
        Write-Host "  ... and $($AllBackups.Count - 6) more" -ForegroundColor DarkGray
    }
    Write-Host ""
}

exit 0
