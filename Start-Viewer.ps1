param([switch]$Editor)
$ErrorActionPreference = 'Stop'
$versions = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$godot = Join-Path $PSScriptRoot "buildtools\godot-$($versions.godot)\Godot_v$($versions.godot)-stable_win64.exe"
if (-not (Test-Path -LiteralPath $godot)) { throw 'Godot is not installed. Run .\Setup.ps1 first.' }
$viewerArgs = @('--path', (Join-Path $PSScriptRoot 'viewer'))
if ($Editor) { $viewerArgs += '--editor' }
& $godot @viewerArgs
