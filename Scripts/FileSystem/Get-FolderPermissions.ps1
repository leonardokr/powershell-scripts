<#
.SYNOPSIS
    Audits folder permissions across multiple servers and exports results to CSV.

.DESCRIPTION
    This script scans specified servers for folder permissions and generates a comprehensive
    report including server name, folder path, identity, permissions, and inheritance status.

.PARAMETER ServerList
    Array of server names to audit. Can be provided as comma-separated values.

.PARAMETER BasePath
    The base path to scan on each server. Default is "d$\" (D: drive).

.PARAMETER OutputPath
    The path where the CSV report will be saved. Default is current directory.

.PARAMETER FileName
    The name of the output CSV file. Default is "FolderPermissions_YYYYMMDD.csv".

.PARAMETER MaxDepth
    Maximum recursion depth for folder scanning. Default is unlimited (-1).

.EXAMPLE
    .\Get-FolderPermissions.ps1 -ServerList "server01","server02"
    
    Audits folder permissions on server01 and server02.

.EXAMPLE
    .\Get-FolderPermissions.ps1 -ServerList "server01" -BasePath "c$\Data" -MaxDepth 2
    
    Audits permissions on C:\Data with maximum 2 levels of recursion.

.NOTES
    File Name      : Get-FolderPermissions.ps1
    Author         : Leonardo Klein Rezende
    Prerequisite   : PowerShell remoting and administrative access to target servers
    Creation Date  : 2025-09-04
    
    Requires administrative privileges on target servers.
    Large folder structures may take considerable time to process.

.LINK
    https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-acl
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string[]]$ServerList,
    
    [Parameter(Mandatory = $false)]
    [string]$BasePath = "d$\",
    
    [Parameter(Mandatory = $false)]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$OutputPath = $PWD.Path,
    
    [Parameter(Mandatory = $false)]
    [string]$FileName = "FolderPermissions_$(Get-Date -Format 'yyyyMMdd').csv",
    
    [Parameter(Mandatory = $false)]
    [int]$MaxDepth = -1
)

# Construct full output path
$OutputFilePath = Join-Path -Path $OutputPath -ChildPath $FileName

Write-Host "Starting folder permissions audit..." -ForegroundColor Cyan
Write-Host "Target servers: $($ServerList -join ', ')" -ForegroundColor Gray
Write-Host "Base path: $BasePath" -ForegroundColor Gray

$Report = @()
$ProcessedServers = 0
$TotalServers = $ServerList.Count

foreach ($Server in $ServerList) {
    $ProcessedServers++
    Write-Progress -Activity "Auditing Folder Permissions" `
                   -Status "Processing server $Server ($ProcessedServers of $TotalServers)" `
                   -PercentComplete (($ProcessedServers / $TotalServers) * 100)
    
    Write-Host "Processing server: $Server" -ForegroundColor Yellow
    
    # Test server connectivity
    if (-not (Test-Connection -ComputerName $Server -Count 1 -Quiet)) {
        Write-Warning "Server $Server is not reachable. Skipping..."
        continue
    }
    
    try {
        # Construct UNC path
        $UNCPath = "\\$Server\$BasePath"
        
        # Get folder structure with optional depth limit
        $GetChildItemParams = @{
            Path = $UNCPath
            Directory = $true
            Recurse = $true
            Force = $true
            ErrorAction = 'SilentlyContinue'
        }
        
        if ($MaxDepth -gt 0) {
            $GetChildItemParams.Depth = $MaxDepth
        }
        
        $FolderPath = Get-ChildItem @GetChildItemParams
        
        foreach ($Folder in $FolderPath) {
            try {
                $ACL = Get-Acl -Path $Folder.FullName -ErrorAction Stop
                
                foreach ($Access in $ACL.Access) {
                    $Properties = [ordered]@{
                        'Server' = $Server
                        'FolderPath' = $Folder.FullName
                        'Identity' = $Access.IdentityReference
                        'Permissions' = $Access.FileSystemRights
                        'AccessControlType' = $Access.AccessControlType
                        'Inherited' = $Access.IsInherited
                        'ScanDate' = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                    $Report += New-Object -TypeName PSObject -Property $Properties
                }
            }
            catch {
                Write-Warning "Failed to get ACL for $($Folder.FullName): $($_.Exception.Message)"
            }
        }
        
        Write-Host "Completed scanning server: $Server" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to process server $Server`: $($_.Exception.Message)"
    }
}

Write-Progress -Activity "Auditing Folder Permissions" -Completed

if ($Report.Count -gt 0) {
    try {
        $Report | Export-Csv -Path $OutputFilePath -Encoding UTF8 -NoTypeInformation
        
        Write-Host "Audit completed successfully!" -ForegroundColor Green
        Write-Host "Total permission entries: $($Report.Count)" -ForegroundColor Yellow
        Write-Host "Report saved to: $OutputFilePath" -ForegroundColor White
    }
    catch {
        Write-Error "Failed to export report: $($_.Exception.Message)"
        exit 1
    }
}
else {
    Write-Host "No folder permissions found or all servers were unreachable." -ForegroundColor Yellow
}

Write-Host "Script execution completed." -ForegroundColor Cyan
