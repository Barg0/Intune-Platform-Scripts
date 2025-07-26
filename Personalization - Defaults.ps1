# Script version:   2025-05-29 11:28
# Script author:    Barg0

# ---------------------------[ Script Start Timestamp ]---------------------------

# Capture start time to log script duration
$scriptStartTime = Get-Date

# ---------------------------[ Script name ]---------------------------

# Script name used for folder/log naming
$scriptName = "Personalization - Defaults"
$logFileName = "$($scriptName)" + ".log"

# ---------------------------[ Logging Setup ]---------------------------

# Logging control switches
$log = $true                     # Set to $false to disable logging in shell
$enableLogFile = $true           # Set to $false to disable file output

# Define the log output location
$logFileDirectory = "$env:ProgramData\IntuneLogs\Scripts\$env:USERNAME"
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

# ---------------------------[ Registry Helper ]---------------------------

function Set-RegistryKeyIfNotExists {
    param (
        [string]$Hive,
        [string]$KeyPath,
        [string]$ValueName,
        [string]$ValueType,
        [string]$ValueData
    )
    $currentValue = (Get-ItemProperty -Path "$Hive\$KeyPath" -Name $ValueName -ErrorAction SilentlyContinue).$ValueName
    if ($currentValue -ne $ValueData) {
        Write-Log "Setting $Hive\$KeyPath\$ValueName to $ValueData" "Info"
        reg.exe add "$Hive\$KeyPath" /v "$ValueName" /t "$ValueType" /d "$ValueData" /f | Out-Null
    } else {
        Write-Log "$Hive\$KeyPath\$ValueName already set to desired value. Skipping." "Success"
    }
}

function Test-RegistryKeyValue {
    param (
        [string]$Hive,
        [string]$KeyPath,
        [string]$ValueName,
        [string]$ExpectedValue
    )

    $resolvedPath = switch ($Hive) {
        "HKEY_CURRENT_USER" { "HKCU:\$KeyPath" }
        "HKEY_LOCAL_MACHINE" { "HKLM:\$KeyPath" }
        default {
            Write-Log "Unsupported registry hive: $Hive" "Error"
            return $false
        }
    }

    try {
        $actualValue = (Get-ItemProperty -Path $resolvedPath -Name $ValueName -ErrorAction Stop).$ValueName
        if ("$actualValue" -eq "$ExpectedValue") {
            Write-Log "Verified: $Hive\$KeyPath\$ValueName = $ExpectedValue" "Success"
            return $true
        } else {
            Write-Log "Mismatch: $Hive\$KeyPath\$ValueName is '$actualValue', expected '$ExpectedValue'" "Error"
            return $false
        }
    } catch {
        Write-Log "Missing: Could not read $Hive\$KeyPath\$ValueName - $_" "Error"
        return $false
    }
}

# ---------------------------[ Script Start ]---------------------------

Write-Log "======== Platform Script Started ========" -Tag "Start"
Write-Log "ComputerName: $env:COMPUTERNAME | User: $env:USERNAME | Script: $scriptName" -Tag "Info"

# ---------------------------[ Main Execution ]---------------------------

# Write-Log "Stopping explorer.exe task..." "Info"
# Stop-Process -Name explorer -Force

$OSVersion = (Get-WmiObject -Class Win32_OperatingSystem).Version
Write-Log "Detected OS Version: $OSVersion" -Tag "Info"

$allChecksPassed = $true
$dwordData = $null

