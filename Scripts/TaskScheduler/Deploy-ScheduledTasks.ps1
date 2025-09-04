<#
.SYNOPSIS
    Deploys scheduled tasks to multiple remote servers.

.DESCRIPTION
    This script automates the deployment of scheduled tasks across multiple servers by:
    - Copying required files to target servers
    - Creating necessary directories
    - Registering scheduled tasks from XML definitions
    - Optionally executing tasks after registration

.PARAMETER TaskName
    The name of the scheduled task to deploy.

.PARAMETER ServerList
    Array of server names where the task will be deployed.

.PARAMETER FilesToCopy
    Array of file paths to copy to each target server.

.PARAMETER TargetDirectory
    The directory on target servers where files will be copied. Default is "C:\Scripts".

.PARAMETER ExecuteAfterRegister
    Switch to execute the task immediately after registration.

.PARAMETER LogPath
    Path for the log file. Default is "C:\Logs".

.PARAMETER EnableDebugMode
    Switch to enable debug mode with detailed logging and timing information.

.EXAMPLE
    .\Deploy-ScheduledTasks.ps1 -TaskName "SystemMaintenance" -ServerList "server01","server02" -FilesToCopy "C:\Tasks\maintenance.ps1","C:\Tasks\maintenance.xml"
    
    Deploys SystemMaintenance task to server01 and server02.

.EXAMPLE
    .\Deploy-ScheduledTasks.ps1 -TaskName "BackupTask" -ServerList "server01" -FilesToCopy "C:\Tasks\backup.ps1","C:\Tasks\backup.xml" -ExecuteAfterRegister -EnableDebugMode
    
    Deploys BackupTask with immediate execution and debug logging.

.NOTES
    File Name      : Deploy-ScheduledTasks.ps1
    Author         : Leonardo Klein Rezende
    Prerequisite   : PowerShell remoting, Administrative access to target servers
    Creation Date  : 2025-09-04
    
    Requires:
    - PowerShell remoting enabled on target servers
    - Administrative privileges on target servers
    - XML task definition file with same name as TaskName

.LINK
    https://docs.microsoft.com/en-us/powershell/module/scheduledtasks/
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$TaskName,
    
    [Parameter(Mandatory = $true)]
    [string[]]$ServerList,
    
    [Parameter(Mandatory = $true)]
    [string[]]$FilesToCopy,
    
    [Parameter(Mandatory = $false)]
    [string]$TargetDirectory = "C:\Scripts",
    
    [Parameter(Mandatory = $false)]
    [switch]$ExecuteAfterRegister,
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\Logs",
    
    [Parameter(Mandatory = $false)]
    [switch]$EnableDebugMode
)

# Ensure log directory exists
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$LogFile = Join-Path -Path $LogPath -ChildName "Deploy_ScheduledTasks_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

if ($EnableDebugMode) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    Start-Transcript -Path $LogFile
}

# Validate files exist locally
Write-Host "Validating source files..." -ForegroundColor Cyan
foreach ($file in $FilesToCopy) {
    if (-not (Test-Path $file)) {
        Write-Error "Source file not found: $file"
        exit 1
    }
}
Write-Host "All source files validated successfully." -ForegroundColor Green

Write-Host "`nStarting scheduled task deployment..." -ForegroundColor Cyan
Write-Host "Task name: $TaskName" -ForegroundColor Gray
Write-Host "Target servers: $($ServerList -join ', ')" -ForegroundColor Gray
Write-Host "Target directory: $TargetDirectory" -ForegroundColor Gray
Write-Host "Execute after register: $ExecuteAfterRegister" -ForegroundColor Gray

$TotalServers = $ServerList.Count
$ProcessedServers = 0
$SuccessfulDeployments = 0
$FailedDeployments = 0

