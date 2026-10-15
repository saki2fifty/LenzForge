# Helper Functions for Dynamic Version Detection
# Used by download scripts to find latest stable releases

function Get-LatestGitHubRelease {
    <#
    .SYNOPSIS
    Gets the latest release from a GitHub repository
    
    .PARAMETER Repo
    Repository in format "owner/repo"
    
    .PARAMETER AssetPattern
    Regex pattern to match asset filename
    
    .PARAMETER FallbackUrl
    URL to use if GitHub API fails
    
    .EXAMPLE
    Get-LatestGitHubRelease "brechtsanders/winlibs_mingw" "x86_64.*posix.*seh.*ucrt.*\.7z$"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Repo,
        
        [Parameter(Mandatory=$true)]
        [string]$AssetPattern,
        
        [Parameter(Mandatory=$false)]
        [string]$FallbackUrl = ""
    )
    
    try {
        $ApiUrl = "https://api.github.com/repos/$Repo/releases/latest"
        Write-Host "[INFO] Querying GitHub API: $Repo" -ForegroundColor Gray
        
        # Query GitHub API
        $Release = Invoke-RestMethod -Uri $ApiUrl -ErrorAction Stop
        
        # Find matching asset
        $Asset = $Release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1
        
        if ($Asset) {
            Write-Host "[OK] Found latest version: $($Release.tag_name)" -ForegroundColor Green
            Write-Host "[OK] Asset: $($Asset.name)" -ForegroundColor Green
            return @{
                Url = $Asset.browser_download_url
                Version = $Release.tag_name
                Name = $Asset.name
                Size = [math]::Round($Asset.size / 1MB, 2)
            }
        } else {
            Write-Host "[WARNING] No matching asset found for pattern: $AssetPattern" -ForegroundColor Yellow
            if ($FallbackUrl) {
                Write-Host "[INFO] Using fallback URL" -ForegroundColor Yellow
                return @{
                    Url = $FallbackUrl
                    Version = "fallback"
                    Name = Split-Path $FallbackUrl -Leaf
                    Size = 0
                }
            }
            return $null
        }
    }
    catch {
        Write-Host "[WARNING] GitHub API query failed: $_" -ForegroundColor Yellow
        if ($FallbackUrl) {
            Write-Host "[INFO] Using fallback URL" -ForegroundColor Yellow
            return @{
                Url = $FallbackUrl
                Version = "fallback"
                Name = Split-Path $FallbackUrl -Leaf
                Size = 0
            }
        }
        return $null
    }
}

function Get-LatestPythonEmbed {
    <#
    .SYNOPSIS
    Gets the latest Python embeddable version
    
    .PARAMETER FallbackVersion
    Version to use if detection fails (e.g., "3.11.0")
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$FallbackVersion = "3.11.0"
    )
    
    try {
        Write-Host "[INFO] Querying Python.org for latest version..." -ForegroundColor Gray
        
        # Scrape python.org downloads page
        $DownloadsPage = Invoke-WebRequest -Uri "https://www.python.org/downloads/windows/" -ErrorAction Stop
        
        # Find embed links (e.g., python-3.12.0-embed-amd64.zip)
        $EmbedLinks = $DownloadsPage.Links | Where-Object {
            $_.href -match "python-(\d+\.\d+\.\d+)-embed-amd64\.zip"
        }
        
        if ($EmbedLinks) {
            $LatestLink = $EmbedLinks | Select-Object -First 1
            $Version = $Matches[1]
            $Url = "https://www.python.org" + $LatestLink.href
            
            Write-Host "[OK] Found latest Python: $Version" -ForegroundColor Green
            return @{
                Url = $Url
                Version = $Version
                Name = "python-$Version-embed-amd64.zip"
                Size = 0
            }
        } else {
            Write-Host "[WARNING] Could not find Python embed version" -ForegroundColor Yellow
            Write-Host "[INFO] Using fallback version: $FallbackVersion" -ForegroundColor Yellow
            return @{
                Url = "https://www.python.org/ftp/python/$FallbackVersion/python-$FallbackVersion-embed-amd64.zip"
                Version = $FallbackVersion
                Name = "python-$FallbackVersion-embed-amd64.zip"
                Size = 0
            }
        }
    }
    catch {
        Write-Host "[WARNING] Python.org query failed: $_" -ForegroundColor Yellow
        Write-Host "[INFO] Using fallback version: $FallbackVersion" -ForegroundColor Yellow
        return @{
            Url = "https://www.python.org/ftp/python/$FallbackVersion/python-$FallbackVersion-embed-amd64.zip"
            Version = $FallbackVersion
            Name = "python-$FallbackVersion-embed-amd64.zip"
            Size = 0
        }
    }
}

function Get-CachedVersion {
    <#
    .SYNOPSIS
    Gets cached version info from downloads directory
    
    .PARAMETER Component
    Component name (e.g., "mingw", "python", "godot")
    
    .PARAMETER CacheFile
    Path to cache file (defaults to downloads/.version_cache.json)
    
    .PARAMETER MaxAgeHours
    Maximum age of cache in hours (default 24)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Component,
        
        [Parameter(Mandatory=$false)]
        [string]$CacheFile = "..\downloads\.version_cache.json",
        
        [Parameter(Mandatory=$false)]
        [int]$MaxAgeHours = 24
    )
    
    if (-not (Test-Path $CacheFile)) {
        return $null
    }
    
    try {
        $Cache = Get-Content $CacheFile -Raw | ConvertFrom-Json
        $Entry = $Cache.$Component
        
        if ($Entry) {
            $CachedTime = [DateTime]::Parse($Entry.timestamp)
            $Age = (Get-Date) - $CachedTime
            
            if ($Age.TotalHours -lt $MaxAgeHours) {
                Write-Host "[INFO] Using cached version info (age: $([math]::Round($Age.TotalHours, 1))h)" -ForegroundColor Gray
                return $Entry
            } else {
                Write-Host "[INFO] Cache expired (age: $([math]::Round($Age.TotalHours, 1))h)" -ForegroundColor Gray
                return $null
            }
        }
    }
    catch {
        Write-Host "[WARNING] Cache read failed: $_" -ForegroundColor Yellow
        return $null
    }
    
    return $null
}

function Set-CachedVersion {
    <#
    .SYNOPSIS
    Caches version info to downloads directory
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Component,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$VersionInfo,
        
        [Parameter(Mandatory=$false)]
        [string]$CacheFile = "..\downloads\.version_cache.json"
    )
    
    try {
        # Ensure downloads directory exists
        $DownloadsDir = Split-Path $CacheFile -Parent
        if (-not (Test-Path $DownloadsDir)) {
            New-Item -ItemType Directory -Path $DownloadsDir -Force | Out-Null
        }
        
        # Load existing cache or create new
        $Cache = @{}
        if (Test-Path $CacheFile) {
            $Cache = Get-Content $CacheFile -Raw | ConvertFrom-Json -AsHashtable
        }
        
        # Add timestamp and save
        $VersionInfo.timestamp = (Get-Date).ToString("o")
        $Cache.$Component = $VersionInfo
        
        $Cache | ConvertTo-Json -Depth 10 | Set-Content $CacheFile -Encoding UTF8
        Write-Host "[OK] Version cached" -ForegroundColor Green
    }
    catch {
        Write-Host "[WARNING] Cache write failed: $_" -ForegroundColor Yellow
    }
}

# Functions are automatically available when dot-sourced
# No Export-ModuleMember needed for dot-sourcing
