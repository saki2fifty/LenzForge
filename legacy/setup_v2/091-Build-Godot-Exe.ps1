# Build Godot Project to Windows Executable
param(
    [string]$GodotVersion = "4.3"
)

$ErrorActionPreference = "Stop"

# Handle version format - if it already has "-stable", don't add it again
if ($GodotVersion -like "*-stable") {
    $VersionTag = $GodotVersion
} else {
    $VersionTag = "$GodotVersion-stable"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building Godot $VersionTag Executable" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$GodotExe = "..\buildtools\Godot_v${VersionTag}_win64.exe"
$ProjectPath = "..\workspace_v2\godot-facemesh"
$BuildDir = "..\build"
$OutputExe = "$BuildDir\LenzForge.exe"
$PresetName = "Windows Desktop"

# Check if Godot exists
if (-not (Test-Path $GodotExe)) {
    Write-Host "[ERROR] Godot not found: $GodotExe" -ForegroundColor Red
    Write-Host "[INFO] Available Godot versions:" -ForegroundColor Yellow
    Get-ChildItem "..\buildtools\Godot_*.exe" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor Gray
    }
    Write-Host "[INFO] Please download Godot v$VersionTag first" -ForegroundColor Yellow
    exit 1
}

# Check if project exists
if (-not (Test-Path $ProjectPath)) {
    Write-Host "[ERROR] Godot project not found: $ProjectPath" -ForegroundColor Red
    Write-Host "[INFO] Please run deployment scripts first" -ForegroundColor Yellow
    pause
    exit 1
}

# Create build directory
Write-Host "[INFO] Creating build directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

# Check for export preset
$ExportPresetsFile = Join-Path $ProjectPath "export_presets.cfg"
if (-not (Test-Path $ExportPresetsFile)) {
    Write-Host "[INFO] Creating export preset..." -ForegroundColor Yellow
    
    $ExportPresetContent = @"
[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="../../build/LenzForge.exe"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=false
texture_format/bptc=true
texture_format/s3tc=true
texture_format/etc=false
texture_format/etc2=false
binary_format/architecture="x86_64"
codesign/enable=false
codesign/timestamp=true
codesign/timestamp_server_url=""
codesign/digest_algorithm=1
codesign/description=""
codesign/custom_options=PackedStringArray()
application/modify_resources=true
application/icon=""
application/console_wrapper_icon=""
application/icon_interpolation=4
application/file_version=""
application/product_version=""
application/company_name=""
application/product_name=""
application/file_description=""
application/copyright=""
application/trademarks=""
application/export_angle=0
ssh_remote_deploy/enabled=false
ssh_remote_deploy/host="user@host_ip"
ssh_remote_deploy/port="22"
ssh_remote_deploy/extra_args_ssh=""
ssh_remote_deploy/extra_args_scp=""
ssh_remote_deploy/run_script="Expand-Archive -LiteralPath '{temp_dir}\\{archive_name}' -DestinationPath '{temp_dir}'
`$action = New-ScheduledTaskAction -Execute '{temp_dir}\\{exe_name}' -Argument '{cmd_args}'
`$trigger = New-ScheduledTaskTrigger -Once -At 00:00
`$settings = New-ScheduledTaskSettingsSet
`$task = New-ScheduledTask -Action `$action -Trigger `$trigger -Settings `$settings
Register-ScheduledTask godot_remote_debug -InputObject `$task -Force:$true
Start-ScheduledTask -TaskName godot_remote_debug
while (Get-ScheduledTask -TaskName godot_remote_debug | ? State -eq running) { Start-Sleep -Milliseconds 100 }
Unregister-ScheduledTask -TaskName godot_remote_debug -Confirm:$false -ErrorAction:SilentlyContinue"
ssh_remote_deploy/cleanup_script="Stop-ScheduledTask -TaskName godot_remote_debug -ErrorAction:SilentlyContinue
Unregister-ScheduledTask -TaskName godot_remote_debug -Confirm:$false -ErrorAction:SilentlyContinue
Remove-Item -Recurse -Force '{temp_dir}'"
"@
    
    Set-Content -Path $ExportPresetsFile -Value $ExportPresetContent -Encoding UTF8
    Write-Host "[OK] Export preset created" -ForegroundColor Green
}

# Export the project
Write-Host "[INFO] Exporting Godot project..." -ForegroundColor Yellow
Write-Host "[INFO] This may take a moment..." -ForegroundColor Gray
Write-Host ""

$ExportArgs = @(
    "--headless",
    "--path", $ProjectPath,
    "--export-debug", $PresetName
)

try {
    & $GodotExe $ExportArgs 2>&1 | ForEach-Object {
        if ($_ -match "ERROR") {
            Write-Host $_ -ForegroundColor Red
        } elseif ($_ -match "WARNING") {
            Write-Host $_ -ForegroundColor Yellow
        } else {
            Write-Host $_ -ForegroundColor Gray
        }
    }
    
    if ($LASTEXITCODE -ne 0) {
        throw "Godot export failed with exit code $LASTEXITCODE"
    }
    
    # Check if executable was created
    if (Test-Path $OutputExe) {
        $FileSize = (Get-Item $OutputExe).Length / 1MB
        Write-Host ""
        Write-Host "[SUCCESS] Build complete!" -ForegroundColor Green
        Write-Host "[INFO] Executable: $OutputExe" -ForegroundColor Cyan
        Write-Host "[INFO] Size: $($FileSize.ToString('F2')) MB" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[INFO] You can now:" -ForegroundColor Yellow
        Write-Host "  1. Double-click '$OutputExe' to run" -ForegroundColor Gray
        Write-Host "  2. Move the .exe to any folder (it's portable!)" -ForegroundColor Gray
        Write-Host "  3. Share with others (no Godot needed)" -ForegroundColor Gray
        Write-Host ""
    } else {
        throw "Build completed but executable not found at: $OutputExe"
    }
    
} catch {
    Write-Host ""
    Write-Host "[ERROR] Build failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "[INFO] Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Make sure Godot export templates are installed" -ForegroundColor Gray
    Write-Host "  2. Check that the project opens in Godot Editor" -ForegroundColor Gray
    Write-Host "  3. Try exporting manually in Godot first" -ForegroundColor Gray
    Write-Host ""
    pause
    exit 1
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
exit 0
