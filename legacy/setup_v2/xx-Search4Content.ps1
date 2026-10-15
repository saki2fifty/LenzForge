# Search-Text.ps1
param(
  [Parameter(Mandatory)] [string[]] $Pattern,   # one or more phrases
  [string] $Path = ".",                         # where to search
  [string[]] $Include = @("*"),                 # file globs to include
  [string[]] $Exclude = @()                     # file globs to exclude
)

Get-ChildItem -Path $Path -Recurse -File -Include $Include -Exclude $Exclude -ErrorAction SilentlyContinue |
  Select-String -Pattern $Pattern -SimpleMatch |
  ForEach-Object { '{0}:{1}: {2}' -f $_.Path, $_.LineNumber, $_.Line.Trim() }
