#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Active Directory Password Expiration Notification Script
    
.DESCRIPTION
    Monitors Active Directory users and sends email notifications when passwords are approaching expiration.
    Supports fine-grained password policies, multilingual messages, and comprehensive logging.
    
.PARAMETER searchBase
    Distinguished Name of the OU to search for users. If not specified, uses default configured base.
    
.PARAMETER testMode
    Switch to enable test mode. All emails will be sent to the test recipient instead of actual users.
    
.PARAMETER enableLogging
    Switch to enable detailed logging to CSV file.
    
.EXAMPLE
    .\Send-PasswordExpiryNotification.ps1
    Runs with default configuration
    
.EXAMPLE
    .\Send-PasswordExpiryNotification.ps1 -testMode -enableLogging
    Runs in test mode with logging enabled
    
.NOTES
    File Name    : Send-PasswordExpiryNotification.ps1
    Author       : Leonardo Klein Rezende
    Requires     : PowerShell 5.1+, ActiveDirectory Module, SMTP Server Access
    
.LINK
    https://github.com/leonardokr/powershell-scripts
#>

param(
    [string]$searchBase,
    [switch]$testMode,
    [switch]$enableLogging
)

$smtpServer = "x.x.x.x"
$expireInDays = 10
$fromAddress = "noreply@company.com"
$testRecipient = "admin@company.com"
$language = "EN"  # EN or PT
$logDirectory = "C:\Logs\PasswordNotifications"
$defaultSearchBase = "OU=Users,DC=contoso,DC=local"

if ($searchBase) { $defaultSearchBase = $searchBase }
if ($testMode) { $testModeEnabled = $true } else { $testModeEnabled = $false }
if ($enableLogging) { $loggingEnabled = $true } else { $loggingEnabled = $false }

$messages = @{
    EN = @{
        EmailSubject  = "Password Expiration Alert"
        Greeting      = "Dear"
        ExpiryMessage = @{
            Today = "Your network password expires today."
            Days  = "Your network password expires in {0} days."
            Day   = "Your network password expires in 1 day."
        }
        Instructions  = @{
            Title = "How to change your password:"
            Step1 = "Press Ctrl + Alt + Del"
            Step2 = "Select 'Change a password'"
            Step3 = "Follow the on-screen instructions"
        }
        Requirements  = @{
            Title      = "Password requirements:"
            MinLength  = "Minimum 8 characters"
            Complexity = "Use uppercase, lowercase, numbers and symbols"
            NoReuse    = "Don't reuse previous passwords"
        }
        Footer        = @{
            Department  = "IT Department"
            AutoMessage = "This is an automated message - do not reply."
            Support     = "For assistance, contact IT support."
        }
    }
    PT = @{
        EmailSubject  = "Alerta - Validade da senha da rede"
        Greeting      = "Prezado(a)"
        ExpiryMessage = @{
            Today = "Sua senha da rede expira hoje."
            Days  = "Sua senha da rede expira em {0} dias."
            Day   = "Sua senha da rede expira em 1 dia."
        }
        Instructions  = @{
            Title = "Como alterar sua senha:"
            Step1 = "Pressione Ctrl + Alt + Del"
            Step2 = "Selecione 'Alterar senha'"
            Step3 = "Siga as instruções na tela"
        }
        Requirements  = @{
            Title      = "Requisitos da senha:"
            MinLength  = "Mínimo 8 caracteres"
            Complexity = "Use maiúsculas, minúsculas, números e símbolos"
            NoReuse    = "Não reutilize senhas anteriores"
        }
        Footer        = @{
            Department  = "Departamento de TI"
            AutoMessage = "Esta é uma mensagem automática - não responder."
            Support     = "Em caso de dúvidas, entre em contato com o suporte técnico."
        }
    }
}

$msg = $messages[$language]
function Write-LogMessage {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Write-Information $logEntry -InformationAction Continue
}

