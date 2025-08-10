# ---------------------------[ Script Start Timestamp ]---------------------------

# Capture start time to log script duration
$scriptStartTime = Get-Date

# ---------------------------[ Script name ]---------------------------

# Script name used for folder/log naming
$scriptName   = "Device Preparation - Rename - Notebook"
$logFileName  = "$($scriptName).log"

# ---------------------------[ Parameter ]---------------------------

# Prefix for device name
$deviceNamePrefix = "NB-"

# ---------------------------[ Logging Setup ]---------------------------

# Logging control switches
$log = $true                     # Set to $false to disable logging in shell
$enableLogFile = $true           # Set to $false to disable file output

# Define the log output location
$logFileDirectory = "$env:ProgramData\IntuneLogs\Scripts"
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
        "Debug"   { "DarkYellow" }
        "End"     { "Cyan" }
        default   { "White" }
    }

    $logMessage = "$timestamp [  $rawTag ] $Message"

    # Write to file if enabled
    if ($enableLogFile) {
        "$logMessage" | Out-File -FilePath $logFile -Append -Encoding UTF8
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
    Write-Log "======== Script Completed ========" -Tag "End"
    exit $ExitCode
}

# ---------------------------[ Helpers ]---------------------------

function Get-DeviceSerial {
    <#
        Attempts to read a reliable serial number.
        Primary: Win32_BIOS.SerialNumber
        Fallback: Win32_ComputerSystemProduct.IdentifyingNumber
    #>
    try {
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
        $s = $bios.SerialNumber
        if ([string]::IsNullOrWhiteSpace($s)) {
            throw "Empty BIOS serial"
        }
        return $s
    } catch {
        Write-Log "BIOS serial unavailable: $($_.Exception.Message). Trying ComputerSystemProduct..." -Tag "Debug"
        try {
            $csp = Get-CimInstance -ClassName Win32_ComputerSystemProduct -ErrorAction Stop
            $s = $csp.IdentifyingNumber
            if ([string]::IsNullOrWhiteSpace($s)) {
                throw "Empty IdentifyingNumber"
            }
            return $s
        } catch {
            Write-Log "Fallback serial unavailable: $($_.Exception.Message)" -Tag "Error"
            return $null
        }
    }
}

function Build-TargetName {
    param(
        [Parameter(Mandatory)][string]$SerialRaw,
        [Parameter(Mandatory)][string]$Prefix
    )

    # Normalize serial: remove spaces, keep only A-Z/0-9, uppercase
    $clean = ($SerialRaw -replace '\s','')
    $clean = ($clean -replace '[^A-Za-z0-9]','')
    $clean = $clean.ToUpper()

    if ([string]::IsNullOrWhiteSpace($clean)) {
        throw "Serial number is empty after cleaning. Cannot build name."
    }

    # Windows limit: 15 characters total
    $maxTotal = 15
    $maxSerialPart = [Math]::Max(0, $maxTotal - $Prefix.Length)

    if ($clean.Length -gt $maxSerialPart) {
        # keep the END of the serial (trim the FRONT) to fit
        $clean = $clean.Substring($clean.Length - $maxSerialPart, $maxSerialPart)
    }

    $name = "$Prefix$clean"

    # Final safety checks
    if ($name.Length -gt 15) {
        throw "Calculated name '$name' exceeds 15 characters."
    }
    if ($name -notmatch '^[A-Z0-9-]+$') {
        throw "Calculated name '$name' contains invalid characters."
    }

    return $name
}

function CurrentNameMatches {
    param(
        [Parameter(Mandatory)][string]$TargetName
    )
    # Computer name comparison is case-insensitive
    return ($env:COMPUTERNAME -ieq $TargetName)
}

# ---------------------------[ Script Start ]---------------------------

Write-Log "======== Script Started ========" -Tag "Start"
Write-Log "ComputerName: $env:COMPUTERNAME | User: $env:USERNAME | Script: $scriptName" -Tag "Info"

# ---------------------------[ Prefix ]---------------------------

# --- Sanitize & normalize the prefix ---
# 1) remove spaces  2) strip non A-Z/0-9/-  3) uppercase
$deviceNamePrefix = ($deviceNamePrefix -replace '\s','' -replace '[^A-Za-z0-9-]','').ToUpper()

# Ensure it ends with a single dash (optional convention for readability)
# if ($deviceNamePrefix.Length -gt 0 -and $deviceNamePrefix[-1] -ne '-') {
#     $deviceNamePrefix += '-'
# }

# Must not be empty after sanitization
if ([string]::IsNullOrWhiteSpace($deviceNamePrefix)) {
    Write-Log "Prefix is empty after sanitization." -Tag "Error"
    exit 1
}

# If the prefix alone reaches/exceeds 15 chars, trim it to 15 (still a valid hostname; leaves 0 for serial)
if ($deviceNamePrefix.Length -ge 15) {
    $deviceNamePrefix = $deviceNamePrefix.Substring(0,15)
}

# ---------------------------[ Rename ]---------------------------

try {
    # Write-Log "Retrieving device serial number..." -Tag "Check"
    $serial = Get-DeviceSerial
    if ($null -eq $serial) {
        Write-Log "Could not obtain a device serial number from WMI. Aborting." -Tag "Error"
        Complete-Script -ExitCode 1
    }
    Write-Log "Serial number: '$serial'" -Tag "Debug"

    # Write-Log "Building target hostname with prefix and enforcing 15-char limit..." -Tag "Check"
    $targetName = Build-TargetName -SerialRaw $serial -Prefix $deviceNamePrefix
    Write-Log "Target hostname computed: $targetName" -Tag "Info"

    if (CurrentNameMatches -TargetName $targetName) {
        Write-Log "Hostname already set to target value. No action required." -Tag "Success"
        # We do NOT reboot here by design.
        Complete-Script -ExitCode 0
    }

    # Validate final length/characters just to be extra safe (should already pass)
    if ($targetName.Length -gt 15) {
        Write-Log "Calculated name '$targetName' exceeds 15 characters. This should not happen. Aborting." -Tag "Error"
        Complete-Script -ExitCode 1
    }
    if ($targetName -notmatch '^[A-Z0-9-]+$') {
        Write-Log "Calculated name '$targetName' contains invalid characters. Aborting." -Tag "Error"
        Complete-Script -ExitCode 1
    }

    # Write-Log "Renaming computer to '$targetName' (no reboot)..." -Tag "Info"
    try {
        # Using Rename-Computer without restart; change takes effect after a reboot
        Rename-Computer -NewName $targetName -Force -ErrorAction Stop | Out-Null
        Write-Log "Rename command executed successfully. A reboot is required for the new name to take effect." -Tag "Success"
        # Write-Log "No reboot will be performed by this script. Reboot via a later step/policy." -Tag "Info"
        Complete-Script -ExitCode 0
    } catch {
        Write-Log "Failed to rename computer: $($_.Exception.Message)" -Tag "Error"
        Complete-Script -ExitCode 1
    }

} catch {
    Write-Log "Unexpected error: $($_.Exception.Message)" -Tag "Error"
    Complete-Script -ExitCode 1
}

