# Active Directory Scripts

Scripts for Active Directory user and object management.

## Scripts

### Get-DeletedUsers.ps1

Exports deleted Active Directory users within a specified date range.

**Features:**

- Configurable date range for deleted user search
- Exports detailed user information to CSV
- Includes display name, UPN, company, and deletion date
- Progress reporting and error handling

**Usage:**

```powershell
# Export users deleted in last 3 months (default)
.\Get-DeletedUsers.ps1

# Export users deleted after specific date
.\Get-DeletedUsers.ps1 -DeletedAfter "2024-01-01" -OutputPath "C:\Reports"
```

### Get-UserLastLogon.ps1

Reports Active Directory user last logon times and group memberships.

**Features:**

- Supports wildcard filtering for user selection
- Option to include or exclude disabled users
- Exports last logon dates and group memberships
- Handles multi-DC environments appropriately

**Usage:**

```powershell
# Get all enabled users
.\Get-UserLastLogon.ps1

# Get specific users including disabled accounts
.\Get-UserLastLogon.ps1 -UserFilter "john.*" -IncludeDisabledUsers
```

### Send-PasswordExpiryNotification.ps1

Automated password expiration notification system for Active Directory users.

**Features:**

- Multilingual support (English and Portuguese)
- HTML email templates with professional design
- Fine-grained password policy support
- Test mode for safe deployment
- Comprehensive logging with CSV export
- Configurable expiration warning period

**Usage:**

```powershell
# Run with specified SMTP server and search base
.\Send-PasswordExpiryNotification.ps1 -SmtpServer "mail.company.com" -FromAddress "noreply@company.com" -SearchBase "OU=Users,DC=domain,DC=com"

# Run in test mode with logging enabled
.\Send-PasswordExpiryNotification.ps1 -SmtpServer "mail.company.com" -FromAddress "noreply@company.com" -SearchBase "OU=Users,DC=domain,DC=com" -TestMode -EnableLogging
```

## Prerequisites

- Active Directory PowerShell module
- Appropriate domain permissions
- PowerShell 5.1 or later

## Notes

- Scripts require domain administrator or equivalent permissions for deleted object queries
- LastLogon attribute may not be accurate in multi-DC environments
- Password notification script needs read access to user attributes
- Always test in non-production environment first
- Review and modify configuration variables before production use
- Ensure SMTP server allows relay from execution host
