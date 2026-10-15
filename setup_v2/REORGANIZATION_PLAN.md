# Script Reorganization Plan - 3-Digit Numbering

## Complete Renaming Map

### Main Launcher
- `00-Setup.ps1` → `000-Setup.ps1`

### Group 1: Python Runtime (001-009)
- `01-Download-Python.ps1` → `001-Download-Python.ps1`
- `02-Download-GetPip.ps1` → `002-Download-GetPip.ps1`
- `03-Extract-Python.ps1` → `003-Extract-Python.ps1`
- `04-Setup-Pip.ps1` → `004-Setup-Pip.ps1`
- `05-Install-Packages.ps1` → `005-Install-Packages.ps1`
- `04-Install-Flask-Dependencies.ps1` → **DELETE** (consolidate into 005)

### Group 2: C++ Compiler (010-019) - NEW
- **CREATE** `010-Download-MinGW.ps1`
- **CREATE** `011-Extract-MinGW.ps1`
- **CREATE** `012-Download-WindowsSDK.ps1`
- **CREATE** `013-Extract-WindowsSDK.ps1`

### Group 3: MSMF Extension (020-029)
- `05-Build-MSMF-Extension.ps1` → `020-Build-MSMF-Extension.ps1`
- `05-Build-MSMF-Extension-Verbose.ps1` → Move to `XX-Build-MSMF-Verbose.ps1` (debug)

### Group 4: Backend Deployment (030-039)
- `06-Deploy-Backend.ps1` → `030-Deploy-Backend.ps1`
- `07-Deploy-GUI-Launcher.ps1` → `031-Deploy-GUI-Launcher.ps1`
- `07-Deploy-Documentation.ps1` → `032-Deploy-Documentation.ps1`

### Group 5: C++ Build Tools (040-049)
- `09-Download-CMake.ps1` → `040-Download-CMake.ps1`
- `11-Extract-CMake.ps1` → `041-Extract-CMake.ps1`
- `10-Download-OpenCV-CPP.ps1` → `042-Download-OpenCV-CPP.ps1`
- `12-Extract-OpenCV-CPP.ps1` → `043-Extract-OpenCV-CPP.ps1`

### Group 6: C++ Viewer (050-059)
- `08-Deploy-CPP-Viewer.ps1` → `050-Deploy-CPP-Viewer.ps1`
- `13-Build-CPP-Viewer.ps1` → `051-Build-CPP-Viewer.ps1`

### Group 7: Godot Engine (060-069)
- `14-Download-Godot.ps1` → `060-Download-Godot.ps1`
- `15-Extract-Godot.ps1` → `061-Extract-Godot.ps1`
- `21-Install-Export-Templates.ps1` → `062-Install-Export-Templates.ps1`

### Group 8: Godot-CPP (070-079)
- `17-Download-Godot-CPP.ps1` → `070-Download-Godot-CPP.ps1`
- `18-Extract-Godot-CPP.ps1` → `071-Extract-Godot-CPP.ps1`

### Group 9: GDExtension (080-089)
- `19-Deploy-GDExtension.ps1` → `080-Deploy-GDExtension.ps1`
- `16-Deploy-Godot-Project.ps1` → `081-Deploy-Godot-Project.ps1`
- `20-Build-GDExtension.ps1` → `082-Build-GDExtension.ps1`

### Group 10: Extras (090-099)
- `23-Install-Virtual-Camera.ps1` → `090-Install-Virtual-Camera.ps1`
- `22-Build-Godot-Exe.ps1` → `091-Build-Godot-Exe.ps1`

### Utility Scripts (No Number)
- `07-Run-Web-Server.ps1` → `Run-Web-Server.ps1` (remove number)

### Scripts to Delete/Archive (Duplicates/Obsolete)
- `16-Setup-CPP.ps1` → **DELETE** (obsolete)
- `17-Setup-Godot.ps1` → **DELETE** (obsolete)
- `21-Install-Extension-To-Godot.ps1` → **DELETE** (duplicate)
- `22-Setup-GDExtension.ps1` → **DELETE** (obsolete)
- `24-Install-VirtualCam-Python.ps1` → **DELETE** (duplicate)

### XX- Scripts (NO CHANGES)
- `xx-Backup-Project.ps1` - Keep as-is
- `XX-Test-CPP-System.ps1` - Keep as-is
- `XX-Test-Godot.ps1` - Keep as-is
- `XX-Test.ps1` - Keep as-is

## Summary
- **Rename**: 24 scripts
- **Create NEW**: 4 scripts (MinGW/SDK)
- **Delete**: 5 duplicate/obsolete scripts
- **Move**: 1 script to XX- (verbose debug)
- **Keep Unchanged**: 4 XX- scripts + assets/docs folders

## Execution Order
1. Create backup of current state
2. Create 4 new scripts (010-013)
3. Rename all existing scripts to 3-digit
4. Delete obsolete scripts
5. Update 000-Setup.ps1 references
6. Test dry-run
