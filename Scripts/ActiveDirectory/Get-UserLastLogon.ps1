<#
.SYNOPSIS
    Reports Active Directory user last logon times and group memberships.

.DESCRIPTION
    This script queries Active Directory for users matching a specified filter and exports
    their information including last logon date and group memberships to a CSV file.

.PARAMETER UserFilter
    The filter to apply when searching for users. Supports wildcard patterns.
    Default is "*" (all users).

.PARAMETER OutputPath
    The path where the CSV report will be saved. Default is current directory.

.PARAMETER FileName
    The name of the output CSV file. Default is "UserLastLogon_YYYYMMDD.csv".

.PARAMETER IncludeDisabledUsers
    Switch to include disabled user accounts in the report. Default is enabled users only.

.EXAMPLE
    .\Get-UserLastLogon.ps1 -UserFilter "john.*"
    
    Exports all users starting with "john" to the current directory.

.EXAMPLE
    .\Get-UserLastLogon.ps1 -UserFilter "*" -OutputPath "C:\Reports" -IncludeDisabledUsers
    
    Exports all users (including disabled) to C:\Reports directory.

.NOTES
    File Name      : Get-UserLastLogon.ps1
    Author         : Leonardo Klein Rezende
    Prerequisite   : Active Directory PowerShell module
    Creation Date  : 2025-09-04
    
    LastLogon attribute may not be accurate in multi-DC environments.
    Consider using lastLogonTimestamp for more accurate results across DCs.

.LINK
    https://docs.microsoft.com/en-us/powershell/module/activedirectory/get-aduser
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$UserFilter = "*",
    
    [Parameter(Mandatory = $false)]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$OutputPath = $PWD.Path,
    
    [Parameter(Mandatory = $false)]
    [string]$FileName = "UserLastLogon_$(Get-Date -Format 'yyyyMMdd').csv",
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeDisabledUsers
)

# Import required module
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "Active Directory module loaded successfully." -ForegroundColor Green
}
catch {
    Write-Error "Failed to load Active Directory module. Please ensure RSAT AD tools are installed."
    exit 1
}

# Construct full output path
$OutputFilePath = Join-Path -Path $OutputPath -ChildPath $FileName

# Build filter based on parameters
$Filter = "samAccountName -like `"$UserFilter`""
if (-not $IncludeDisabledUsers) {
    $Filter += " -and Enabled -eq `$true"
}

Write-Host "Starting user last logon report..." -ForegroundColor Cyan
Write-Host "User filter: $UserFilter" -ForegroundColor Gray
Write-Host "Include disabled users: $IncludeDisabledUsers" -ForegroundColor Gray

try {
    # Query user objects
    $Users = Get-ADUser -Filter $Filter `
                       -Properties Company, Created, LastLogon, MemberOf, Enabled `
                       -ErrorAction Stop |
             Select-Object @{Name="SamAccountName"; Expression={$_.samAccountName}},
                          @{Name="Name"; Expression={$_.Name}},
                          @{Name="Company"; Expression={$_.Company}},
                          @{Name="Created"; Expression={Get-Date $_.Created -Format "yyyy-MM-dd"}},
                          @{Name="LastLogon"; Expression={
                              if ($_.LastLogon -and $_.LastLogon -gt 0) {
                                  [DateTime]::FromFileTime($_.LastLogon).ToString("yyyy-MM-dd HH:mm:ss")
                              } else {
                                  "Never"
                              }
                          }},
                          @{Name="Enabled"; Expression={$_.Enabled}},
                          @{Name="GroupMemberships"; Expression={
                              if ($_.MemberOf) {
                                  ($_.MemberOf -replace '^CN=|,(OU|CN).+') -join ";"
                              } else {
                                  "None"
                              }
                          }}

    if ($Users.Count -gt 0) {
        # Export to CSV
        $Users | Export-Csv -Encoding UTF8 -Path $OutputFilePath -NoTypeInformation
        
        Write-Host "Export completed successfully!" -ForegroundColor Green
        Write-Host "Found $($Users.Count) users matching criteria" -ForegroundColor Yellow
        Write-Host "Report saved to: $OutputFilePath" -ForegroundColor White
    }
    else {
        Write-Host "No users found matching the specified criteria." -ForegroundColor Yellow
    }
}
catch {
    Write-Error "Failed to query users: $($_.Exception.Message)"
    exit 1
}

Write-Host "Script execution completed." -ForegroundColor Cyan
