# Network Shares Scripts

Scripts for SMB share creation and DFS namespace management.

## Scripts

### New-ShareAndDFS.ps1
Creates SMB shares and corresponding DFS namespaces for all folders in a specified path.

**Features:**
- Automated SMB share creation
- DFS namespace creation with domain integration
- Comprehensive error handling and logging
- Progress reporting with statistics
- Debug mode with performance timing
- Checks for existing shares/namespaces

**Usage:**
```powershell
# Create shares for all folders in D:\
.\New-ShareAndDFS.ps1

# Custom configuration
.\New-ShareAndDFS.ps1 -BasePath "E:\SharedFolders" -DomainNamespace "\\company.local" -EnableDebugMode

# With custom logging
.\New-ShareAndDFS.ps1 -LogPath "D:\Logs" -EnableDebugMode
```

**Process:**
1. Scans specified base path for directories
2. Creates SMB share for each directory
3. Creates corresponding DFS namespace entry
4. Provides detailed progress and error reporting

## Prerequisites

- Administrative privileges on target server
- DFS Management features installed
- Domain membership for DFS namespace creation
- DFSN and SmbShare PowerShell modules

## Notes

- Script automatically handles existing shares/namespaces
- DFS namespaces are created as DomainV2 type
- All shares are created with "Everyone" full access (modify as needed)
- Comprehensive logging available in debug mode
