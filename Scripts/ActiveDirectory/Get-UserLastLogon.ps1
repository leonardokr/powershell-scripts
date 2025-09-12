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
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$OutputPath = $PWD.Path,
    
    [Parameter(Mandatory = $false)]
    [string]$FileName = "UserLastLogon_$(Get-Date -Format 'yyyyMMdd').csv",
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeDisabledUsers
)

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Information "Active Directory module loaded successfully." -InformationAction Continue
}
catch {
    Write-Error "Failed to load Active Directory module. Please ensure RSAT AD tools are installed."
    exit 1
}

$OutputFilePath = Join-Path -Path $OutputPath -ChildPath $FileName

$Filter = "samAccountName -like `"$UserFilter`""
if (-not $IncludeDisabledUsers) {
    $Filter += " -and Enabled -eq `$true"
}

Write-Information "Starting user last logon report..." -InformationAction Continue
Write-Information "User filter: $UserFilter" -InformationAction Continue
Write-Information "Include disabled users: $IncludeDisabledUsers" -InformationAction Continue

try {
    $Users = Get-ADUser -Filter $Filter `
        -Properties Company, Created, LastLogon, MemberOf, Enabled `
        -ErrorAction Stop |
    Select-Object @{Name = "SamAccountName"; Expression = { $_.samAccountName } },
    @{Name = "Name"; Expression = { $_.Name } },
    @{Name = "Company"; Expression = { $_.Company } },
    @{Name = "Created"; Expression = { Get-Date $_.Created -Format "yyyy-MM-dd" } },
    @{Name = "LastLogon"; Expression = {
            if ($_.LastLogon -and $_.LastLogon -gt 0) {
                [DateTime]::FromFileTime($_.LastLogon).ToString("yyyy-MM-dd HH:mm:ss")
            }
            else {
                "Never"
            }
        }
    },
    @{Name = "Enabled"; Expression = { $_.Enabled } },
    @{Name = "GroupMemberships"; Expression = {
            if ($_.MemberOf) {
                ($_.MemberOf -replace '^CN=|,(OU|CN).+') -join ";"
            }
            else {
                "None"
            }
        }
    }

    if ($Users.Count -gt 0) {
        $Users | Export-Csv -Encoding UTF8 -Path $OutputFilePath -NoTypeInformation
        
        Write-Information "Export completed successfully!" -InformationAction Continue
        Write-Information "Found $($Users.Count) users matching criteria" -InformationAction Continue
        Write-Information "Report saved to: $OutputFilePath" -InformationAction Continue
    }
    else {
        Write-Information "No users found matching the specified criteria." -InformationAction Continue
    }
}
catch {
    Write-Error "Failed to query users: $($_.Exception.Message)"
    exit 1
}

Write-Information "Script execution completed." -InformationAction Continue





