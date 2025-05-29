# Script version:   2025-05-29 11:38
# Script author:    Barg0

# ---------------------------[ Script Start Timestamp ]---------------------------

$scriptStartTime = Get-Date

# ---------------------------[ Script name ]---------------------------

# Script name used for folder/log naming
$scriptName = "Create - admin.laps"
$logFileName = "$scriptName.log"

# ---------------------------[ User Variables ]---------------------------

$userName = "admin.laps"
$userFullName = "LAPS Administrator"
$userDescription = "LAPS"

# ---------------------------[ Logging Setup ]---------------------------

# Logging control switches
$log = $true                     # Set to $false to disable logging in shell
$enableLogFile = $true           # Set to $false to disable file output

# Define the log output location
$logFileDirectory = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\Scripts"
$logFile = "$logFileDirectory\$logFileName"

# Ensure the log directory exists
if ($enableLogFile -and -not (Test-Path $logFileDirectory)) {
    New-Item -ItemType Directory -Path $logFileDirectory -Force | Out-Null
}

# Function to write structured logs to file and console
function Write-Log {
    param ([string]$Message, [string]$Tag = "Info")

    if (-not $log) { return } # Exit if logging is disabled

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $tagList = @("Start", "Check", "Info", "Success", "Error", "Debug", "End")
    $rawTag = $Tag.Trim()

    if ($tagList -contains $rawTag) {
        $rawTag = $rawTag.PadRight(7)
    } else {
        $rawTag = "Error  "  # Fallback if an unrecognized tag is used
    }

    # Set tag colors
    $color = switch ($rawTag.Trim()) {
        "Start"   { "Cyan" }
        "Check"   { "Blue" }
        "Info"    { "Yellow" }
        "Success" { "Green" }
        "Error"   { "Red" }
        "Debug"   { "DarkYellow"}
        "End"     { "Cyan" }
        default   { "White" }
    }

    $logMessage = "$timestamp [  $rawTag ] $Message"

    # Write to file if enabled
    if ($enableLogFile) {
        "$logMessage" | Out-File -FilePath $logFile -Append
    }

    # Write to console with color formatting
    Write-Host "$timestamp " -NoNewline
    Write-Host "[  " -NoNewline -ForegroundColor White
    Write-Host "$rawTag" -NoNewline -ForegroundColor $color
    Write-Host " ] " -NoNewline -ForegroundColor White
    Write-Host "$Message"
}

# ---------------------------[ Exit Function ]---------------------------

function Complete-Script {
    param([int]$ExitCode)
    $scriptEndTime = Get-Date
    $duration = $scriptEndTime - $scriptStartTime
    Write-Log "Script execution time: $($duration.ToString("hh\:mm\:ss\.ff"))" -Tag "Info"
    Write-Log "Exit Code: $ExitCode" -Tag "Info"
    Write-Log "======== Platform Script Completed ========" -Tag "End"
    exit $ExitCode
}
# Complete-Script -ExitCode 0

# ---------------------------[ Script Start ]---------------------------

Write-Log "======== Platform Script Started ========" -Tag "Start"
Write-Log "ComputerName: $env:COMPUTERNAME | User: $env:USERNAME | Script: $scriptName" -Tag "Info"


# ---------------------------[ Password Generator ]---------------------------

function New-SecureRandomPassword {
    $length = 16
    $allowed = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789!@#$%^&*()-_=+'.ToCharArray()

    do {
        $plainPassword = -join ((1..$length) | ForEach-Object { $allowed | Get-Random })
    } while (
        ($plainPassword -notmatch '[A-Z]') -or
        ($plainPassword -notmatch '[a-z]') -or
        ($plainPassword -notmatch '\d') -or
        ($plainPassword -notmatch '[!@#$%^&*()\-_=+]')
    )

    Write-Log "Generated secure random password." -Tag "Success"
    return (ConvertTo-SecureString $plainPassword -AsPlainText -Force)
}


# ---------------------------[ Check If User Exists ]---------------------------

function Test-LocalUserExists {
    param ([string]$userName)

    Write-Log "Checking if user $userName exists..." -Tag "Check"
    $user = Get-LocalUser -Name $userName -ErrorAction SilentlyContinue

    if ($null -ne $user) {
        Write-Log "User $userName exists." -Tag "Success"
        return $true
    } else {
        Write-Log "User $userName does not exist." -Tag "Info"
        return $false
    }
}

# ---------------------------[ Create Local User ]---------------------------

function New-CustomLocalUser {
    param (
        [string]$userName,
        [securestring]$SecurePassword
    )

    Write-Log "Attempting to create local user $($userName)..." -Tag "Info"

    try {
        New-LocalUser -Name $userName -Password $SecurePassword -FullName $userFullName -Description $userDescription
        Write-Log "User $userName created successfully." -Tag "Success"
        return $true
    }
    catch {
        Write-Log "Error creating user $($userName): $_" -Tag "Error"
        return $false
    }
}

# ---------------------------[ Main Execution Logic ]---------------------------

if (Test-LocalUserExists -UserName $userName) {
    Write-Log "No action needed. Exiting script." -Tag "Info"
    Complete-Script -ExitCode 0
}
else {
    $securePassword = New-SecureRandomPassword

    if (New-CustomLocalUser -UserName $userName -SecurePassword $securePassword) {
        if (Test-LocalUserExists -UserName $userName) {
            Write-Log "User $userName successfully verified after creation." -Tag "Success"
            Complete-Script -ExitCode 0
        } else {
            Write-Log "User $userName could not be verified after creation." -Tag "Error"
            Complete-Script -ExitCode 1
        }
    } else {
        Write-Log "User creation failed." -Tag "Error"
        Complete-Script -ExitCode 1
    }
}