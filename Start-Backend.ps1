param([switch]$Demo, [int]$Port = 5000)
$ErrorActionPreference = 'Stop'
$versions = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$python = Join-Path $PSScriptRoot "buildtools\python-$($versions.python)\python.exe"
if (-not (Test-Path -LiteralPath $python)) { throw 'Python is not installed. Run .\Setup.ps1 first.' }
$backendArgs = @('-B', (Join-Path $PSScriptRoot 'backend\run_server.py'), '--port', "$Port")
if ($Demo) { $backendArgs += '--demo' }
& $python @backendArgs
if ($LASTEXITCODE -ne 0) { throw "Backend exited with code $LASTEXITCODE" }
