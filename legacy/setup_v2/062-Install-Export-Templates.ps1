# Install Godot Export Templates
param(
    [string]$GodotVersion = "4.3"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Handle version format
if ($GodotVersion -like "*-stable") {
    $VersionTag = $GodotVersion
    $VersionNumber = $GodotVersion -replace "-stable", ""
} else {
    $VersionNumber = $GodotVersion
    $VersionTag = "$GodotVersion-stable"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installing Export Templates v$VersionTag" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# PORTABLE: Install templates within project directory, NOT AppData
$TemplatesDir = Join-Path $ProjectRoot "buildtools\godot\export_templates\$VersionTag"
$DownloadDir = Join-Path $ProjectRoot "buildtools\downloads"
$TemplatesZip = Join-Path $DownloadDir "godot-templates-$VersionTag.tpz"

# Check if it's actually a zip file (sometimes GitHub serves .zip)
$ZipAlternative = Join-Path $DownloadDir "godot-templates-$VersionTag.zip"
if (Test-Path $ZipAlternative) {
    $TemplatesZip = $ZipAlternative
    Write-Host "[INFO] Using .zip file instead of .tpz" -ForegroundColor Yellow
}

# Check if templates already installed
if (Test-Path $TemplatesDir) {
    Write-Host "[OK] Export templates already installed at:" -ForegroundColor Green
    Write-Host "     $TemplatesDir" -ForegroundColor Gray
    Write-Host ""
    exit 0
}

# Create download directory
New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null

# Download templates
$DownloadUrl = "https://github.com/godotengine/godot/releases/download/$VersionTag/Godot_v${VersionTag}_export_templates.tpz"

if (-not (Test-Path $TemplatesZip)) {
    Write-Host "[INFO] Downloading export templates..." -ForegroundColor Yellow
    Write-Host "[INFO] URL: $DownloadUrl" -ForegroundColor Gray
    Write-Host "[INFO] This may take a few minutes (70-150 MB)..." -ForegroundColor Gray
    Write-Host ""
    
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $TemplatesZip -UseBasicParsing
        Write-Host "[OK] Download complete" -ForegroundColor Green
        Write-Host ""
    } catch {
        Write-Host "[ERROR] Failed to download templates: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[OK] Templates archive already downloaded" -ForegroundColor Green
    Write-Host ""
}

# Extract templates
Write-Host "[INFO] Installing templates to portable location..." -ForegroundColor Yellow
Write-Host "[INFO] Location: $TemplatesDir" -ForegroundColor Gray
Write-Host ""

# Create templates directory (portable, within project)
$TemplateParentDir = Split-Path -Parent $TemplatesDir
New-Item -ItemType Directory -Force -Path $TemplateParentDir | Out-Null

try {
    # Extract using .NET compression (PORTABLE - avoids system temp)
    Write-Host "[INFO] Extracting templates using .NET compression..." -ForegroundColor Yellow
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    
    # Open the zip file and extract to target directory
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($TemplatesZip)
        
        # Ensure target directory exists
        if (-not (Test-Path $TemplatesDir)) {
            New-Item -ItemType Directory -Force -Path $TemplatesDir | Out-Null
        }
        
        # Extract all entries
        foreach ($entry in $zip.Entries) {
            $destinationPath = Join-Path $TemplatesDir $entry.FullName
            $destinationDir = Split-Path $destinationPath
            
            # Create directory if needed
            if (-not $entry.FullName.EndsWith("/")) {
                if (-not (Test-Path $destinationDir)) {
                    New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
                }
            }
            
            # Extract file
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destinationPath)
        }
        
        $zip.Dispose()
        
        Write-Host "[OK] Templates installed successfully" -ForegroundColor Green
        Write-Host "[INFO] Location: $TemplatesDir" -ForegroundColor Cyan
        Write-Host ""
        
    } catch {
        Write-Host "[ERROR] Failed to install templates: $_" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "[ERROR] Failed to install templates: $_" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCCESS] Export templates ready for Godot $VersionTag" -ForegroundColor Green
Write-Host ""
exit 0
