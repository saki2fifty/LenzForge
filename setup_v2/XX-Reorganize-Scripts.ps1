# Reorganize Scripts to 3-Digit Numbering
# This script renames all setup scripts according to REORGANIZATION_PLAN.md
# MANUAL EXECUTION ONLY - Review plan first!

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Script Reorganization Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "[WARNING] This will rename 24 scripts and archive 5 obsolete scripts!" -ForegroundColor Yellow
Write-Host "[INFO] Review REORGANIZATION_PLAN.md before proceeding" -ForegroundColor Cyan
Write-Host ""
$confirm = Read-Host "Type 'YES' to proceed"
if ($confirm -ne "YES") {
    Write-Host "[CANCELLED] No changes made" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "[INFO] Starting reorganization..." -ForegroundColor Cyan

# Archive directory
$ArchiveDir = Join-Path $ScriptDir "_archive\scripts-2digit-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
if (-not (Test-Path $ArchiveDir)) {
    New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null
}

Write-Host "[INFO] Archive location: $ArchiveDir" -ForegroundColor Gray
Write-Host ""

# Renaming map (old -> new)
$renameMap = @{
    "00-Setup.ps1" = "000-Setup.ps1"
    "01-Download-Python.ps1" = "001-Download-Python.ps1"
    "02-Download-GetPip.ps1" = "002-Download-GetPip.ps1"
    "03-Extract-Python.ps1" = "003-Extract-Python.ps1"
    "04-Setup-Pip.ps1" = "004-Setup-Pip.ps1"
    "05-Install-Packages.ps1" = "005-Install-Packages.ps1"
    "05-Build-MSMF-Extension.ps1" = "020-Build-MSMF-Extension.ps1"
    "06-Deploy-Backend.ps1" = "030-Deploy-Backend.ps1"
    "07-Deploy-GUI-Launcher.ps1" = "031-Deploy-GUI-Launcher.ps1"
    "07-Deploy-Documentation.ps1" = "032-Deploy-Documentation.ps1"
    "08-Deploy-CPP-Viewer.ps1" = "050-Deploy-CPP-Viewer.ps1"
    "09-Download-CMake.ps1" = "040-Download-CMake.ps1"
    "10-Download-OpenCV-CPP.ps1" = "042-Download-OpenCV-CPP.ps1"
    "11-Extract-CMake.ps1" = "041-Extract-CMake.ps1"
    "12-Extract-OpenCV-CPP.ps1" = "043-Extract-OpenCV-CPP.ps1"
    "13-Build-CPP-Viewer.ps1" = "051-Build-CPP-Viewer.ps1"
    "14-Download-Godot.ps1" = "060-Download-Godot.ps1"
    "15-Extract-Godot.ps1" = "061-Extract-Godot.ps1"
    "17-Download-Godot-CPP.ps1" = "070-Download-Godot-CPP.ps1"
    "18-Extract-Godot-CPP.ps1" = "071-Extract-Godot-CPP.ps1"
    "19-Deploy-GDExtension.ps1" = "080-Deploy-GDExtension.ps1"
    "16-Deploy-Godot-Project.ps1" = "081-Deploy-Godot-Project.ps1"
    "20-Build-GDExtension.ps1" = "082-Build-GDExtension.ps1"
    "21-Install-Export-Templates.ps1" = "062-Install-Export-Templates.ps1"
    "23-Install-Virtual-Camera.ps1" = "090-Install-Virtual-Camera.ps1"
    "22-Build-Godot-Exe.ps1" = "091-Build-Godot-Exe.ps1"
}

# Scripts to archive (obsolete/duplicates)
$archiveOnly = @(
    "04-Install-Flask-Dependencies.ps1"
    "16-Setup-CPP.ps1"
    "17-Setup-Godot.ps1"
    "21-Install-Extension-To-Godot.ps1"
    "22-Setup-GDExtension.ps1"
    "24-Install-VirtualCam-Python.ps1"
    "05-Build-MSMF-Extension-Verbose.ps1"
)

# Special handling
$specialMoves = @{
    "07-Run-Web-Server.ps1" = "Run-Web-Server.ps1"
    "05-Build-MSMF-Extension-Verbose.ps1" = "XX-Build-MSMF-Verbose.ps1"
}

# Phase 1: Archive obsolete scripts
Write-Host "=== Phase 1: Archiving obsolete scripts ===" -ForegroundColor Yellow
foreach ($script in $archiveOnly) {
    $sourcePath = Join-Path $ScriptDir $script
    if (Test-Path $sourcePath) {
        $destPath = Join-Path $ArchiveDir $script
        Copy-Item $sourcePath $destPath
        Write-Host "[ARCHIVED] $script" -ForegroundColor Gray
    }
}

# Phase 2: Handle special moves
Write-Host ""
Write-Host "=== Phase 2: Special moves ===" -ForegroundColor Yellow
foreach ($old in $specialMoves.Keys) {
    $sourcePath = Join-Path $ScriptDir $old
    if (Test-Path $sourcePath) {
        $newName = $specialMoves[$old]
        $destPath = Join-Path $ScriptDir $newName
        Move-Item $sourcePath $destPath -Force
        Write-Host "[MOVED] $old -> $newName" -ForegroundColor Cyan
    }
}

# Phase 3: Rename scripts
Write-Host ""
Write-Host "=== Phase 3: Renaming scripts ===" -ForegroundColor Yellow
foreach ($old in $renameMap.Keys) {
    $sourcePath = Join-Path $ScriptDir $old
    if (Test-Path $sourcePath) {
        $newName = $renameMap[$old]
        $destPath = Join-Path $ScriptDir $newName
        Move-Item $sourcePath $destPath -Force
        Write-Host "[RENAMED] $old -> $newName" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Reorganization Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "[SUCCESS] All scripts reorganized" -ForegroundColor Green
Write-Host "[INFO] Obsolete scripts archived to: $ArchiveDir" -ForegroundColor Gray
Write-Host ""
Write-Host "[NEXT STEP] Update 000-Setup.ps1 to call new script numbers" -ForegroundColor Cyan
