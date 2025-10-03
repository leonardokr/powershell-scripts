<#
.SYNOPSIS
    Manages Windows Updates across multiple servers during scheduled maintenance windows.

.DESCRIPTION
    Orchestrates Windows Updates installation across server infrastructure with staged execution
    for maintenance windows. Supports CSV-based server lists, SQL Server service management,
    and comprehensive logging for audit trails.

.PARAMETER ServerListPath
    Path to CSV file containing server names. Must have 'ServerName' column header.

.PARAMETER Stage
    Execution stage: Check, Reboot, Recheck, or Finalize.

.PARAMETER LogPath  
    Directory path for log files. Default: C:\Logs\WindowsUpdates

.PARAMETER WSUSTimeoutMinutes
    Timeout for Windows Update operations in minutes. Default: 30

.PARAMETER RebootTimeoutMinutes
    Maximum wait time for server reboot completion. Default: 15

.PARAMETER SkipSQLServiceCheck
    Skip SQL Server service verification during check stage.

.EXAMPLE
    .\Invoke-WindowsUpdateMaintenance.ps1 -ServerListPath "C:\servers.csv" -Stage Check
    
    Checks for available updates on servers listed in CSV file.

.EXAMPLE
    .\Invoke-WindowsUpdateMaintenance.ps1 -ServerListPath "C:\servers.csv" -Stage Reboot -LogPath "D:\Maintenance\Logs"
    
    Reboots servers after update installation with custom log location.

.NOTES
    File Name      : Invoke-WindowsUpdateMaintenance.ps1
    Author         : IT Operations Team
    Prerequisite   : Administrator privileges, PowerShell 5.1+, PSWindowsUpdate module
    Creation Date  : 2025-10-03
    
    MAINTENANCE WINDOW WORKFLOW:
    1. Initial update installation
    2. Server reboots and SQL Server update approval
    3. Post-reboot - Final update check and SQL service restart
    4. Completion - Maintenance finalization

.LINK
    https://docs.microsoft.com/powershell/module/pswindowsupdate/
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$ServerListPath,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("Check", "Reboot", "Recheck", "Finalize")]
    [string]$Stage,
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\Logs\WindowsUpdates",
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(5, 120)]
    [int]$WSUSTimeoutMinutes = 30,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(5, 60)]
    [int]$RebootTimeoutMinutes = 15,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipSQLServiceCheck
)

$ErrorActionPreference = 'Stop'

function Initialize-LogFile {
    param([string]$LogDirectory, [string]$Stage)
    
    try {
        if (-not (Test-Path $LogDirectory)) {
            New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $logFileName = "WindowsUpdate_${Stage}_${timestamp}.log"
        $logFilePath = Join-Path $LogDirectory $logFileName
        
        $header = "=== Windows Update Maintenance - Stage: $Stage ==="
        $header | Out-File -FilePath $logFilePath -Encoding UTF8
        "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $logFilePath -Append -Encoding UTF8
        "" | Out-File -FilePath $logFilePath -Append -Encoding UTF8
        
        return $logFilePath
    }
    catch {
        throw "Failed to initialize log file: $($_.Exception.Message)"
    }
}

function Write-MaintenanceLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO",
        [string]$LogFilePath,
        [string]$ServerName = "LOCALHOST"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] [$ServerName] $Message"
    
    Write-Information $logEntry -InformationAction Continue
    
    if ($LogFilePath) {
        $logEntry | Out-File -FilePath $LogFilePath -Append -Encoding UTF8
    }
}

function Test-ServerConnectivity {
    param([string[]]$ServerNames, [string]$LogFilePath)
    
    $availableServers = @()
    $unavailableServers = @()
    
    foreach ($server in $ServerNames) {
        Write-MaintenanceLog "Testing connectivity to $server" -Level "INFO" -LogFilePath $LogFilePath -ServerName $server
        
        try {
            $result = Test-WSMan -ComputerName $server -ErrorAction Stop
            if ($result) {
                $availableServers += $server
                Write-MaintenanceLog "Connectivity verified" -Level "SUCCESS" -LogFilePath $LogFilePath -ServerName $server
            }
        }
        catch {
            $unavailableServers += $server
            Write-MaintenanceLog "Connectivity failed: $($_.Exception.Message)" -Level "ERROR" -LogFilePath $LogFilePath -ServerName $server
        }
    }
    
    return @{
        Available = $availableServers
        Unavailable = $unavailableServers
    }
}

