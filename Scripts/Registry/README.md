# Registry Scripts

This folder contains PowerShell scripts for managing Windows Registry settings.

## Scripts

### Disable-LanmanCache.ps1
Disables LanmanWorkstation cache settings to improve network performance.

**Purpose:**
- Resolves network performance issues
- Fixes file access problems with shared resources
- Disables various cache mechanisms in LanmanWorkstation service

**Requirements:**
- Administrator privileges
- Windows PowerShell 5.1 or later

**Usage:**
```powershell
# Basic usage
.\Disable-LanmanCache.ps1

# Preview changes without applying
.\Disable-LanmanCache.ps1 -WhatIf

# Prompt for confirmation
.\Disable-LanmanCache.ps1 -Confirm
```

**Note:** System restart may be required for changes to take effect.

## Common Use Cases

1. **Network Performance Issues**: When experiencing slow file access over network shares
2. **File Locking Problems**: When files appear locked or inaccessible on network drives
3. **Cache Corruption**: When cached information causes inconsistent behavior

## Safety Notes

- Always test changes in a non-production environment first
- Create registry backups before making modifications
- Verify changes with appropriate testing procedures
- Monitor system behavior after applying registry changes

## Registry Locations

These scripts primarily modify settings under:
- `HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters`
