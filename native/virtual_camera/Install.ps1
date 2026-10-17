param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'
$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run this script once from an Administrator PowerShell to register the LenzForge camera component.' }
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$source = Join-Path $repo 'viewer/gdextension/bin/LenzForgeCamera.dll'
$directory = Join-Path $env:ProgramFiles 'LenzForge/VirtualCamera'
$destination = Join-Path $directory 'LenzForgeCamera.dll'
$key = 'HKLM:/SOFTWARE/Classes/CLSID/{A7CBB740-1ED1-49F1-9444-90A2EAD037D6}'
if ($Uninstall) {
    if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }
    # Remove only the named component, never an entire computed directory tree.
    if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Force }
    Write-Host 'LenzForge camera component removed. Close existing camera clients to release their session.'
    exit
}
if ([Environment]::OSVersion.Version.Build -lt 22000) { throw 'LenzForge Virtual Camera requires Windows 11 (build 22000 or newer).' }
if (-not (Test-Path -LiteralPath $source)) { throw 'Build the camera first with native/virtual_camera/build.ps1.' }
New-Item -ItemType Directory -Force $directory | Out-Null
Copy-Item -LiteralPath $source -Destination $destination -Force
New-Item -Path "$key/InprocServer32" -Force | Out-Null
Set-Item -LiteralPath $key -Value 'LenzForge Virtual Camera'
Set-Item -LiteralPath "$key/InprocServer32" -Value $destination
New-ItemProperty -LiteralPath "$key/InprocServer32" -Name ThreadingModel -Value Both -PropertyType String -Force | Out-Null
Write-Host 'Installed LenzForge Virtual Camera. Use the camera button in the studio toolbar to start output.'
