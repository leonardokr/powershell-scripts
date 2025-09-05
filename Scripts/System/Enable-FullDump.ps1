<#
.SYNOPSIS
    Enables full memory dump collection for Windows Error Reporting.

.DESCRIPTION
    This script configures Windows Error Reporting (WER) to create full memory dumps
    when applications crash. Full dumps contain complete memory contents and are useful
    for detailed crash analysis and debugging.

.PARAMETER DumpFolder
    The folder where crash dumps will be stored. Default is %LOCALAPPDATA%\CrashDumps.

.PARAMETER DumpCount
    Maximum number of dump files to keep. Default is 50.

.EXAMPLE
    .\Enable-FullDump.ps1
    
    Enables full dump collection with default settings.

.EXAMPLE
    .\Enable-FullDump.ps1 -DumpFolder "C:\Dumps" -DumpCount 100
    
    Enables full dump collection with custom folder and count settings.

.EXAMPLE
    .\Enable-FullDump.ps1 -WhatIf
    
    Shows what registry changes would be made without actually applying them.

.NOTES
    File Name      : Enable-FullDump.ps1
    Author         : Leonardo Klein Rezende
    Prerequisite   : Administrator privileges
    Creation Date  : 2025-09-05
    
    IMPORTANT: This script requires administrator privileges to modify registry settings.
    Full dumps can be very large and consume significant disk space.

.LINK
    https://docs.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory = $false)]
    [string]$DumpFolder = "%LOCALAPPDATA%\CrashDumps",
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000)]
    [int]$DumpCount = 50
)

# Error handling
$ErrorActionPreference = 'Stop'

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Convert dump folder to absolute path if it's not an environment variable
function Resolve-DumpPath {
    param([string]$Path)
    
    if ($Path.Contains('%')) {
        return $Path  # Keep environment variables as-is
    }
    else {
        return [System.IO.Path]::GetFullPath($Path)
    }
}

try {
    Write-Host "Starting Windows Error Reporting full dump configuration..." -ForegroundColor Green
    
    # Verify administrator privileges
    if (-not (Test-Administrator)) {
        throw "This script requires administrator privileges. Please run as administrator."
    }
    
    # Define registry path
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps"
    
    Write-Host "Checking registry path: $regPath" -ForegroundColor Yellow
    
    # Ensure registry path exists
    if (-not (Test-Path $regPath)) {
        Write-Host "Registry path does not exist. Creating: $regPath" -ForegroundColor Yellow
        
        if ($PSCmdlet.ShouldProcess($regPath, "Create registry path")) {
            New-Item -Path $regPath -Force | Out-Null
            Write-Host "Registry path created successfully." -ForegroundColor Green
        }
    }
    
    # Resolve dump folder path
    $resolvedDumpFolder = Resolve-DumpPath -Path $DumpFolder
    
    # Define dump settings
    $dumpSettings = @{
        "DumpFolder" = @{
            Value = $resolvedDumpFolder
            Type = "ExpandString"
            Description = "Crash dump storage location"
        }
        "DumpType" = @{
            Value = 2  # 2 = Full dump
            Type = "DWord"
            Description = "Dump type (2 = Full dump)"
        }
        "DumpCount" = @{
            Value = $DumpCount
            Type = "DWord"
            Description = "Maximum number of dump files to retain"
        }
    }
    
    Write-Host "Configuring full dump settings..." -ForegroundColor Yellow
    Write-Host "  Dump Folder: $resolvedDumpFolder" -ForegroundColor Cyan
    Write-Host "  Dump Type: Full (2)" -ForegroundColor Cyan
    Write-Host "  Max Dump Count: $DumpCount" -ForegroundColor Cyan
    
    # Apply each setting
    foreach ($setting in $dumpSettings.GetEnumerator()) {
        $settingName = $setting.Key
        $settingData = $setting.Value
        $settingValue = $settingData.Value
        $settingType = $settingData.Type
        $description = $settingData.Description
        
        Write-Host "`nConfiguring $description..." -ForegroundColor Yellow
        
        if ($PSCmdlet.ShouldProcess("$regPath\$settingName", "Set registry value to $settingValue ($settingType)")) {
            try {
                New-ItemProperty -Path $regPath -Name $settingName -Value $settingValue -PropertyType $settingType -Force | Out-Null
                Write-Host "  Successfully set $settingName to $settingValue" -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to set $settingName - $($_.Exception.Message)"
            }
        }
    }
    
    Write-Host "`nWindows Error Reporting full dump collection has been enabled successfully." -ForegroundColor Green
    
    # Show important information
    Write-Host "`nIMPORTANT INFORMATION:" -ForegroundColor Yellow
    Write-Host "• Full dumps can be very large (potentially GB-sized files)" -ForegroundColor Cyan
    Write-Host "• Ensure sufficient disk space is available in the dump folder" -ForegroundColor Cyan
    Write-Host "• Dumps are created automatically when applications crash" -ForegroundColor Cyan
    Write-Host "• Monitor disk usage regularly to prevent space issues" -ForegroundColor Cyan
    
    # Create dump folder if it doesn't contain environment variables and doesn't exist
    if (-not $resolvedDumpFolder.Contains('%')) {
        if (-not (Test-Path $resolvedDumpFolder)) {
            Write-Host "`nCreating dump folder: $resolvedDumpFolder" -ForegroundColor Yellow
            if ($PSCmdlet.ShouldProcess($resolvedDumpFolder, "Create dump folder")) {
                New-Item -Path $resolvedDumpFolder -ItemType Directory -Force | Out-Null
                Write-Host "Dump folder created successfully." -ForegroundColor Green
            }
        }
    }
}
catch {
    Write-Error "An error occurred while configuring full dump collection - $($_.Exception.Message)"
    exit 1
}