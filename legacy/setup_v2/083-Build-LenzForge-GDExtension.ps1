# Build LenzForge GDExtension for Godot AR
# Part of LenzForge setup system

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Build LenzForge GDExtension" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$GDExtensionDir = Join-Path $ProjectRoot "workspace_v2\LenzForge-AR\gdextension"
$LenzForgeSrc = Join-Path $GDExtensionDir "lenzforge"
$MinGWBin = Join-Path $ProjectRoot "buildtools\mingw\bin"
$PythonScripts = Join-Path $ProjectRoot "buildtools\python\Scripts"

# Check if GDExtension source exists
if (-not (Test-Path $GDExtensionDir)) {
    Write-Host "[ERROR] GDExtension directory not found: $GDExtensionDir" -ForegroundColor Red
    Write-Host "[INFO] Please run: .\081-Deploy-Godot-Project.ps1" -ForegroundColor Yellow
    exit 1
}

# Check for MinGW
if (-not (Test-Path "$MinGWBin\g++.exe")) {
    Write-Host "[ERROR] MinGW compiler not found!" -ForegroundColor Red
    Write-Host "[INFO] Please run setup scripts 010-011 to install MinGW" -ForegroundColor Yellow
    exit 1
}

# Check for SCons
if (-not (Test-Path "$PythonScripts\scons.exe")) {
    Write-Host "[ERROR] SCons not found!" -ForegroundColor Red
    Write-Host "[INFO] Installing SCons..." -ForegroundColor Yellow
    $PythonExe = Join-Path $ProjectRoot "buildtools\python\python.exe"
    & $PythonExe -m pip install scons
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to install SCons" -ForegroundColor Red
        exit 1
    }
}

Write-Host "[INFO] Building LenzForge GDExtension..." -ForegroundColor Cyan
Write-Host "[INFO] Source: $LenzForgeSrc" -ForegroundColor Gray
Write-Host ""

# Add MinGW to PATH
$env:PATH = "$MinGWBin;$env:PATH"

# Verify compiler
try {
    $gccVersion = & "$MinGWBin\g++.exe" --version 2>&1 | Select-Object -First 1
    Write-Host "[OK] GCC: $gccVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] GCC not accessible" -ForegroundColor Red
    exit 1
}

# Ensure bin directory exists and is a directory
$BinDir = Join-Path $GDExtensionDir "bin"
if (Test-Path $BinDir) {
    $item = Get-Item $BinDir
    if (-not $item.PSIsContainer) {
        Write-Host "[INFO] Removing old 'bin' file..." -ForegroundColor Yellow
        Remove-Item $BinDir -Force
        New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    }
} else {
    Write-Host "[INFO] Creating bin directory..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
}

# Clean any stale build artifacts
Write-Host "[INFO] Cleaning stale build artifacts..." -ForegroundColor Cyan
$srcDir = Join-Path $LenzForgeSrc "src"
if (Test-Path $srcDir) {
    Remove-Item "$srcDir\*.o" -Force -ErrorAction SilentlyContinue
}
Remove-Item "$LenzForgeSrc\.sconsign.dblite" -Force -ErrorAction SilentlyContinue
Write-Host "[OK] Build artifacts cleaned" -ForegroundColor Green

# Change to lenzforge directory
Push-Location $LenzForgeSrc