function Get-SQLServerServices {
    param([string]$ServerName, [string]$LogFilePath)
    
    try {
        $sqlServices = Invoke-Command -ComputerName $ServerName -ScriptBlock {
            Get-Service | Where-Object {
                $_.Name -like "MSSQL*" -or 
                $_.Name -like "SQLServer*" -or 
                $_.Name -eq "SQLSERVERAGENT" -or
                $_.Name -like "SQL*Agent*"
            } | Select-Object Name, Status, StartType
        } -ErrorAction Stop
        
        Write-MaintenanceLog "Found $($sqlServices.Count) SQL Server services" -Level "INFO" -LogFilePath $LogFilePath -ServerName $ServerName
        return $sqlServices
    }
    catch {
        Write-MaintenanceLog "Failed to retrieve SQL Server services: $($_.Exception.Message)" -Level "ERROR" -LogFilePath $LogFilePath -ServerName $ServerName
        return @()
    }
}

function Invoke-UpdateCheck {
    param([string[]]$ServerNames, [string]$LogFilePath, [int]$TimeoutMinutes, [bool]$SkipSQLCheck)
    
    $results = @{}
    
    foreach ($server in $ServerNames) {
        Write-MaintenanceLog "Starting update check" -Level "INFO" -LogFilePath $LogFilePath -ServerName $server
        
        try {
            if (-not $SkipSQLCheck) {
                $sqlServices = Get-SQLServerServices -ServerName $server -LogFilePath $LogFilePath
                if ($sqlServices.Count -gt 0) {
                    Write-MaintenanceLog "SQL Server services detected - ensuring no automatic restarts during check" -Level "WARN" -LogFilePath $LogFilePath -ServerName $server
                }
            }
            
            $updates = Invoke-Command -ComputerName $server -ScriptBlock {
                param($Timeout)
                
                Import-Module PSWindowsUpdate -ErrorAction Stop
                
                $updateList = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot -Verbose:$false
                
                return @{
                    UpdateCount = $updateList.Count
                    Updates = $updateList | Select-Object Title, Size, Description
                    RequiresReboot = $updateList | Where-Object {$_.RebootRequired -eq $true}
                }
            } -ArgumentList $TimeoutMinutes -ErrorAction Stop
            
            $results[$server] = @{
                Status = "Success"
                UpdateCount = $updates.UpdateCount
                Updates = $updates.Updates
                RebootRequired = ($updates.RequiresReboot.Count -gt 0)
                Error = $null
            }
            
            Write-MaintenanceLog "Found $($updates.UpdateCount) available updates" -Level "SUCCESS" -LogFilePath $LogFilePath -ServerName $server
            
            if ($updates.RequiresReboot.Count -gt 0) {
                Write-MaintenanceLog "Updates requiring reboot detected" -Level "WARN" -LogFilePath $LogFilePath -ServerName $server
            }
        }
        catch {
            $results[$server] = @{
                Status = "Failed"
                UpdateCount = 0
                Updates = @()
                RebootRequired = $false
                Error = $_.Exception.Message
            }
            
            Write-MaintenanceLog "Update check failed: $($_.Exception.Message)" -Level "ERROR" -LogFilePath $LogFilePath -ServerName $server
        }
    }
    
    return $results
}

