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
    Creation Date  : 2025-09-05
    
    Requires:
    - PowerShell remoting enabled on target servers
    - Administrative privileges on target servers
    - Task XML file included in FilesToCopy parameter

.LINK
    https://docs.microsoft.com/en-us/powershell/module/scheduledtasks/
#>

[CmdletBinding(SupportsShouldProcess)]
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

$ErrorActionPreference = 'Stop'

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

function Copy-FilesToServer {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ServerName,
        [string[]]$Files,
        [string]$TargetDir
    )
    
    Write-Log "Starting file deployment to $ServerName" 'Info'
    
    try {
        $session = New-PSSession -ComputerName $ServerName -ErrorAction Stop
        
        if ($PSCmdlet.ShouldProcess($ServerName, "Create directory $TargetDir")) {
            Invoke-Command -Session $session -ScriptBlock {
                param($Dir)
                if (-not (Test-Path $Dir)) {
                    New-Item -Path $Dir -ItemType Directory -Force | Out-Null
                    Write-Output "Created directory: $Dir"
                }
            } -ArgumentList $TargetDir
        }
        
        foreach ($file in $Files) {
            if (Test-Path $file) {
                $fileName = Split-Path $file -Leaf
                $remotePath = Join-Path $TargetDir $fileName
                
                if ($PSCmdlet.ShouldProcess($file, "Copy to $ServerName")) {
                    Copy-Item -Path $file -Destination $remotePath -ToSession $session -Force
                    Write-Log "Copied $fileName to $ServerName" 'Info'
                }
            }
            else {
                Write-Log "File not found: $file" 'Warning'
            }
        }
        
        Remove-PSSession $session
        Write-Log "File deployment to $ServerName completed successfully" 'Info'
    }
    catch {
        Write-Log "Failed to deploy files to $ServerName - $($_.Exception.Message)" 'Error'
        if ($session) { Remove-PSSession $session -ErrorAction SilentlyContinue }
        throw
    }
}

function Register-ScheduledTaskOnServer {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ServerName,
        [string]$TaskName,
        [string]$TargetDir,
        [bool]$ExecuteAfter
    )
    
    Write-Log "Registering scheduled task '$TaskName' on $ServerName" 'Info'
    
    try {
        $session = New-PSSession -ComputerName $ServerName -ErrorAction Stop
        
        $result = Invoke-Command -Session $session -ScriptBlock {
            param($TaskName, $TargetDir, $ExecuteAfter)
            
            $xmlFile = Get-ChildItem -Path $TargetDir -Filter "*.xml" | Where-Object { $_.Name -like "*$TaskName*" } | Select-Object -First 1
            
            if (-not $xmlFile) {
                throw "Task XML file not found for '$TaskName' in $TargetDir"
            }
            
            try {
                Register-ScheduledTask -TaskName $TaskName -Xml (Get-Content $xmlFile.FullName | Out-String) -Force
                $status = "Task '$TaskName' registered successfully"
                
                if ($ExecuteAfter) {
                    Start-ScheduledTask -TaskName $TaskName
                    $status += " and started"
                }
                
                return @{ Success = $true; Message = $status }
            }
            catch {
                return @{ Success = $false; Message = $_.Exception.Message }
            }
        } -ArgumentList $TaskName, $TargetDir, $ExecuteAfter
        
        Remove-PSSession $session
        
        if ($result.Success) {
            Write-Log $result.Message 'Info'
        }
        else {
            Write-Log "Failed to register task on $ServerName - $($result.Message)" 'Error'
        }
        
        return $result.Success
    }
    catch {
        Write-Log "Failed to register task on $ServerName - $($_.Exception.Message)" 'Error'
        if ($session) { Remove-PSSession $session -ErrorAction SilentlyContinue }
        return $false
    }
}

try {
    Write-Log "Starting scheduled task deployment process" 'Info'
    Write-Log "Task Name: $TaskName" 'Debug'
    Write-Log "Target Servers: $($ServerList -join ', ')" 'Debug'
    Write-Log "Files to Copy: $($FilesToCopy -join ', ')" 'Debug'
    Write-Log "Target Directory: $TargetDirectory" 'Debug'
    
    $missingFiles = $FilesToCopy | Where-Object { -not (Test-Path $_) }
    if ($missingFiles) {
        throw "Missing files: $($missingFiles -join ', ')"
    }
    
    $xmlFile = $FilesToCopy | Where-Object { $_.EndsWith('.xml') }
    if (-not $xmlFile) {
        throw "No XML task definition file found in FilesToCopy parameter"
    }
    
    $successCount = 0
    $failureCount = 0
    $results = @()
    
    foreach ($server in $ServerList) {
        Write-Log "Processing server: $server" 'Info'
        
        try {
            if (-not (Test-NetConnection -ComputerName $server -Port 5985 -InformationLevel Quiet)) {
                throw "Cannot connect to $server on port 5985 (WinRM)"
            }
            
            Copy-FilesToServer -ServerName $server -Files $FilesToCopy -TargetDir $TargetDirectory
            
            $taskResult = Register-ScheduledTaskOnServer -ServerName $server -TaskName $TaskName -TargetDir $TargetDirectory -ExecuteAfter $ExecuteAfterRegister
            
            if ($taskResult) {
                $successCount++
                $results += [PSCustomObject]@{
                    Server  = $server
                    Status  = 'Success'
                    Message = 'Task deployed successfully'
                }
            }
            else {
                $failureCount++
                $results += [PSCustomObject]@{
                    Server  = $server
                    Status  = 'Failed'
                    Message = 'Task registration failed'
                }
            }
        }
        catch {
            $failureCount++
            $errorMessage = $_.Exception.Message
            Write-Log "Server $server failed: $errorMessage" 'Error'
            
            $results += [PSCustomObject]@{
                Server  = $server
                Status  = 'Failed'
                Message = $errorMessage
            }
        }
    }
    
    Write-Log "Deployment completed" 'Info'
    Write-Log "Success: $successCount servers" 'Info'
    Write-Log "Failed: $failureCount servers" 'Info'
    
    Write-Output $results
    
    if ($failureCount -gt 0) {
        Write-Warning "Some deployments failed. Check the log for details."
        exit 1
    }
}
catch {
    Write-Log "Deployment process failed: $($_.Exception.Message)" 'Error'
    exit 1
}