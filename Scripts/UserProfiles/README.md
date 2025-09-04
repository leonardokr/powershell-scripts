# User Profiles Scripts

Scripts for Windows user profile cleanup and maintenance.

## Scripts

### Remove-OrphanedProfiles.ps1
Removes Windows user profiles that no longer have corresponding folders.

**Features:**
- Identifies orphaned profile registry entries
- Report-only mode for safe analysis
- Actual removal mode with confirmation
- Comprehensive logging and CSV reporting
- Excludes system accounts automatically
- Custom SID exclusion support

**Usage:**
```powershell
# Report mode only (safe - no changes made)
.\Remove-OrphanedProfiles.ps1

# Actually remove orphaned profiles
.\Remove-OrphanedProfiles.ps1 -RemoveProfiles

# Exclude specific SIDs from processing
.\Remove-OrphanedProfiles.ps1 -RemoveProfiles -ExcludedSIDs "S-1-5-21-123456789-1001"

# Custom output location
.\Remove-OrphanedProfiles.ps1 -OutputPath "C:\Reports" -LogPath "C:\Logs"
```

**What it does:**
1. Scans Windows profile registry entries
2. Identifies profiles pointing to non-existent folders
3. Identifies .bak profiles (backup/orphaned entries)
4. Generates detailed CSV report
5. Optionally removes orphaned entries from registry

**Report includes:**
- Profile SID
- Profile path
- Folder existence status
- Backup profile indicator
- Profile state information
- Last use time
- Action taken

## Prerequisites

- Administrative privileges (required for registry modification)
- Windows Server or Windows 10/11
- PowerShell 5.1 or later

## Safety Notes

- **ALWAYS run in report mode first** to review what will be removed
- Script modifies Windows registry - ensure system backup exists
- Test thoroughly in non-production environment
- System accounts (S-1-5-18, S-1-5-19, S-1-5-20) are excluded by default

## Warning

This script modifies the Windows registry. Incorrect registry modifications can cause system instability. Always:
1. Create system backup before running
2. Test in non-production environment
3. Review report mode output carefully
4. Run with appropriate administrative privileges
