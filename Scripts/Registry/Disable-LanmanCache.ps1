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

$ErrorActionPreference = 'Stop'

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

try {
    Write-Information "Starting LanmanWorkstation cache disable process..." -InformationAction Continue
    
    if (-not (Test-Administrator)) {
        throw "This script requires administrator privileges. Please run as administrator."
    }
    
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
    Write-Information "Checking registry path: $regPath" -InformationAction Continue
    
    if (-not (Test-Path $regPath)) {
        Write-Information "Registry path does not exist. Creating: $regPath" -InformationAction Continue
        
        if ($PSCmdlet.ShouldProcess($regPath, "Create registry path")) {
            New-Item -Path $regPath -Force | Out-Null
            Write-Information "Registry path created successfully." -InformationAction Continue
        }
    }
    
    $cacheSettings = @{
        "DirectoryCacheLifetime"      = 0
        "FileNotFoundCacheLifetime"   = 0
        "FileInfoCacheLifetime"       = 0
        "FileNotFoundCacheEntriesMax" = 0
        "FileInfoCacheEntriesMax"     = 0
    }
    
    Write-Information "Applying cache disable settings..." -InformationAction Continue
    
    foreach ($setting in $cacheSettings.GetEnumerator()) {
        $settingName = $setting.Key
        $settingValue = $setting.Value
        
        Write-Verbose "Setting $settingName = $settingValue"
        
        if ($PSCmdlet.ShouldProcess("$regPath\$settingName", "Set registry value to $settingValue")) {
            try {
                New-ItemProperty -Path $regPath -Name $settingName -Value $settingValue -PropertyType DWord -Force | Out-Null
                Write-Information "Successfully set $settingName to $settingValue" -InformationAction Continue
            }
            catch {
                Write-Warning "Failed to set $settingName - $($_.Exception.Message)"
            }
        }
    }
    
    Write-Information "LanmanWorkstation cache settings have been disabled successfully." -InformationAction Continue
    Write-Warning "IMPORTANT: A system restart may be required for changes to take effect."
    
    if (-not $WhatIf) {
        $restart = Read-Host "`nWould you like to restart the computer now? (y/N)"
        if ($restart -eq 'y' -or $restart -eq 'Y') {
            Write-Information "Initiating system restart..." -InformationAction Continue
            Restart-Computer -Force
        }
    }
}
catch {
    Write-Error "An error occurred while disabling LanmanWorkstation cache - $($_.Exception.Message)"
    exit 1
}



