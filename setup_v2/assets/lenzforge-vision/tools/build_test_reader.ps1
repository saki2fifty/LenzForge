# Build test_vid1_reader with static linking (no DLL dependencies)

$ErrorActionPreference = "Stop"

Write-Host "Building test_vid1_reader.exe with static linking..." -ForegroundColor Cyan

# Get MinGW path from buildtools
$mingwBin = "d:\temp\_LenzForge\buildtools\mingw\bin"

if (-not (Test-Path $mingwBin)) {
    Write-Host "ERROR: MinGW not found at $mingwBin" -ForegroundColor Red
    exit 1
}

# Build with static linking to avoid DLL dependencies
& "$mingwBin\g++.exe" -O2 -std=c++17 `
    -static-libgcc -static-libstdc++ -static `
    -o test_vid1_reader.exe `
    test_vid1_reader.cpp

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build failed" -ForegroundColor Red
    exit 1
}

Write-Host "SUCCESS: test_vid1_reader.exe built with static linking" -ForegroundColor Green
Write-Host "No DLL dependencies required!" -ForegroundColor Green
