<#
.SYNOPSIS
    Disables LanmanWorkstation cache settings to improve network performance.

.DESCRIPTION
    This script modifies Windows registry settings to disable various cache mechanisms
    in the LanmanWorkstation service. This can help resolve network performance issues
    and file access problems in some environments, particularly with shared network resources.

.PARAMETER WhatIf
    Shows what would happen if the script runs without actually making changes.

.PARAMETER Confirm
    Prompts for confirmation before making registry changes.

.EXAMPLE
    .\Disable-LanmanCache.ps1
    
    Disables all LanmanWorkstation cache settings.

.EXAMPLE
    .\Disable-LanmanCache.ps1 -WhatIf
    
    Shows what registry changes would be made without actually applying them.

.EXAMPLE
    .\Disable-LanmanCache.ps1 -Confirm
    
    Prompts for confirmation before making each registry change.

.NOTES
    File Name      : Disable-LanmanCache.ps1
    Author         : Leonardo Klein Rezende
    Prerequisite   : Administrator privileges
    Creation Date  : 2025-09-05
    
    IMPORTANT: This script requires administrator privileges to modify registry settings.
    Restart may be required for changes to take effect.

.LINK
    https://docs.microsoft.com/en-us/windows/client-management/troubleshoot-networking
#>

[CmdletBinding(SupportsShouldProcess)]
param (
)

# Error handling
$ErrorActionPreference = 'Stop'

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

try {
    Write-Host "Starting LanmanWorkstation cache disable process..." -ForegroundColor Green
    
    # Verify administrator privileges
    if (-not (Test-Administrator)) {
        throw "This script requires administrator privileges. Please run as administrator."
    }
    
    # Define registry path and values
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
    
    Write-Host "Checking registry path: $regPath" -ForegroundColor Yellow
    
    # Ensure registry path exists
    if (-not (Test-Path $regPath)) {
        Write-Host "Registry path does not exist. Creating: $regPath" -ForegroundColor Yellow
        
        if ($PSCmdlet.ShouldProcess($regPath, "Create registry path")) {
            New-Item -Path $regPath -Force | Out-Null
            Write-Host "Registry path created successfully." -ForegroundColor Green
        }
    }
    
    # Define cache settings to disable
    $cacheSettings = @{
        "DirectoryCacheLifetime"      = 0
        "FileNotFoundCacheLifetime"   = 0
        "FileInfoCacheLifetime"       = 0
        "FileNotFoundCacheEntriesMax" = 0
        "FileInfoCacheEntriesMax"     = 0
    }
    
    Write-Host "Applying cache disable settings..." -ForegroundColor Yellow
    
    # Apply each setting
    foreach ($setting in $cacheSettings.GetEnumerator()) {
        $settingName = $setting.Key
        $settingValue = $setting.Value
        
        Write-Host "  Setting $settingName = $settingValue" -ForegroundColor Cyan
        
        if ($PSCmdlet.ShouldProcess("$regPath\$settingName", "Set registry value to $settingValue")) {
            try {
                New-ItemProperty -Path $regPath -Name $settingName -Value $settingValue -PropertyType DWord -Force | Out-Null
                Write-Host "    Successfully set $settingName to $settingValue" -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to set $settingName - $($_.Exception.Message)"
            }
        }
    }
    
    Write-Host "`nLanmanWorkstation cache settings have been disabled successfully." -ForegroundColor Green
    Write-Host "IMPORTANT: A system restart may be required for changes to take effect." -ForegroundColor Yellow
    
    # Offer to restart
    if (-not $WhatIf) {
        $restart = Read-Host "`nWould you like to restart the computer now? (y/N)"
        if ($restart -eq 'y' -or $restart -eq 'Y') {
            Write-Host "Initiating system restart..." -ForegroundColor Yellow
            Restart-Computer -Force
        }
    }
}
catch {
    Write-Error "An error occurred while disabling LanmanWorkstation cache - $($_.Exception.Message)"
    exit 1
}
