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

$ErrorActionPreference = 'Stop'

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Resolve-DumpPath {
    param([string]$Path)
    
    if ($Path.Contains('%')) {
        return $Path
    }
    else {
        return [System.IO.Path]::GetFullPath($Path)
    }
}

try {
    Write-Information "Starting Windows Error Reporting full dump configuration..." -InformationAction Continue
    
    if (-not (Test-Administrator)) {
        throw "This script requires administrator privileges. Please run as administrator."
    }
    
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps"
    Write-Information "Checking registry path: $regPath" -InformationAction Continue
    
    if (-not (Test-Path $regPath)) {
        Write-Information "Registry path does not exist. Creating: $regPath" -InformationAction Continue
        
        if ($PSCmdlet.ShouldProcess($regPath, "Create registry path")) {
            New-Item -Path $regPath -Force | Out-Null
            Write-Information "Registry path created successfully." -InformationAction Continue
        }
    }
    
    $resolvedDumpFolder = Resolve-DumpPath -Path $DumpFolder
    
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
    
    Write-Information "Configuring full dump settings:" -InformationAction Continue
    Write-Verbose "Dump Folder: $resolvedDumpFolder"
    Write-Verbose "Dump Type: Full (2)"
    Write-Verbose "Max Dump Count: $DumpCount"
    
    foreach ($setting in $dumpSettings.GetEnumerator()) {
        $settingName = $setting.Key
        $settingData = $setting.Value
        $settingValue = $settingData.Value
        $settingType = $settingData.Type
        $description = $settingData.Description
        
        Write-Verbose "Configuring $description..."
        
        if ($PSCmdlet.ShouldProcess("$regPath\$settingName", "Set registry value to $settingValue ($settingType)")) {
            try {
                New-ItemProperty -Path $regPath -Name $settingName -Value $settingValue -PropertyType $settingType -Force | Out-Null
                Write-Information "Successfully set $settingName to $settingValue" -InformationAction Continue
            }
            catch {
                Write-Warning "Failed to set $settingName - $($_.Exception.Message)"
            }
        }
    }
    
    Write-Information "Windows Error Reporting full dump collection has been enabled successfully." -InformationAction Continue
    Write-Warning "IMPORTANT INFORMATION:"
    Write-Information "• Full dumps can be very large (potentially GB-sized files)" -InformationAction Continue
    Write-Information "• Ensure sufficient disk space is available in the dump folder" -InformationAction Continue
    Write-Information "• Dumps are created automatically when applications crash" -InformationAction Continue
    Write-Information "• Monitor disk usage regularly to prevent space issues" -InformationAction Continue
    
    if (-not $resolvedDumpFolder.Contains('%')) {
        if (-not (Test-Path $resolvedDumpFolder)) {
            Write-Information "Creating dump folder: $resolvedDumpFolder" -InformationAction Continue
            if ($PSCmdlet.ShouldProcess($resolvedDumpFolder, "Create dump folder")) {
                New-Item -Path $resolvedDumpFolder -ItemType Directory -Force | Out-Null
                Write-Information "Dump folder created successfully." -InformationAction Continue
            }
        }
    }
}
catch {
    Write-Error "An error occurred while configuring full dump collection - $($_.Exception.Message)"
    exit 1
}