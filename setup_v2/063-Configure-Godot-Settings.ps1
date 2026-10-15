# Configure Godot Editor Settings for Portable Environment
# Sets custom export templates path so Godot uses our portable templates

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Configuring Godot for Portable Mode" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Portable templates location
$PortableTemplatesDir = Join-Path $ProjectRoot "buildtools\godot\export_templates"

# Create Godot editor settings file
$GodotConfigDir = Join-Path $ProjectRoot "buildtools\godot\editor_data"
$EditorSettingsFile = Join-Path $GodotConfigDir "editor_settings-4.tres"

Write-Host "[INFO] Configuring Godot to use portable export templates..." -ForegroundColor Yellow
Write-Host "[INFO] Templates location: $PortableTemplatesDir" -ForegroundColor Gray
Write-Host ""

# Create config directory
New-Item -ItemType Directory -Force -Path $GodotConfigDir | Out-Null

# Create editor settings file with custom templates path
$editorSettings = @"
[gd_resource type="EditorSettings" format=3]

[resource]
export/templates_path = "$($PortableTemplatesDir -replace '\\', '/')"
"@

$editorSettings | Out-File -FilePath $EditorSettingsFile -Encoding UTF8 -Force

Write-Host "[OK] Godot editor settings created" -ForegroundColor Green
Write-Host "[INFO] Settings file: $EditorSettingsFile" -ForegroundColor Gray
Write-Host ""
Write-Host "[INFO] Godot will now use portable export templates" -ForegroundColor Cyan
Write-Host "[INFO] No C: drive dependencies!" -ForegroundColor Green
Write-Host ""

exit 0