try {
    Write-Host "[INFO] Running SCons build (DEBUG)..." -ForegroundColor Cyan
    Write-Host "[INFO] This may take 2-3 minutes..." -ForegroundColor Yellow
    Write-Host ""
    
    # Build DEBUG version
    $process = Start-Process -FilePath "$PythonScripts\scons.exe" -ArgumentList "platform=windows target=template_debug" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\scons_output.txt" -RedirectStandardError "$env:TEMP\scons_error.txt"
    
    # Show progress while building
    $spinner = @('|', '/', '-', '\')
    $spinnerIndex = 0
    Write-Host -NoNewline "Building DEBUG "
    
    while (-not $process.HasExited) {
        Write-Host -NoNewline "`r$($spinner[$spinnerIndex]) Building DEBUG... " -ForegroundColor Cyan
        $spinnerIndex = ($spinnerIndex + 1) % $spinner.Length
        Start-Sleep -Milliseconds 200
    }
    
    Write-Host "`r DEBUG build complete!     " -ForegroundColor Green
    Write-Host ""
    
    # Get the exit code
    $LASTEXITCODE = $process.ExitCode
    
    # Show any errors
    if ($LASTEXITCODE -ne 0) {
        $errors = Get-Content "$env:TEMP\scons_error.txt" -ErrorAction SilentlyContinue
        if ($errors) {
            Write-Host "[ERROR] DEBUG build errors:" -ForegroundColor Red
            Write-Host $errors -ForegroundColor Red
        }
        Pop-Location
        exit 1
    }
    
    # Check debug output
    $debugDllPath = "..\bin\lenzforge.windows.template_debug.x86_64.dll"
    if (Test-Path $debugDllPath) {
        $size = (Get-Item $debugDllPath).Length
        $sizeMB = "{0:N2} MB" -f ($size / 1MB)
        Write-Host "[OK] DEBUG DLL created: $sizeMB" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "[INFO] Running SCons build (RELEASE)..." -ForegroundColor Cyan
    Write-Host "[INFO] This may take 2-3 minutes..." -ForegroundColor Yellow
    Write-Host ""
    
    # Build RELEASE version
    $process = Start-Process -FilePath "$PythonScripts\scons.exe" -ArgumentList "platform=windows target=template_release" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\scons_output.txt" -RedirectStandardError "$env:TEMP\scons_error.txt"
    
    # Show progress while building
    $spinnerIndex = 0
    Write-Host -NoNewline "Building RELEASE "
    
    while (-not $process.HasExited) {
        Write-Host -NoNewline "`r$($spinner[$spinnerIndex]) Building RELEASE... " -ForegroundColor Cyan
        $spinnerIndex = ($spinnerIndex + 1) % $spinner.Length
        Start-Sleep -Milliseconds 200
    }
    
    Write-Host "`r RELEASE build complete!     " -ForegroundColor Green
    Write-Host ""
    
    # Get the exit code
    $LASTEXITCODE = $process.ExitCode
    
    # Show any errors
    if ($LASTEXITCODE -ne 0) {
        $errors = Get-Content "$env:TEMP\scons_error.txt" -ErrorAction SilentlyContinue
        if ($errors) {
            Write-Host "[ERROR] RELEASE build errors:" -ForegroundColor Red
            Write-Host $errors -ForegroundColor Red
        }
        Pop-Location
        exit 1
    }
    
    # Check release output
    $releaseDllPath = "..\bin\lenzforge.windows.template_release.x86_64.dll"
    if (Test-Path $releaseDllPath) {
        $size = (Get-Item $releaseDllPath).Length
        $sizeMB = "{0:N2} MB" -f ($size / 1MB)
        Write-Host "[OK] RELEASE DLL created: $sizeMB" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "[SUCCESS] LenzForge extension built successfully (DEBUG + RELEASE)!" -ForegroundColor Green
    
    # Check both outputs exist
    if ((Test-Path $debugDllPath) -and (Test-Path $releaseDllPath)) {
        Write-Host "[INFO] Location: workspace_v2\LenzForge-AR\gdextension\bin\" -ForegroundColor Cyan
        
        # Copy MinGW runtime DLLs to bin directory
        Write-Host ""
        Write-Host "[INFO] Copying MinGW runtime DLLs..." -ForegroundColor Cyan
        $mingwDlls = @(
            "libgcc_s_seh-1.dll",
            "libstdc++-6.dll",
            "libwinpthread-1.dll"
        )
        
        foreach ($dll in $mingwDlls) {
            $sourceDll = Join-Path $MinGWBin $dll
            $targetDll = Join-Path $BinDir $dll
            if (Test-Path $sourceDll) {
                Copy-Item $sourceDll $targetDll -Force
                Write-Host "[OK] Copied: $dll" -ForegroundColor Green
            } else {
                Write-Host "[WARN] DLL not found: $dll" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "[WARNING] One or both DLL files not found" -ForegroundColor Yellow
    }
} catch {
    Write-Host ""
    Write-Host "[ERROR] Build failed: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}

Pop-Location

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  LenzForge GDExtension Built" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "The Godot project is now ready!" -ForegroundColor Cyan

exit 0
