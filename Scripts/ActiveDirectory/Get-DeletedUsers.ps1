#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Exports deleted Active Directory users within a specified date range.

.DESCRIPTION
    This script queries Active Directory for deleted user objects and exports their information
    to a CSV file. It includes user details such as display name, UPN, company, and deletion date.

.PARAMETER DeletedAfter
    The date after which to search for deleted users. Default is 3 months ago.

.PARAMETER OutputPath
    The path where the CSV report will be saved. Default is current directory.

.PARAMETER FileName
    The name of the output CSV file. Default is "DeletedUsers_YYYYMMDD.csv".

.EXAMPLE
    .\Get-DeletedUsers.ps1
    
    Exports all users deleted in the last 3 months to the current directory.

.EXAMPLE
    .\Get-DeletedUsers.ps1 -DeletedAfter "2024-01-01" -OutputPath "C:\Reports"
    
    Exports users deleted after January 1, 2024 to C:\Reports directory.

.NOTES
    File Name      : Get-DeletedUsers.ps1
    Author         : Leonardo Klein Rezende
    Prerequisite   : Active Directory PowerShell module
    Creation Date  : 2025-09-04
    Version        : 1.0.0

    Requires Domain Admin or equivalent permissions to query deleted objects.

.LINK
    https://docs.microsoft.com/en-us/powershell/module/activedirectory/get-adobject
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [DateTime]$DeletedAfter = (Get-Date).AddMonths(-3),
    
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$OutputPath = $PWD.Path,
    
    [Parameter(Mandatory = $false)]
    [string]$FileName = "DeletedUsers_$(Get-Date -Format 'yyyyMMdd').csv"
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

Write-Information "Starting deleted users export..." -InformationAction Continue
Write-Information "Search criteria: Users deleted after $($DeletedAfter.ToString('yyyy-MM-dd'))" -InformationAction Continue

try {
    $DeletedUsers = Get-ADObject -Filter "isdeleted -eq `$TRUE -and whenChanged -gt `$DeletedAfter -and ObjectClass -eq 'user'" `
        -IncludeDeletedObjects `
        -Properties displayName, userPrincipalName, Company, whenChanged, samAccountName `
        -ErrorAction Stop |
    Where-Object { $_.userPrincipalName -ne $null } |
    Sort-Object whenChanged |
    Select-Object @{Name = "DisplayName"; Expression = { $_.displayName } },
    @{Name = "UserPrincipalName"; Expression = { $_.userPrincipalName } },
    @{Name = "Company"; Expression = { $_.Company } },
    @{Name = "DeletionDate"; Expression = { Get-Date $_.whenChanged -Format "yyyy-MM-dd" } },
    @{Name = "SamAccountName"; Expression = { $_.samAccountName } }

    if ($DeletedUsers.Count -gt 0) {
        $DeletedUsers | Export-Csv -Encoding UTF8 -Path $OutputFilePath -NoTypeInformation
        
        Write-Information "Export completed successfully!" -InformationAction Continue
        Write-Information "Found $($DeletedUsers.Count) deleted users" -InformationAction Continue
        Write-Information "Report saved to: $OutputFilePath" -InformationAction Continue
    }
    else {
        Write-Information "No deleted users found for the specified criteria." -InformationAction Continue
    }
}
catch {
    Write-Error "Failed to query deleted users: $($_.Exception.Message)"
    exit 1
}

Write-Information "Script execution completed." -InformationAction Continue