function Invoke-ServerReboot {
    param([string[]]$ServerNames, [string]$LogFilePath, [int]$TimeoutMinutes)
    
    $results = @{}
    
    foreach ($server in $ServerNames) {
        Write-MaintenanceLog "Checking if reboot is required" -Level "INFO" -LogFilePath $LogFilePath -ServerName $server
        
        try {
            $rebootPending = Invoke-Command -ComputerName $server -ScriptBlock {
                $registryKeys = @(
                    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
                    "HKLM:\SOFTWARE\Microsoft\Updates\UpdateExeVolatile"
                )
                
                foreach ($key in $registryKeys) {
                    if (Test-Path $key) {
                        return $true
                    }
                }
                
                $pendingReboot = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue
                return ($pendingReboot -ne $null)
            } -ErrorAction Stop
            
            if ($rebootPending) {
                Write-MaintenanceLog "Reboot required - initiating restart" -Level "INFO" -LogFilePath $LogFilePath -ServerName $server
                
                if ($PSCmdlet.ShouldProcess($server, "Restart computer")) {
                    Restart-Computer -ComputerName $server -Force -Wait -Timeout ($TimeoutMinutes * 60) -ErrorAction Stop
                    
                    Start-Sleep -Seconds 30
                    
                    $connectivityTest = Test-WSMan -ComputerName $server -ErrorAction SilentlyContinue
                    if ($connectivityTest) {
                        $results[$server] = @{
                            Status = "Success"
                            RebootCompleted = $true
                            Error = $null
                        }
                        Write-MaintenanceLog "Reboot completed successfully" -Level "SUCCESS" -LogFilePath $LogFilePath -ServerName $server
                    }
                    else {
                        throw "Server did not respond after reboot within timeout period"
                    }
                }
            }
            else {
                $results[$server] = @{
                    Status = "Skipped"
                    RebootCompleted = $false
                    Error = "No reboot required"
                }
                Write-MaintenanceLog "No reboot required" -Level "INFO" -LogFilePath $LogFilePath -ServerName $server
            }
        }
        catch {
            $results[$server] = @{
                Status = "Failed"
                RebootCompleted = $false
                Error = $_.Exception.Message
            }
            Write-MaintenanceLog "Reboot failed: $($_.Exception.Message)" -Level "ERROR" -LogFilePath $LogFilePath -ServerName $server
        }
    }
    
    return $results
}

function Invoke-FinalizeUpdates {
    param([string[]]$ServerNames, [string]$LogFilePath)
    
    $results = @{}
    
    foreach ($server in $ServerNames) {
        Write-MaintenanceLog "Finalizing update installation" -Level "INFO" -LogFilePath $LogFilePath -ServerName $server
        
        try {
            $sqlServices = Get-SQLServerServices -ServerName $server -LogFilePath $LogFilePath
            
            if ($sqlServices.Count -gt 0) {
                Write-MaintenanceLog "Restarting SQL Server services" -Level "INFO" -LogFilePath $LogFilePath -ServerName $server
                
                Invoke-Command -ComputerName $server -ScriptBlock {
                    param($Services)
                    
                    foreach ($service in $Services) {
                        if ($service.Status -eq "Running") {
                            try {
                                Restart-Service -Name $service.Name -Force -ErrorAction Stop
                                Write-Output "Restarted service: $($service.Name)"
                            }
                            catch {
                                Write-Error "Failed to restart service $($service.Name): $($_.Exception.Message)"
                            }
                        }
                    }
                } -ArgumentList @(,$sqlServices) -ErrorAction Stop
            }
            
            $finalCheck = Invoke-Command -ComputerName $server -ScriptBlock {
                Import-Module PSWindowsUpdate -ErrorAction Stop
                $remainingUpdates = Get-WindowsUpdate -MicrosoftUpdate -Verbose:$false
                return $remainingUpdates.Count
            } -ErrorAction Stop
            
            $results[$server] = @{
                Status = "Success"
                SQLServicesRestarted = ($sqlServices.Count -gt 0)
                RemainingUpdates = $finalCheck
                Error = $null
            }
            
            Write-MaintenanceLog "Finalization completed - $finalCheck updates remaining" -Level "SUCCESS" -LogFilePath $LogFilePath -ServerName $server
        }
        catch {
            $results[$server] = @{
                Status = "Failed"
                SQLServicesRestarted = $false
                RemainingUpdates = -1
                Error = $_.Exception.Message
            }
            Write-MaintenanceLog "Finalization failed: $($_.Exception.Message)" -Level "ERROR" -LogFilePath $LogFilePath -ServerName $server
        }
    }
    
    return $results
}

