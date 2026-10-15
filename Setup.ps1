param([switch]$SkipBuild, [switch]$SkipInstall)
$ErrorActionPreference = 'Stop'
$versions = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$pythonDirectory = Join-Path $PSScriptRoot "buildtools\python-$($versions.python)"
$bootstrapPython = Join-Path $pythonDirectory 'python.exe'
if (-not (Test-Path -LiteralPath $bootstrapPython)) {
    New-Item -ItemType Directory -Path $pythonDirectory -Force | Out-Null
    $archive = Join-Path $pythonDirectory 'bootstrap.zip'
    Invoke-WebRequest "https://www.python.org/ftp/python/$($versions.python)/python-$($versions.python)-embed-amd64.zip" -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $pythonDirectory -Force
    Remove-Item -LiteralPath $archive
}
$setupArgs = @((Join-Path $PSScriptRoot 'tools\bootstrap.py'))
if ($SkipBuild) { $setupArgs += '--skip-build' }
if ($SkipInstall) { $setupArgs += '--skip-install' }
& $bootstrapPython @setupArgs
if ($LASTEXITCODE -ne 0) { throw "Setup failed with exit code $LASTEXITCODE" }
