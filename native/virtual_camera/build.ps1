param([switch]$Test)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) { throw 'Install Visual Studio Build Tools with Desktop development with C++ and the Windows 11 SDK.' }
$vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'Visual Studio C++ build tools are missing.' }
$sdk = '10.0.26100.0'
if (-not (Test-Path -LiteralPath (Join-Path ${env:ProgramFiles(x86)} "Windows Kits/10/Include/$sdk/um/mfvirtualcamera.h"))) { throw "Windows SDK $sdk is required." }
$out = Join-Path $repo 'artifacts/virtual-camera-build'
$bin = Join-Path $repo 'viewer/gdextension/bin'
New-Item -ItemType Directory -Force $out,$bin | Out-Null
$developer = Join-Path $vs 'Common7/Tools/Launch-VsDevShell.ps1'
& $developer -Arch amd64 -HostArch amd64 -SkipAutomaticLocation | Out-Null
$flags = @('/nologo','/std:c++17','/O2','/EHsc','/MT','/W4','/DUNICODE','/D_UNICODE','/DWIN32_LEAN_AND_MEAN','/D_WIN32_WINNT=0x0A00',"/I$PSScriptRoot")
Push-Location $out
try {
    $source = @('activation.cpp','media_source.cpp','output.cpp') | ForEach-Object { Join-Path $PSScriptRoot $_ }
    & cl.exe @flags /LD @source "/Fe$bin/LenzForgeCamera.dll" /link "/DEF:$PSScriptRoot/camera.def" mfplat.lib mf.lib mfuuid.lib mfsensorgroup.lib ole32.lib advapi32.lib uuid.lib /INCREMENTAL:NO /DYNAMICBASE /NXCOMPAT
    if ($LASTEXITCODE) { throw 'Virtual camera build failed.' }
    & cl.exe @flags (Join-Path $PSScriptRoot 'probe.cpp') (Join-Path $PSScriptRoot 'media_source.cpp') "/Fe$out/LenzForgeCameraProbe.exe" /link mfplat.lib mf.lib mfreadwrite.lib mfuuid.lib mfsensorgroup.lib ole32.lib advapi32.lib uuid.lib /INCREMENTAL:NO
    if ($LASTEXITCODE) { throw 'Virtual camera probe build failed.' }
    if ($Test) {
        & "$out/LenzForgeCameraProbe.exe" --self-test
        if ($LASTEXITCODE) { throw 'Virtual camera source self-test failed.' }
        & "$out/LenzForgeCameraProbe.exe" --component "$bin/LenzForgeCamera.dll"
        if ($LASTEXITCODE) { throw 'Virtual camera COM component test failed.' }
    }
} finally { Pop-Location }