if ($OSVersion.StartsWith("10.0.2")) {
    Write-Log "Windows 11 detected. Proceeding with registry modifications." "Info"

    reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve | Out-Null
    Write-Log "Enabled classic context menu." "Success"
    

    $registryKeysWindows11 = @(
        @{Hive = "HKEY_CURRENT_USER"; KeyPath = "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName = "TaskbarAl"; ValueType = "REG_DWORD"; ValueData = "0"},
        @{Hive = "HKEY_CURRENT_USER"; KeyPath = "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName = "ShowTaskViewButton"; ValueType = "REG_DWORD"; ValueData = "0"},
        @{Hive = "HKEY_CURRENT_USER"; KeyPath = "Software\Microsoft\Windows\CurrentVersion\Search"; ValueName = "SearchboxTaskbarMode"; ValueType = "REG_DWORD"; ValueData = "1"},
        @{Hive = "HKEY_CURRENT_USER"; KeyPath = "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"; ValueName = "SystemUsesLightTheme"; ValueType = "REG_DWORD"; ValueData = "0"},
        @{Hive = "HKEY_CURRENT_USER"; KeyPath = "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"; ValueName = "AppsUseLightTheme"; ValueType = "REG_DWORD"; ValueData = "1"},
        @{Hive = "HKEY_CURRENT_USER"; KeyPath = "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"; ValueName = "EnableTransparency"; ValueType = "REG_DWORD"; ValueData = "1"},
        @{Hive = "HKEY_CURRENT_USER"; KeyPath = "Control Panel\Desktop"; ValueName = "AutoColorization"; ValueType = "REG_DWORD"; ValueData = "1"}
    )

    foreach ($key in $registryKeysWindows11) {
        Set-RegistryKeyIfNotExists @key
    }

    # Validate normal keys
    foreach ($key in $registryKeysWindows11) {
        if (-not (Test-RegistryKeyValue -Hive $key.Hive -KeyPath $key.KeyPath -ValueName $key.ValueName -ExpectedValue $key.ValueData)) {
            $allChecksPassed = $false
        }
    }

    # Validate context menu key only once
    Write-Log "Validating classic context menu key..." "Check"
    if (-not (Test-RegistryKeyValue -Hive "HKEY_CURRENT_USER" -KeyPath "Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -ValueName "" -ExpectedValue "")) {
        $allChecksPassed = $false
    }

} elseif ($OSVersion.StartsWith("10.0.1")) {
    Write-Log "Windows 10 detected. Proceeding with registry modifications." "Info"

    $registryKeysWindows10 = @(
        @{Hive = "HKEY_CURRENT_USER"; KeyPath = "Software\Microsoft\Windows\CurrentVersion\Explorer"; ValueName = "EnableAutoTray"; ValueType = "REG_DWORD"; ValueData = "0"},
        @{Hive = "HKEY_CURRENT_USER"; KeyPath = "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName = "ShowCortanaButton"; ValueType = "REG_DWORD"; ValueData = "0"},
        @{Hive = "HKEY_CURRENT_USER"; KeyPath = "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName = "ShowTaskViewButton"; ValueType = "REG_DWORD"; ValueData = "0"},
        @{Hive = "HKEY_CURRENT_USER"; KeyPath = "Software\Microsoft\Windows\CurrentVersion\Search"; ValueName = "SearchboxTaskbarMode"; ValueType = "REG_DWORD"; ValueData = "1"},
        @{Hive = "HKEY_CURRENT_USER"; KeyPath = "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"; ValueName = "SystemUsesLightTheme"; ValueType = "REG_DWORD"; ValueData = "0"},
        @{Hive = "HKEY_CURRENT_USER"; KeyPath = "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"; ValueName = "AppsUseLightTheme"; ValueType = "REG_DWORD"; ValueData = "1"},
        @{Hive = "HKEY_CURRENT_USER"; KeyPath = "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"; ValueName = "EnableTransparency"; ValueType = "REG_DWORD"; ValueData = "1"},
        @{Hive = "HKEY_CURRENT_USER"; KeyPath = "Control Panel\Desktop"; ValueName = "AutoColorization"; ValueType = "REG_DWORD"; ValueData = "1"}
    )

    foreach ($key in $registryKeysWindows10) {
        Set-RegistryKeyIfNotExists @key
    }

    # ----- BEGIN: Your original hash logic for Feeds -----
    $MethodDefinition = @'
    [DllImport("Shlwapi.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = false)]
    public static extern int HashData(byte[] pbData, int cbData, byte[] piet, int outputLen);
'@
    $Shlwapi = Add-Type -MemberDefinition $MethodDefinition -Name 'Shlwapi' -Namespace 'Win32' -PassThru
    $option = 2 # 2 is for off

    $machineIdReg = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\SQMClient\' -Name 'MachineId' -ErrorAction SilentlyContinue
    $machineId = '{C283D224-5CAD-4502-95F0-2569E4C85074}' # Fallback

    if ($machineIdReg) {
        $machineId = $machineIdReg.MachineId
    }

    $combined = $machineId + '_' + $option.ToString()
    $reverse = $combined[($combined.Length - 1)..0] -join ''
    $bytesIn = [System.Text.Encoding]::Unicode.GetBytes($reverse)
    $bytesOut = [byte[]]::new(4)
    $Shlwapi::HashData($bytesIn, 0x53, $bytesOut, $bytesOut.Count) | Out-Null

    $dwordData = [System.BitConverter]::ToUInt32($bytesOut, 0)
    Set-RegistryKeyIfNotExists -Hive "HKEY_CURRENT_USER" -KeyPath "SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" -ValueName "EnShellFeedsTaskbarViewMode" -ValueType "REG_DWORD" -ValueData $dwordData
    # ----- END -----

    foreach ($key in $registryKeysWindows10) {
        if (-not (Test-RegistryKeyValue -Hive $key.Hive -KeyPath $key.KeyPath -ValueName $key.ValueName -ExpectedValue $key.ValueData)) {
            $allChecksPassed = $false
        }
    }
    if (-not (Test-RegistryKeyValue -Hive "HKEY_CURRENT_USER" -KeyPath "SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" -ValueName "EnShellFeedsTaskbarViewMode" -ExpectedValue $dwordData)) {
        $allChecksPassed = $false
    }

} else {
    Write-Log "Unsupported Windows version detected. Exiting." "Error"
    Complete-Script -ExitCode 1
}

# ---------------------------[ Finalize ]---------------------------

Write-Log "Restarting explorer..." "Info"
Stop-Process -Name explorer -Force
Start-Process -FilePath "explorer.exe"

if ($allChecksPassed) {
    Complete-Script -ExitCode 0
} else {
    Complete-Script -ExitCode 1
}
