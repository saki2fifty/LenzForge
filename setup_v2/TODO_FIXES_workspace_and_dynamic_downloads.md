# TODO: Critical Fixes for Setup System

## Issue 1: workspace vs workspace_v2 Confusion

### Problem:
Scripts reference both `/workspace/` and `/workspace_v2/`. Only `workspace_v2/` should exist.

### Files to Check & Fix:

**Setup Scripts:**
- [x] `051-Build-CPP-Viewer.ps1` - FIXED (now deleted)
- [ ] `000-Setup.ps1` - Check for any `workspace` refs
- [ ] `081-Deploy-Godot-Project.ps1` - Check path
- [ ] Any other deploy scripts

**Search Command:**
```powershell
Get-ChildItem setup_v2\*.ps1 -Recurse | Select-String -Pattern "\\workspace[^_]" | Select-Object Path, LineNumber, Line
```

### Action Plan:
1. Search all setup scripts for "workspace" (not workspace_v2)
2. Replace with "workspace_v2"
3. Verify no /workspace directory is ever created

---

## Issue 2: Dynamic Version Detection

### Problem:
Download URLs are hardcoded. Should dynamically find latest stable versions.

### Affected Scripts:

#### `001-Download-Python.ps1`
**Current:** Hardcoded `https://www.python.org/ftp/python/3.11.0/python-3.11.0-embed-amd64.zip`
**Should:** Query https://www.python.org/downloads/ and find latest 3.x embed version
**Method:** Parse HTML or use GitHub API

#### `010-Download-MinGW.ps1`
**Current:** Hardcoded GCC 15.2.0 URL
**Should:** Query GitHub API `https://api.github.com/repos/brechtsanders/winlibs_mingw/releases/latest`
**Method:**
```powershell
$apiUrl = "https://api.github.com/repos/brechtsanders/winlibs_mingw/releases/latest"
$release = Invoke-RestMethod -Uri $apiUrl
$asset = $release.assets | Where-Object { $_.name -match "x86_64-posix-seh.*ucrt.*\.7z$" } | Select-Object -First 1
$downloadUrl = $asset.browser_download_url
```

#### `002-Download-GetPip.ps1`
**Current:** Hardcoded `https://bootstrap.pypa.io/get-pip.py`
**Note:** This URL is stable (redirects to latest), no change needed

#### `060-Download-Godot.ps1`
**Current:** Hardcoded Godot 4.3 URL
**Should:** Query GitHub API `https://api.github.com/repos/godotengine/godot/releases/latest`
**Filter:** Stable releases only (exclude RC, beta, dev)

#### `070-Download-Godot-CPP.ps1`
**Current:** Hardcoded version
**Should:** Match Godot version or use latest tag

#### `012-Download-WindowsSDK.ps1`
**Current:** Hardcoded SDK URL
**Note:** Microsoft doesn't provide API; URL usually stable. May need manual updates.

---

## Implementation Strategy

### Phase 1: Add Version Detection Helper
Create `setup_v2/XX-Get-Latest-Version.ps1` with functions:
```powershell
function Get-LatestGitHubRelease {
    param([string]$Repo, [string]$AssetPattern)
    # Returns latest release URL matching pattern
}

function Get-LatestPythonEmbed {
    # Scrapes python.org for latest 3.x embed
}
```

### Phase 2: Update Download Scripts
Modify each download script to:
1. Try dynamic version detection
2. Fall back to known-good version if detection fails
3. Cache version in `downloads/.version_cache.json`

### Phase 3: Add Version Lock Option
Allow users to lock versions:
```json
// downloads/version_lock.json (optional)
{
    "python": "3.11.0",  // Empty = auto-detect
    "mingw": "",         // Empty = latest
    "godot": "4.3"       // Specific = locked
}
```

---

## Benefits of Dynamic Detection

✅ **Always Current** - Auto-gets latest stable
✅ **Less Maintenance** - No manual URL updates
✅ **Resilient** - Falls back if API fails
✅ **Portable** - Works years from now

---

## Risks & Mitigations

**Risk:** GitHub API rate limits (60 req/hour unauthenticated)
**Mitigation:** Cache results in `downloads/.version_cache.json` for 24 hours

**Risk:** Breaking changes in new versions
**Mitigation:** Version lock file + fallback to tested version

**Risk:** API changes/discontinued
**Mitigation:** Always include fallback hardcoded URL

---

## Example: Smart Download Script

```powershell
# Try dynamic detection
$LatestUrl = Get-LatestGitHubRelease "brechtsanders/winlibs_mingw" "x86_64.*ucrt.*\.7z"

# Fall back to known-good
if (-not $LatestUrl) {
    Write-Host "[INFO] Using fallback version (GCC 15.2.0)" -ForegroundColor Yellow
    $LatestUrl = "https://github.com/brechtsanders/winlibs_mingw/releases/download/..."
}

# Download
Invoke-WebRequest -Uri $LatestUrl -OutFile $Archive
```

---

## Priority

### High Priority (Do First):
1. ✅ Fix workspace vs workspace_v2 (simple find/replace)
2. ⏳ Add dynamic MinGW detection (most likely to break)
3. ⏳ Add dynamic Python detection

### Medium Priority:
4. ⏳ Dynamic Godot detection
5. ⏳ Version cache system

### Low Priority:
6. ⏳ Version lock file
7. ⏳ Windows SDK dynamic (if possible)

---

## Next Steps

1. Search all scripts for "workspace" refs
2. Create version detection helper script
3. Update MinGW download first (test case)
4. Roll out to other downloads
5. Test on fresh machine
6. Document in setup README

---

## Status

- [ ] workspace vs workspace_v2 fixed
- [ ] Dynamic MinGW download
- [ ] Dynamic Python download
- [ ] Dynamic Godot download
- [ ] Version cache system
- [ ] Tested end-to-end
