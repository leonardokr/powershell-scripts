# PowerShell Scripts Collection

[![PowerShell Script Validation](https://github.com/leonardokr/powershell-scripts/actions/workflows/validate.yml/badge.svg)](https://github.com/leonardokr/powershell-scripts/actions/workflows/validate.yml)

A collection of PowerShell scripts for Windows system administration, Active Directory management, and IT automation tasks.

## 📁 Repository Structure

```
Scripts/
├── ActiveDirectory/    # Active Directory user and object management
├── FileSystem/         # File system permissions and auditing
├── NetworkShares/      # SMB shares and DFS namespace management
├── Registry/           # Windows Registry configuration and optimization
├── System/             # System-level configuration and debugging
├── TaskScheduler/      # Scheduled task deployment and management
└── UserProfiles/       # Windows user profile cleanup and maintenance
```

## 🚀 Scripts Overview

### Active Directory
- **Get-DeletedUsers.ps1** - Exports deleted AD users within a specified date range
- **Get-UserLastLogon.ps1** - Reports user last logon times and group memberships
- **Send-PasswordExpiryNotification.ps1** - Password expiration notification for AD users

### File System
- **Get-FolderPermissions.ps1** - Audits folder permissions across multiple servers

### Network Shares
- **New-ShareAndDFS.ps1** - Creates SMB shares and corresponding DFS namespaces

### Registry
- **Disable-LanmanCache.ps1** - Disables LanmanWorkstation cache for network performance

### System
- **Enable-FullDump.ps1** - Configures Windows Error Reporting for full memory dumps
- **Invoke-WindowsUpdateMaintenance.ps1** - Manages Windows Updates across servers during maintenance windows

### Task Scheduler
- **Deploy-ScheduledTasks.ps1** - Deploys scheduled tasks to multiple servers

### User Profiles
- **Remove-OrphanedProfiles.ps1** - Removes Windows user profiles without folders

## 🔧 Prerequisites

- PowerShell 5.1 or later
- Windows Server environment
- Active Directory PowerShell module (for AD scripts)
- DFS Management module (for DFS scripts)
- Appropriate administrative permissions

## 📋 Usage

Each script includes:
- Parameter definitions with validation
- Help documentation
- Error handling
- Logging capabilities
- Progress indicators

To get help for any script:
```powershell
Get-Help .\ScriptName.ps1 -Full
```

## ⚠️ Important Notes

- Always test scripts in a non-production environment first
- Review and modify variables/parameters before execution
- Ensure you have appropriate permissions for the target operations
- Some scripts require domain administrator privileges

## 📝 Configuration

Most scripts include a configuration section at the top with customizable variables:
- Server lists
- Domain settings
- Output paths
- Debug options

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Leonardo Klein Rezende**  
IT Professional specializing in Windows Server and Active Directory administration

---

*These scripts are provided as-is and should be thoroughly tested before use in production environments.*
