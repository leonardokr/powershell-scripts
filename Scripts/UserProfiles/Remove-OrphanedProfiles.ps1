<#
.SYNOPSIS
    Removes Windows user profiles that no longer have corresponding folders.

.DESCRIPTION
    This script identifies and optionally removes Windows user profile registry entries
    that point to non-existent profile folders. This helps clean up orphaned profile
    entries that remain after profile folders have been manually deleted.

.PARAMETER RemoveProfiles
    Switch to actually remove the orphaned profiles. Without this switch, the script
    runs in report-only mode.

.PARAMETER ExcludedSIDs
    Array of SIDs to exclude from processing. System accounts are excluded by default.

.PARAMETER LogPath
    Path for the log file. Default is "C:\Logs".

.PARAMETER OutputPath
    Path for the CSV report. Default is current directory.

.EXAMPLE
    .\Remove-OrphanedProfiles.ps1
    
    Runs in report-only mode, showing orphaned profiles without removing them.

.EXAMPLE
    .\Remove-OrphanedProfiles.ps1 -RemoveProfiles
    
    Actually removes orphaned profile registry entries.

.EXAMPLE
    .\Remove-OrphanedProfiles.ps1 -RemoveProfiles -ExcludedSIDs "S-1-5-21-123456789-1001"
    
    Removes orphaned profiles but excludes the specified SID.

.NOTES
    File Name      : Remove-OrphanedProfiles.ps1
    Author         : Leonardo Klein Rezende
    Prerequisite   : Administrative privileges
    Creation Date  : 2025-09-04
    
    WARNING: This script modifies the Windows registry. Always test in a 
    non-production environment first and ensure you have a system backup.
    
    Requires administrative privileges to modify registry.

.LINK
    https://docs.microsoft.com/en-us/windows/win32/shell/user-profiles
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [switch]$RemoveProfiles,
    
    [Parameter(Mandatory = $false)]
    [string[]]$ExcludedSIDs = @("S-1-5-18", "S-1-5-19", "S-1-5-20"),
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\Logs",
    
    [Parameter(Mandatory = $false)]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$OutputPath = $PWD.Path
)

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script requires administrative privileges. Please run as Administrator."
    exit 1
}

if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$LogFile = Join-Path -Path $LogPath -ChildName "Remove_OrphanedProfiles_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$ReportFile = Join-Path -Path $OutputPath -ChildName "OrphanedProfiles_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

Start-Transcript -Path $LogFile

Write-Information "Starting orphaned profile cleanup..." -InformationAction Continue
$mode = if($RemoveProfiles){'REMOVAL'}else{'REPORT ONLY'}
Write-Information "Mode: $mode" -InformationAction Continue
Write-Information "Report will be saved to: $ReportFile" -InformationAction Continue

$ProfileListPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"

try {
    $ProfilesDirectory = Get-ItemPropertyValue -Path $ProfileListPath -Name "ProfilesDirectory" -ErrorAction Stop
    Write-Information "Profiles directory: $ProfilesDirectory" -InformationAction Continue
}
catch {
    Write-Error "Failed to get profiles directory from registry: $($_.Exception.Message)"
    exit 1
}

$OrphanedProfiles = @()
$ProcessedProfiles = 0
$OrphanedCount = 0
$RemovedCount = 0

