# System Scripts

This folder contains PowerShell scripts for managing Windows system settings and configurations.

## Scripts

### Enable-FullDump.ps1
Configures Windows Error Reporting to create full memory dumps when applications crash.

**Purpose:**
- Enables comprehensive crash analysis
- Collects complete memory contents for debugging
- Configures automatic dump collection settings

**Requirements:**
- Administrator privileges
- Windows PowerShell 5.1 or later
- Sufficient disk space for dump files

**Usage:**
```powershell
# Basic usage with default settings
.\Enable-FullDump.ps1

# Custom dump folder and count
.\Enable-FullDump.ps1 -DumpFolder "C:\Dumps" -DumpCount 100

# Preview changes without applying
.\Enable-FullDump.ps1 -WhatIf

# Prompt for confirmation
.\Enable-FullDump.ps1 -Confirm
```

**Parameters:**
- `DumpFolder`: Location where crash dumps are stored (default: %LOCALAPPDATA%\CrashDumps)
- `DumpCount`: Maximum number of dump files to keep (default: 50)

## Important Considerations

### Disk Space Requirements
- Full dumps can be very large (potentially GB-sized files)
- Monitor disk usage regularly to prevent space issues
- Consider implementing cleanup policies for old dumps

### Security and Privacy
- Dump files contain complete memory contents
- May include sensitive information
- Ensure appropriate access controls on dump folders
- Consider encryption for sensitive environments

### Performance Impact
- Minimal impact on normal system operation
- Dump creation occurs only during crashes
- Large applications may take time to generate full dumps

## Use Cases

1. **Application Debugging**: Detailed analysis of application crashes
2. **System Troubleshooting**: Comprehensive memory state analysis
3. **Development Environments**: Enhanced debugging capabilities
4. **Production Monitoring**: Automated crash data collection

## Registry Locations

These scripts modify settings under:
- `HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps`

## Related Microsoft Documentation

- [Collecting User-Mode Dumps](https://docs.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps)
- [Windows Error Reporting](https://docs.microsoft.com/en-us/windows/win32/wer/windows-error-reporting)