function Write-SummaryReport {
    param([hashtable]$Results, [string]$Stage, [string]$LogFilePath)
    
    $summary = @"

=== MAINTENANCE SUMMARY - STAGE: $Stage ===
Execution Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

"@
    
    $successCount = 0
    $failureCount = 0
    
    foreach ($server in $Results.Keys) {
        $result = $Results[$server]
        $status = $result.Status
        
        if ($status -eq "Success" -or $status -eq "Skipped") {
            $successCount++
        }
        else {
            $failureCount++
        }
        
        $summary += "Server: $server - Status: $status"
        if ($result.Error) {
            $summary += " - Error: $($result.Error)"
        }
        $summary += "`n"
        
        switch ($Stage) {
            "Check" {
                if ($result.UpdateCount -ne $null) {
                    $summary += "  Updates Available: $($result.UpdateCount)`n"
                }
            }
            "Reboot" {
                if ($result.RebootCompleted -ne $null) {
                    $summary += "  Reboot Completed: $($result.RebootCompleted)`n"
                }
            }
            "Finalize" {
                if ($result.RemainingUpdates -ne $null -and $result.RemainingUpdates -ge 0) {
                    $summary += "  Remaining Updates: $($result.RemainingUpdates)`n"
                }
            }
        }
        $summary += "`n"
    }
    
    $summary += "TOTALS: Success: $successCount, Failed: $failureCount`n"
    $summary += "======================================`n"
    
    Write-Information $summary -InformationAction Continue
    
    if ($LogFilePath) {
        $summary | Out-File -FilePath $LogFilePath -Append -Encoding UTF8
    }
}

try {
    Write-Information "=== Windows Update Maintenance Script ===" -InformationAction Continue
    Write-Information "Stage: $Stage" -InformationAction Continue
    Write-Information "Server List: $ServerListPath" -InformationAction Continue
    
    $logFilePath = Initialize-LogFile -LogDirectory $LogPath -Stage $Stage
    Write-MaintenanceLog "Log file initialized: $logFilePath" -Level "SUCCESS" -LogFilePath $logFilePath
    
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        throw "PSWindowsUpdate module not available. Please install: Install-Module PSWindowsUpdate"
    }
    
    $serverList = Import-Csv -Path $ServerListPath
    if (-not $serverList -or -not $serverList[0].PSObject.Properties['ServerName']) {
        throw "Invalid CSV format. Must contain 'ServerName' column header."
    }
    
    $serverNames = $serverList.ServerName | Where-Object {$_ -and $_.Trim() -ne ""}
    Write-MaintenanceLog "Loaded $($serverNames.Count) servers from CSV" -Level "INFO" -LogFilePath $logFilePath
    
    $connectivity = Test-ServerConnectivity -ServerNames $serverNames -LogFilePath $logFilePath
    
    if ($connectivity.Unavailable.Count -gt 0) {
        Write-MaintenanceLog "Unavailable servers will be skipped: $($connectivity.Unavailable -join ', ')" -Level "WARN" -LogFilePath $logFilePath
    }
    
    if ($connectivity.Available.Count -eq 0) {
        throw "No servers are accessible for maintenance operations"
    }
    
    $results = @{}
    
    switch ($Stage) {
        "Check" {
            Write-MaintenanceLog "Starting update check phase" -Level "INFO" -LogFilePath $logFilePath
            $results = Invoke-UpdateCheck -ServerNames $connectivity.Available -LogFilePath $logFilePath -TimeoutMinutes $WSUSTimeoutMinutes -SkipSQLCheck $SkipSQLServiceCheck.IsPresent
        }
        
        "Reboot" {
            Write-MaintenanceLog "Starting reboot phase" -Level "INFO" -LogFilePath $logFilePath
            $results = Invoke-ServerReboot -ServerNames $connectivity.Available -LogFilePath $logFilePath -TimeoutMinutes $RebootTimeoutMinutes
        }
        
        "Recheck" {
            Write-MaintenanceLog "Starting recheck phase" -Level "INFO" -LogFilePath $logFilePath
            $results = Invoke-UpdateCheck -ServerNames $connectivity.Available -LogFilePath $logFilePath -TimeoutMinutes $WSUSTimeoutMinutes -SkipSQLCheck $false
        }
        
        "Finalize" {
            Write-MaintenanceLog "Starting finalization phase" -Level "INFO" -LogFilePath $logFilePath
            $results = Invoke-FinalizeUpdates -ServerNames $connectivity.Available -LogFilePath $logFilePath
        }
    }
    
    Write-SummaryReport -Results $results -Stage $Stage -LogFilePath $logFilePath
    
    Write-MaintenanceLog "Maintenance stage '$Stage' completed successfully" -Level "SUCCESS" -LogFilePath $logFilePath
    
}
catch {
    $errorMessage = "Critical error during $Stage stage: $($_.Exception.Message)"
    Write-MaintenanceLog $errorMessage -Level "ERROR" -LogFilePath $logFilePath
    Write-Error $errorMessage
    exit 1
}

Write-MaintenanceLog "Script execution completed" -Level "SUCCESS" -LogFilePath $logFilePath