try {
    $ProfileEntries = Get-ChildItem -Path $ProfileListPath -ErrorAction Stop | 
                     Where-Object { $_.PSChildName -notin $ExcludedSIDs }
    
    $TotalProfiles = $ProfileEntries.Count
    Write-Information "Found $TotalProfiles user profiles to check (excluding system accounts)." -InformationAction Continue
    
    foreach ($ProfileEntry in $ProfileEntries) {
        $ProcessedProfiles++
        $ProfileSID = $ProfileEntry.PSChildName
        
        Write-Progress -Activity "Checking User Profiles" `
                       -Status "Processing SID: $ProfileSID ($ProcessedProfiles of $TotalProfiles)" `
                       -PercentComplete (($ProcessedProfiles / $TotalProfiles) * 100)
        
        try {
            $ProfilePath = Get-ItemPropertyValue -Path $ProfileEntry.PSPath -Name "ProfileImagePath" -ErrorAction Stop
            
                        $IsBackupProfile = $ProfileSID -like "*.bak"
            
                        $FolderExists = Test-Path -Path $ProfilePath
            
            if ($IsBackupProfile -or -not $FolderExists) {
                $OrphanedCount++
                
                try {
                    $ProfileState = Get-ItemPropertyValue -Path $ProfileEntry.PSPath -Name "State" -ErrorAction SilentlyContinue
                    $LastUseTime = Get-ItemPropertyValue -Path $ProfileEntry.PSPath -Name "ProfileLoadTimeLow" -ErrorAction SilentlyContinue
                }
                catch {
                    $ProfileState = "Unknown"
                    $LastUseTime = "Unknown"
                }
                
                $ProfileInfo = [PSCustomObject]@{
                    SID = $ProfileSID
                    ProfilePath = $ProfilePath
                    FolderExists = $FolderExists
                    IsBackupProfile = $IsBackupProfile
                    ProfileState = $ProfileState
                    LastUseTime = $LastUseTime
                    ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    Action = "None"
                }
                
                if ($RemoveProfiles) {
                    try {
                        Write-Information "Removing orphaned profile: $ProfileSID" -InformationAction Continue
                        Remove-Item -Path $ProfileEntry.PSPath -Recurse -Force -ErrorAction Stop
                        
                        $ProfileInfo.Action = "Removed"
                        $RemovedCount++
                        Write-Information "Successfully removed profile: $ProfileSID" -InformationAction Continue
                    }
                    catch {
                        $ProfileInfo.Action = "Failed to remove: $($_.Exception.Message)"
                        Write-Information "Failed to remove profile $ProfileSID`: $($_.Exception.Message)" -InformationAction Continue
                    }
                } else {
                    $ProfileInfo.Action = "Would be removed (report mode)"
                    Write-Information "Found orphaned profile: $ProfileSID -> $ProfilePath" -InformationAction Continue
                }
                
                $OrphanedProfiles += $ProfileInfo
            }
        }
        catch {
            Write-Warning "Failed to process profile $ProfileSID`: $($_.Exception.Message)"
        }
    }
    
    Write-Progress -Activity "Checking User Profiles" -Completed
    
    if ($OrphanedProfiles.Count -gt 0) {
        $OrphanedProfiles | Export-Csv -Path $ReportFile -NoTypeInformation -Encoding UTF8
        Write-Information "`nReport exported to: $ReportFile" -InformationAction Continue
    }
    
    Write-Information "`n========================================" -InformationAction Continue
    Write-Information "CLEANUP SUMMARY" -InformationAction Continue
    Write-Information "========================================" -InformationAction Continue
    Write-Information "Total profiles checked: $ProcessedProfiles" -InformationAction Continue
    Write-Information "Orphaned profiles found: $OrphanedCount" -InformationAction Continue
    
    if ($RemoveProfiles) {
        Write-Information "Profiles successfully removed: $RemovedCount" -InformationAction Continue
        Write-Information "Profiles failed to remove: $($OrphanedCount - $RemovedCount)" -InformationAction Continue
    } else {
        Write-Information "Run with -RemoveProfiles switch to actually remove orphaned profiles." -InformationAction Continue
    }
    
    if ($OrphanedProfiles.Count -eq 0) {
        Write-Information "No orphaned profiles found!" -InformationAction Continue
    }
}
catch {
    Write-Error "Failed to enumerate profile entries: $($_.Exception.Message)"
    exit 1
}

Write-Information "`nLog saved to: $LogFile" -InformationAction Continue
Write-Information "Script execution completed." -InformationAction Continue

Stop-Transcript





