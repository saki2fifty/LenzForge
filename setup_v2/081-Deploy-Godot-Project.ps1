# Deploy LenzForge AR Frontend
# Copies LenzForge-AR project from assets to workspace_v2
# Preserves compiled GDExtension DLLs to prevent breakage on redeploy

$ErrorActionPreference = "Stop"

Write-Host "[INFO] Deploying LenzForge AR Frontend..." -ForegroundColor Cyan

# Paths
$projectRoot = Split-Path $PSScriptRoot -Parent
$assetsPath = Join-Path $PSScriptRoot "assets\lenzforge-ar"
$workspacePath = Join-Path $projectRoot "workspace_v2\LenzForge-AR"
$binPath = Join-Path $workspacePath "gdextension\bin"

# Check if source exists
if (-not (Test-Path $assetsPath)) {
    Write-Host "[ERROR] LenzForge AR source not found: $assetsPath" -ForegroundColor Red
    Write-Host "[INFO] This should not happen in a properly configured setup" -ForegroundColor Yellow
    exit 0  # Don't fail setup, just skip
}

# Create workspace directory if needed
$workspaceV2 = Join-Path $projectRoot "workspace_v2"
if (-not (Test-Path $workspaceV2)) {
    New-Item -ItemType Directory -Path $workspaceV2 | Out-Null
    Write-Host "[OK] Created workspace_v2 directory"
}

# PRESERVE COMPILED DLLS: Save GDExtension DLLs before deployment
$tempDllDir = Join-Path $env:TEMP "lenzforge_dlls_backup"
$savedDlls = $false

if (Test-Path $binPath) {
    Write-Host "[INFO] Preserving compiled GDExtension DLLs..." -ForegroundColor Cyan
    
    # Create temp backup directory
    if (Test-Path $tempDllDir) {
        Remove-Item -Recurse -Force $tempDllDir
    }
    New-Item -ItemType Directory -Path $tempDllDir | Out-Null
    
    # Copy all DLL files from bin directory
    $dllFiles = Get-ChildItem -Path $binPath -Filter "*.dll"
    if ($dllFiles.Count -gt 0) {
        foreach ($dll in $dllFiles) {
            Copy-Item $dll.FullName -Destination $tempDllDir
            Write-Host "[OK] Saved: $($dll.Name)" -ForegroundColor Green
        }
        $savedDlls = $true
    } else {
        Write-Host "[INFO] No DLLs found to preserve" -ForegroundColor Gray
    }
}

# Remove old deployment if exists
if (Test-Path $workspacePath) {
    Write-Host "[INFO] Removing old deployment..."
    Remove-Item -Recurse -Force $workspacePath
}

# Copy new deployment
Write-Host "[INFO] Copying LenzForge AR project..."
Copy-Item -Recurse $assetsPath $workspacePath

# RESTORE COMPILED DLLS: Copy preserved DLLs back
if ($savedDlls) {
    Write-Host "[INFO] Restoring compiled GDExtension DLLs..." -ForegroundColor Cyan
    
    # Ensure bin directory exists in new deployment
    $newBinPath = Join-Path $workspacePath "gdextension\bin"
    if (-not (Test-Path $newBinPath)) {
        New-Item -ItemType Directory -Path $newBinPath -Force | Out-Null
    }
    
    # Restore all DLL files
    $restoredDlls = Get-ChildItem -Path $tempDllDir -Filter "*.dll"
    foreach ($dll in $restoredDlls) {
        Copy-Item $dll.FullName -Destination $newBinPath -Force
        Write-Host "[OK] Restored: $($dll.Name)" -ForegroundColor Green
    }
    
    # Clean up temp directory
    Remove-Item -Recurse -Force $tempDllDir -ErrorAction SilentlyContinue
    
    Write-Host "[OK] GDExtension DLLs preserved across deployment!" -ForegroundColor Green
} else {
    Write-Host "[INFO] No compiled DLLs to restore" -ForegroundColor Gray
    Write-Host "[INFO] Run 083-Build-LenzForge-GDExtension.ps1 to build GDExtension" -ForegroundColor Yellow
}

# Copy configuration file to project root (if exists)
$configSource = Join-Path $projectRoot "lenzforge_config.json"
$configTarget = Join-Path $workspacePath "lenzforge_config.json"
if (Test-Path $configSource) {
    Write-Host "[INFO] Copying lenzforge_config.json to Godot project..."
    Copy-Item $configSource $configTarget -Force
    Write-Host "[OK] Config file deployed" -ForegroundColor Gray
} else {
    Write-Host "[WARN] lenzforge_config.json not found in project root" -ForegroundColor Yellow
}

# Copy MinGW runtime DLLs from buildtools to deployed bin directory (if not already present)
$MinGWBin = Join-Path $projectRoot "buildtools\mingw\bin"
$DeployedBin = Join-Path $workspacePath "gdextension\bin"

if (Test-Path $MinGWBin) {
    Write-Host "[INFO] Ensuring MinGW runtime DLLs are present..." -ForegroundColor Cyan
    
    # Ensure bin directory exists
    if (-not (Test-Path $DeployedBin)) {
        New-Item -ItemType Directory -Path $DeployedBin -Force | Out-Null
    }
    
    $mingwDlls = @(
        "libgcc_s_seh-1.dll",
        "libstdc++-6.dll",
        "libwinpthread-1.dll"
    )
    
    foreach ($dll in $mingwDlls) {
        $sourceDll = Join-Path $MinGWBin $dll
        $targetDll = Join-Path $DeployedBin $dll
        
        # Only copy if not already present (from restoration)
        if (-not (Test-Path $targetDll)) {
            if (Test-Path $sourceDll) {
                Copy-Item $sourceDll $targetDll -Force
                Write-Host "[OK] Copied: $dll" -ForegroundColor Green
            } else {
                Write-Host "[WARN] DLL not found: $dll" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[OK] Already present: $dll" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "[WARN] MinGW not found at: $MinGWBin" -ForegroundColor Yellow
    Write-Host "[INFO] MinGW DLLs will be copied during GDExtension build" -ForegroundColor Gray
}

Write-Host "[OK] LenzForge AR deployed!" -ForegroundColor Green
Write-Host "[INFO] Location: $workspacePath"
Write-Host "[INFO] Project file: $workspacePath\project.godot"
Write-Host ""

# Check if GDExtension is ready
$debugDll = Join-Path $DeployedBin "lenzforge.windows.template_debug.x86_64.dll"
$releaseDll = Join-Path $DeployedBin "lenzforge.windows.template_release.x86_64.dll"

if ((Test-Path $debugDll) -and (Test-Path $releaseDll)) {
    Write-Host "[OK] GDExtension compiled and ready!" -ForegroundColor Green
    Write-Host ""
    Write-Host "[INFO] To open in Godot 4.3:"
    Write-Host "  1. Launch Godot 4.3"
    Write-Host "  2. Click 'Import'"
    Write-Host "  3. Select: workspace_v2\LenzForge-AR\project.godot"
} else {
    Write-Host "[WARN] GDExtension not compiled yet" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "[INFO] To build GDExtension:"
    Write-Host "  Run: .\083-Build-LenzForge-GDExtension.ps1"
    Write-Host ""
    Write-Host "[INFO] Then open in Godot 4.3:"
    Write-Host "  1. Launch Godot 4.3"
    Write-Host "  2. Click 'Import'"
    Write-Host "  3. Select: workspace_v2\LenzForge-AR\project.godot"
}
Write-Host ""

exit 0
