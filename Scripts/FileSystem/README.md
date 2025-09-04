# File System Scripts

Scripts for file system permissions auditing and management.

## Scripts

### Get-FolderPermissions.ps1
Audits folder permissions across multiple servers and exports results to CSV.

**Features:**
- Multi-server permission auditing
- Configurable recursion depth
- Comprehensive permission reporting including inheritance
- Progress reporting and connectivity testing
- CSV export with timestamp

**Usage:**
```powershell
# Audit specific servers
.\Get-FolderPermissions.ps1 -ServerList "server01","server02"

# Audit with limited recursion depth
.\Get-FolderPermissions.ps1 -ServerList "server01" -BasePath "c$\Data" -MaxDepth 2

# Export to specific location
.\Get-FolderPermissions.ps1 -ServerList "server01" -OutputPath "C:\Reports"
```

**Output includes:**
- Server name
- Full folder path
- Identity (user/group)
- Permissions (FileSystemRights)
- Access control type (Allow/Deny)
- Inheritance status
- Scan timestamp

## Prerequisites

- Administrative access to target servers
- Network connectivity to target servers
- PowerShell 5.1 or later

## Notes

- Large folder structures may take considerable time to process
- Use MaxDepth parameter to limit recursion for performance
- Script includes connectivity testing before processing each server
