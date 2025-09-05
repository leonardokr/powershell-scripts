<#
.SYNOPSIS
    Creates SMB shares and corresponding DFS namespaces for all folders in a specified path.

.DESCRIPTION
    This script automates the creation of SMB shares and DFS namespaces for all subfolders
    in a specified directory. It includes error handling, logging, and progress reporting.

.PARAMETER BasePath
    The base path containing folders to share. Default is "D:\".

.PARAMETER DomainNamespace
    The DFS domain namespace root. Default is "\\domain.local".

.PARAMETER ServerName
    The server name for DFS targets. Default is current computer name.

.PARAMETER LogPath
    Path for the log file. Default is "C:\Logs".

.PARAMETER EnableDebugMode
    Switch to enable debug mode with detailed logging and timing information.

.EXAMPLE
    .\New-ShareAndDFS.ps1 -BasePath "D:\SharedFolders"
    
    Creates shares and DFS namespaces for all folders in D:\SharedFolders.

.EXAMPLE
    .\New-ShareAndDFS.ps1 -BasePath "E:\Data" -DomainNamespace "\\company.local" -EnableDebugMode
    
    Creates shares with custom domain namespace and enables debug logging.

.NOTES
    File Name      : New-ShareAndDFS.ps1
    Author         : Leonardo Klein Rezende
    Prerequisite   : DFSN PowerShell module, Administrative privileges
    Creation Date  : 2025-09-05
    
    Requires:
    - Administrative privileges
    - DFS Management features installed
    - Domain membership for DFS namespace creation

.LINK
    https://docs.microsoft.com/en-us/powershell/module/dfsn/
    https://docs.microsoft.com/en-us/powershell/module/smbshare/
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory = $false)]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$BasePath = "D:\",
    
    [Parameter(Mandatory = $false)]
    [string]$DomainNamespace = "\\domain.local",
    
    [Parameter(Mandatory = $false)]
    [string]$ServerName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\Logs",
    
    [Parameter(Mandatory = $false)]
    [switch]$EnableDebugMode
)

# Error handling
$ErrorActionPreference = 'Stop'

# Logging function
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        'Info' { Write-Information $logMessage -InformationAction Continue }
        'Warning' { Write-Warning $logMessage }
        'Error' { Write-Error $logMessage }
        'Debug' { if ($EnableDebugMode) { Write-Verbose $logMessage } }
    }
}

function New-SMBShareSafe {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Name,
        [string]$Path,
        [string]$Description = ""
    )
    
    Write-Log "Creating SMB share: $Name" 'Debug'
    
    try {
        $existingShare = Get-SmbShare -Name $Name -ErrorAction SilentlyContinue
        if ($existingShare) {
            Write-Log "SMB share '$Name' already exists" 'Warning'
            return $true
        }
        
        if ($PSCmdlet.ShouldProcess($Name, "Create SMB share")) {
            New-SmbShare -Name $Name -Path $Path -Description $Description -FullAccess "Everyone"
            Write-Log "SMB share '$Name' created successfully" 'Info'
            return $true
        }
    }
    catch {
        Write-Log "Failed to create SMB share '$Name': $($_.Exception.Message)" 'Error'
        return $false
    }
}

function New-DFSNamespaceSafe {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Name,
        [string]$TargetPath,
        [string]$NamespacePath
    )
    
    Write-Log "Creating DFS namespace: $Name" 'Debug'
    
    try {
        $dfsPath = "$NamespacePath\$Name"
        $existingLink = Get-DfsnFolderTarget -Path $dfsPath -ErrorAction SilentlyContinue
        if ($existingLink) {
            Write-Log "DFS link '$dfsPath' already exists" 'Warning'
            return $true
        }
        
        if ($PSCmdlet.ShouldProcess($dfsPath, "Create DFS namespace link")) {
            New-DfsnFolder -Path $dfsPath -TargetPath $TargetPath
            Write-Log "DFS namespace '$dfsPath' created successfully" 'Info'
            return $true
        }
    }
    catch {
        Write-Log "Failed to create DFS namespace '$Name': $($_.Exception.Message)" 'Error'
        return $false
    }
}

# Main execution
try {
    Write-Log "Starting SMB share and DFS namespace creation process" 'Info'
    Write-Log "Base Path: $BasePath" 'Debug'
    Write-Log "Domain Namespace: $DomainNamespace" 'Debug'
    Write-Log "Server Name: $ServerName" 'Debug'
    
    # Verify prerequisites
    if (-not (Get-Module -ListAvailable -Name DFSN)) {
        throw "DFS Management PowerShell module is not available. Please install DFS Management features."
    }
    
    if (-not (Get-Module -ListAvailable -Name SmbShare)) {
        throw "SMB Share PowerShell module is not available."
    }
    
    # Import required modules
    Import-Module DFSN -ErrorAction Stop
    Import-Module SmbShare -ErrorAction Stop
    
    # Get all subdirectories
    $folders = Get-ChildItem -Path $BasePath -Directory -ErrorAction Stop
    
    if ($folders.Count -eq 0) {
        Write-Log "No folders found in $BasePath" 'Warning'
        return
    }
    
    Write-Log "Found $($folders.Count) folders to process" 'Info'
    
    $successCount = 0
    $failureCount = 0
    $results = @()
    
    # Process each folder
    foreach ($folder in $folders) {
        $folderName = $folder.Name
        $folderPath = $folder.FullName
        $shareName = $folderName
        $shareTargetPath = "\\$ServerName\$shareName"
        
        Write-Log "Processing folder: $folderName" 'Info'
        
        try {
            # Create SMB share
            $shareResult = New-SMBShareSafe -Name $shareName -Path $folderPath -Description "Automated share for $folderName"
            
            # Create DFS namespace link
            $dfsResult = New-DFSNamespaceSafe -Name $folderName -TargetPath $shareTargetPath -NamespacePath $DomainNamespace
            
            if ($shareResult -and $dfsResult) {
                $successCount++
                $status = 'Success'
                $message = 'Share and DFS link created successfully'
            }
            else {
                $failureCount++
                $status = 'Partial'
                $message = 'Some operations failed'
            }
        }
        catch {
            $failureCount++
            $status = 'Failed'
            $message = $_.Exception.Message
            Write-Log "Failed to process folder '$folderName': $message" 'Error'
        }
        
        $results += [PSCustomObject]@{
            FolderName = $folderName
            ShareName = $shareName
            FolderPath = $folderPath
            Status = $status
            Message = $message
        }
    }
    
    # Summary
    Write-Log "Processing completed" 'Info'
    Write-Log "Successful: $successCount folders" 'Info'
    Write-Log "Failed: $failureCount folders" 'Info'
    
    # Output results
    Write-Output $results
    
    if ($failureCount -gt 0) {
        Write-Warning "Some operations failed. Check the log for details."
        exit 1
    }
}
catch {
    Write-Log "Process failed: $($_.Exception.Message)" 'Error'
    exit 1
}