function Initialize-LogFile {
    param([string]$LogPath)
    
    try {
        $parentDir = Split-Path -Path $LogPath -Parent
        
        if (-not (Test-Path -Path $parentDir)) {
            New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
            Write-LogMessage "Created log directory: $parentDir" -Level "SUCCESS"
        }
        
        if (-not (Test-Path -Path $LogPath)) {
            $header = "Date,UserName,Email,DaysToExpire,ExpirationDate,EmailSent,Status"
            $header | Out-File -FilePath $LogPath -Encoding UTF8
            Write-LogMessage "Created log file: $LogPath" -Level "SUCCESS"
        }
        
        return $true
    }
    catch {
        Write-LogMessage "Failed to initialize log file: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Get-PasswordExpirationData {
    param(
        [Microsoft.ActiveDirectory.Management.ADUser]$User,
        [System.TimeSpan]$DefaultMaxAge
    )
    
    $expirationData = @{
        PasswordSetDate = $User.PasswordLastSet
        ExpirationDate  = $null
        DaysToExpire    = $null
        Status          = "Unknown"
    }
    
    if ($User.PasswordLastSet) {
        $fineGrainedPolicy = Get-ADUserResultantPasswordPolicy -Identity $User -ErrorAction SilentlyContinue
        $maxAge = if ($fineGrainedPolicy) { $fineGrainedPolicy.MaxPasswordAge } else { $DefaultMaxAge }
        
        $expirationData.ExpirationDate = $User.PasswordLastSet.Add($maxAge)
        $expirationData.DaysToExpire = [math]::Floor(($expirationData.ExpirationDate - (Get-Date)).TotalDays)
        
        $expirationData.Status = switch ($expirationData.DaysToExpire) {
            { $_ -lt 0 } { "Expired" }
            { $_ -eq 0 } { "ExpiringToday" }
            { $_ -le 3 } { "Critical" }
            { $_ -le 7 } { "Warning" }
            default { "Normal" }
        }
    }
    
    return $expirationData
}

function Get-PasswordExpiryEmailBody {
    param(
        [string]$UserName,
        [int]$DaysToExpire
    )
    
    $expiryText = switch ($DaysToExpire) {
        0 { $msg.ExpiryMessage.Today }
        1 { $msg.ExpiryMessage.Day }
        default { $msg.ExpiryMessage.Days -f $DaysToExpire }
    }
    
    return @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); max-width: 600px; margin: 0 auto; }
        .header { color: #d73027; font-size: 24px; font-weight: bold; margin-bottom: 20px; text-align: center; }
        .content { color: #333; line-height: 1.6; font-size: 16px; }
        .alert-box { background-color: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 20px 0; border-radius: 4px; }
        .instructions { background-color: #e7f3ff; padding: 15px; border-left: 4px solid #007bff; margin: 20px 0; border-radius: 4px; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 2px solid #eee; font-size: 14px; color: #666; text-align: center; }
        ul { margin: 10px 0; padding-left: 20px; }
        li { margin-bottom: 5px; }
        kbd { background-color: #f1f1f1; border: 1px solid #ccc; border-radius: 3px; padding: 2px 4px; font-family: monospace; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">$($msg.EmailSubject)</div>
        
        <div class="content">
            <p>$($msg.Greeting) <strong>$UserName</strong>,</p>
            
            <div class="alert-box">
                <strong>$expiryText</strong>
            </div>
            
            <p>To avoid account lockouts and system access interruptions, please change your password immediately.</p>
            
            <div class="instructions">
                <p><strong>$($msg.Instructions.Title)</strong></p>
                <ul>
                    <li>$($msg.Instructions.Step1)</li>
                    <li>$($msg.Instructions.Step2)</li>
                    <li>$($msg.Instructions.Step3)</li>
                </ul>
            </div>
            
            <p><strong>$($msg.Requirements.Title)</strong></p>
            <ul>
                <li>$($msg.Requirements.MinLength)</li>
                <li>$($msg.Requirements.Complexity)</li>
                <li>$($msg.Requirements.NoReuse)</li>
            </ul>
        </div>
        
        <div class="footer">
            <p><strong>$($msg.Footer.Department)</strong><br>
            $($msg.Footer.AutoMessage)<br>
            $($msg.Footer.Support)</p>
        </div>
    </div>
</body>
</html>
"@
}

function Send-PasswordExpiryAlert {
    param(
        [Microsoft.ActiveDirectory.Management.ADUser]$User,
        [hashtable]$ExpirationData,
        [string]$RecipientEmail
    )
    
    try {
        $emailBody = Get-PasswordExpiryEmailBody -UserName $User.Name -DaysToExpire $ExpirationData.DaysToExpire
        
        $mailParams = @{
            SmtpServer = $smtpServer
            From       = $fromAddress
            To         = $RecipientEmail
            Subject    = $msg.EmailSubject
            Body       = $emailBody
            BodyAsHtml = $true
            Priority   = "High"
            Encoding   = [System.Text.Encoding]::UTF8
        }
        
        Send-MailMessage @mailParams -ErrorAction Stop
        Write-LogMessage "Email sent successfully to: $RecipientEmail ($($User.Name))" -Level "SUCCESS"
        return $true
        
    }
    catch {
        Write-LogMessage "Failed to send email to ${RecipientEmail}: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Write-LogEntry {
    param(
        [string]$LogPath,
        [Microsoft.ActiveDirectory.Management.ADUser]$User,
        [hashtable]$ExpirationData,
        [string]$Email,
        [bool]$EmailSent
    )
    
    try {
        $logEntry = @(
            (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
            $User.Name,
            $Email,
            $ExpirationData.DaysToExpire,
            $ExpirationData.ExpirationDate.ToString("yyyy-MM-dd"),
            $EmailSent,
            $ExpirationData.Status
        ) -join ","
        
        Add-Content -Path $LogPath -Value $logEntry -Encoding UTF8
    }
    catch {
        Write-LogMessage "Failed to write log entry: $($_.Exception.Message)" -Level "ERROR"
    }
}

try {
    Write-LogMessage "=== PASSWORD EXPIRATION NOTIFICATION STARTED ===" -Level "INFO"
    Write-LogMessage "Search Base: $defaultSearchBase" -Level "INFO"
    Write-LogMessage "Language: $language" -Level "INFO"
    Write-LogMessage "Test Mode: $testModeEnabled" -Level "INFO"
    Write-LogMessage "Logging: $loggingEnabled" -Level "INFO"
    
    $logFilePath = $null
    if ($loggingEnabled) {
        $logFileName = "PasswordNotification_$(Get-Date -Format 'yyyy-MM-dd').csv"
        $logFilePath = Join-Path -Path $logDirectory -ChildPath $logFileName
        
        if (-not (Initialize-LogFile -LogPath $logFilePath)) {
            Write-LogMessage "Continuing without logging..." -Level "WARN"
            $loggingEnabled = $false
        }
    }
    
    if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
        throw "Active Directory module not available. Please install RSAT tools."
    }
    
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-LogMessage "Active Directory module loaded successfully" -Level "SUCCESS"
    
    $defaultPasswordPolicy = Get-ADDefaultDomainPasswordPolicy -ErrorAction Stop
    $maxPasswordAge = $defaultPasswordPolicy.MaxPasswordAge
    Write-LogMessage "Default password age policy: $($maxPasswordAge.Days) days" -Level "INFO"
    
    $userFilter = {
        $_.Enabled -eq $true -and
        $_.PasswordNeverExpires -eq $false -and
        $_.PasswordExpired -eq $false
    }
    
    Write-LogMessage "Searching for users in: $defaultSearchBase" -Level "INFO"
    
    $adUsers = Get-ADUser -SearchBase $defaultSearchBase -Filter * -Properties Name, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress |
    Where-Object $userFilter
    
    Write-LogMessage "Found $($adUsers.Count) enabled users to process" -Level "INFO"
    
    $stats = @{
        Processed  = 0
        EmailsSent = 0
        Errors     = 0
        NoEmail    = 0
        Skipped    = 0
    }
    
    foreach ($user in $adUsers) {
        $stats.Processed++
        
        try {
            $expirationData = Get-PasswordExpirationData -User $user -DefaultMaxAge $maxPasswordAge
            
            if ($expirationData.DaysToExpire -ge 0 -and $expirationData.DaysToExpire -lt $expireInDays) {
                $recipientEmail = if ($testModeEnabled) { $testRecipient } else { $user.EmailAddress }
                
                if ([string]::IsNullOrWhiteSpace($recipientEmail)) {
                    $recipientEmail = $testRecipient
                    $stats.NoEmail++
                    Write-LogMessage "User without email address: $($user.Name)" -Level "WARN"
                }
                
                $emailSent = Send-PasswordExpiryAlert -User $user -ExpirationData $expirationData -RecipientEmail $recipientEmail
                
                if ($emailSent) {
                    $stats.EmailsSent++
                }
                
                if ($loggingEnabled) {
                    Write-LogEntry -LogPath $logFilePath -User $user -ExpirationData $expirationData -Email $recipientEmail -EmailSent $emailSent
                }
                
            }
            else {
                $stats.Skipped++
            }
            
        }
        catch {
            $stats.Errors++
            Write-LogMessage "Error processing user $($user.Name): $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    Write-LogMessage "=== PROCESSING COMPLETED ===" -Level "SUCCESS"
    Write-LogMessage "Users processed: $($stats.Processed)" -Level "INFO"
    Write-LogMessage "Emails sent: $($stats.EmailsSent)" -Level "SUCCESS"
    Write-LogMessage "Users without email: $($stats.NoEmail)" -Level "INFO"
    Write-LogMessage "Errors: $($stats.Errors)" -Level "INFO"
    Write-LogMessage "Skipped (not expiring): $($stats.Skipped)" -Level "INFO"
    
    if ($testModeEnabled) {
        Write-LogMessage "*** TEST MODE ACTIVE - All emails sent to: $testRecipient ***" -Level "WARN"
    }
    
    if ($loggingEnabled) {
        Write-LogMessage "Detailed log saved to: $logFilePath" -Level "INFO"
    }
    
}
catch {
    Write-LogMessage "Critical error during execution: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

Write-LogMessage "=== SCRIPT EXECUTION COMPLETED ===" -Level "SUCCESS"
