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
    Creation Date  : 2025-09-04
    
    Requires:
    - Administrative privileges
    - DFS Management features installed
    - Domain membership for DFS namespace creation

.LINK
    https://docs.microsoft.com/en-us/powershell/module/dfsn/
    https://docs.microsoft.com/en-us/powershell/module/smbshare/
#>

[CmdletBinding()]
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

# Ensure log directory exists
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$LogFile = Join-Path -Path $LogPath -ChildName "ShareDFSCreation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

if ($EnableDebugMode) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    Start-Transcript -Path $LogFile
}

# Import required modules
try {
    Import-Module DFSN -ErrorAction Stop
    Write-Host "DFS Namespace module loaded successfully." -ForegroundColor Green
}
catch {
    Write-Error "Failed to load DFSN module. Please ensure DFS Management features are installed."
    exit 1
}

try {
    Import-Module SmbShare -ErrorAction Stop
    Write-Host "SMB Share module loaded successfully." -ForegroundColor Green
}
catch {
    Write-Error "Failed to load SmbShare module."
    exit 1
}

function Write-ColorMessage {
    <#
    .SYNOPSIS
        Writes colored messages to the console.
    #>
    param (
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    Write-Host $Message -ForegroundColor $Color
}

function New-SMBShareSafe {
    <#
    .SYNOPSIS
        Creates an SMB share with error handling.
    #>
    param (
        [string]$FolderPath,
        [string]$ShareName
    )
    
    $existingShare = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
    if ($null -eq $existingShare) {
        Write-ColorMessage "`n======== Creating share '$ShareName' for path '$FolderPath'... ========" -Color DarkGray
        try {
            New-SmbShare -Name $ShareName -Path $FolderPath -FullAccess "Everyone" -ErrorAction Stop
            Write-ColorMessage "Share '$ShareName' created successfully." -Color Green
            return $true
        }
        catch {
            Write-ColorMessage "Error creating share '$ShareName': $($_.Exception.Message)" -Color Red
            return $false
        }
    }
    else {
        Write-ColorMessage "Share '$ShareName' already exists." -Color Yellow
        return $true
    }
}

function New-DFSNamespaceSafe {
    <#
    .SYNOPSIS
        Creates a DFS namespace with error handling.
    #>
    param (
        [string]$NamespaceName,
        [string]$TargetPath
    )

    $namespacePath = "$DomainNamespace\$NamespaceName"

    $nsExists = Get-DfsnRoot -Path $namespacePath -ErrorAction SilentlyContinue
    if ($null -eq $nsExists) {
        Write-ColorMessage "Creating DFS namespace: '$namespacePath'..." -Color DarkGray
        try {
            New-DfsnRoot -Type DomainV2 -Path $namespacePath -TargetPath $TargetPath -ErrorAction Stop
            Write-ColorMessage "DFS namespace '$namespacePath' created successfully." -Color Green
            return $true
        }
        catch {
            Write-ColorMessage "Error creating DFS namespace '$namespacePath': $($_.Exception.Message)" -Color Red
            return $false
        }
    }
    else {
        Write-ColorMessage "DFS namespace '$namespacePath' already exists." -Color Yellow
        return $true
    }
}

# Main execution
Write-ColorMessage "Starting share and DFS creation process..." -Color Cyan
Write-ColorMessage "Base path: $BasePath" -Color Gray
Write-ColorMessage "Domain namespace: $DomainNamespace" -Color Gray
Write-ColorMessage "Server name: $ServerName" -Color Gray

try {
    $folders = Get-ChildItem -Path $BasePath -Directory -ErrorAction Stop
    $totalFolders = $folders.Count
    $processedFolders = 0
    $successCount = 0
    $errorCount = 0

    if ($totalFolders -eq 0) {
        Write-ColorMessage "No folders found in $BasePath" -Color Yellow
        exit 0
    }

    Write-ColorMessage "Found $totalFolders folders to process." -Color White

    foreach ($folder in $folders) {
        $processedFolders++
        $folderName = $folder.Name
        $folderPath = $folder.FullName

        Write-Progress -Activity "Creating Shares and DFS Namespaces" `
                       -Status "Processing folder: $folderName ($processedFolders of $totalFolders)" `
                       -PercentComplete (($processedFolders / $totalFolders) * 100)

        Write-ColorMessage "`nProcessing folder: $folderName" -Color White

        # Create SMB Share
        $shareSuccess = New-SMBShareSafe -FolderPath $folderPath -ShareName $folderName

        if ($shareSuccess) {
            # Create DFS Namespace
            $targetPath = "\\$ServerName.$($DomainNamespace.Split('\')[2])\$folderName"
            $dfsSuccess = New-DFSNamespaceSafe -NamespaceName $folderName -TargetPath $targetPath
            
            if ($shareSuccess -and $dfsSuccess) {
                $successCount++
            } else {
                $errorCount++
            }
        } else {
            $errorCount++
        }
    }

    Write-Progress -Activity "Creating Shares and DFS Namespaces" -Completed

    Write-ColorMessage "`n========== Summary ==========" -Color Cyan
    Write-ColorMessage "Total folders processed: $totalFolders" -Color White
    Write-ColorMessage "Successful operations: $successCount" -Color Green
    Write-ColorMessage "Failed operations: $errorCount" -Color Red
}
catch {
    Write-Error "Failed to enumerate folders in $BasePath`: $($_.Exception.Message)"
    exit 1
}

if ($EnableDebugMode) {
    $watch.Stop()
    Write-ColorMessage "`nThe execution took $($watch.Elapsed) to run" -Color Gray
    Write-ColorMessage "PID of this process: $([System.Diagnostics.Process]::GetCurrentProcess().Id)" -Color Gray
    Write-ColorMessage "Log saved to: $LogFile" -Color Gray
    Stop-Transcript
}

Write-ColorMessage "`nScript execution completed." -Color Cyan