foreach ($server in $ServerList) {
    $ProcessedServers++
    Write-Progress -Activity "Deploying Scheduled Tasks" `
                   -Status "Processing server $server ($ProcessedServers of $TotalServers)" `
                   -PercentComplete (($ProcessedServers / $TotalServers) * 100)
    
    Write-Host "`n========================================" -ForegroundColor DarkGray
    Write-Host "Processing server: $server" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor DarkGray
    
    # Test server connectivity
    if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
        Write-Host "Server $server is unreachable. Skipping..." -ForegroundColor Red
        $FailedDeployments++
        continue
    }
    
    try {
        # Create target directory on remote server
        Write-Host "Creating target directory on $server..." -ForegroundColor Yellow
        Invoke-Command -ComputerName $server -ScriptBlock {
            param($TargetDir)
            if (-not (Test-Path -Path $TargetDir)) {
                New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
                Write-Host "Created directory: $TargetDir" -ForegroundColor Green
            } else {
                Write-Host "Directory already exists: $TargetDir" -ForegroundColor Yellow
            }
        } -ArgumentList $TargetDirectory -ErrorAction Stop
        
        # Copy files to target server
        Write-Host "Copying files to $server..." -ForegroundColor Yellow
        foreach ($file in $FilesToCopy) {
            try {
                $fileName = Split-Path $file -Leaf
                $remotePath = "\\$server\$($TargetDirectory.Replace(':','$'))\$fileName"
                Copy-Item -Path $file -Destination $remotePath -Force -ErrorAction Stop
                Write-Host "Copied: $fileName" -ForegroundColor Gray
            }
            catch {
                Write-Host "Failed to copy $file`: $($_.Exception.Message)" -ForegroundColor Red
                throw
            }
        }
        
        # Remove existing task if it exists
        Write-Host "Checking for existing task on $server..." -ForegroundColor Yellow
        Invoke-Command -ComputerName $server -ScriptBlock {
            param($TaskName)
            $taskExists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            if ($taskExists) {
                try {
                    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
                    Write-Host "Removed existing task: $TaskName" -ForegroundColor Yellow
                }
                catch {
                    Write-Host "Failed to remove existing task: $($_.Exception.Message)" -ForegroundColor Red
                    throw
                }
            }
        } -ArgumentList $TaskName -ErrorAction Stop
        
        # Register new task
        Write-Host "Registering scheduled task on $server..." -ForegroundColor Yellow
        Invoke-Command -ComputerName $server -ScriptBlock {
            param($TaskName, $TargetDir, $ExecuteAfter)
            $xmlFile = Join-Path -Path $TargetDir -ChildPath "$TaskName.xml"
            
            if (Test-Path $xmlFile) {
                try {
                    $xmlContent = Get-Content -Path $xmlFile -Raw
                    Register-ScheduledTask -Xml $xmlContent -TaskName $TaskName -ErrorAction Stop
                    Write-Host "Task registered successfully: $TaskName" -ForegroundColor Green
                    
                    if ($ExecuteAfter) {
                        Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop
                        Write-Host "Task executed: $TaskName" -ForegroundColor Gray
                    }
                }
                catch {
                    Write-Host "Failed to register task: $($_.Exception.Message)" -ForegroundColor Red
                    throw
                }
            }
            else {
                Write-Host "XML file not found: $xmlFile" -ForegroundColor Red
                throw "Task definition file not found"
            }
        } -ArgumentList $TaskName, $TargetDirectory, $ExecuteAfterRegister -ErrorAction Stop
        
        Write-Host "Successfully completed deployment to $server" -ForegroundColor Green
        $SuccessfulDeployments++
    }
    catch {
        Write-Host "Failed to deploy to $server`: $($_.Exception.Message)" -ForegroundColor Red
        $FailedDeployments++
    }
}

Write-Progress -Activity "Deploying Scheduled Tasks" -Completed

# Summary
Write-Host "`n========================================" -ForegroundColor DarkGray
Write-Host "DEPLOYMENT SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor DarkGray
Write-Host "Total servers: $TotalServers" -ForegroundColor White
Write-Host "Successful deployments: $SuccessfulDeployments" -ForegroundColor Green
Write-Host "Failed deployments: $FailedDeployments" -ForegroundColor Red

if ($EnableDebugMode) {
    $watch.Stop()
    Write-Host "`nExecution time: $($watch.Elapsed)" -ForegroundColor Gray
    Write-Host "Process ID: $([System.Diagnostics.Process]::GetCurrentProcess().Id)" -ForegroundColor Gray
    Write-Host "Log file: $LogFile" -ForegroundColor Gray
    Stop-Transcript
}

Write-Host "`nScript execution completed." -ForegroundColor Cyan

# Exit with appropriate code
if ($FailedDeployments -gt 0) {
    exit 1
} else {
    exit 0
}
