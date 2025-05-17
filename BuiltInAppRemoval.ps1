# Script version: 2025-05-03 19:05

# ---------------------------[ Script Start Timestamp ]---------------------------

# Capture start time to log script duration
$scriptStartTime = Get-Date

# ---------------------------[ Logging Setup ]---------------------------

# Logging control switches
$log = 1                         # 1 = Enable logging, 0 = Disable logging
$EnableLogFile = $true           # Set to $false to disable file output

# Application name used for folder/log naming
$scriptName = "Remove - Built-in apps"

# Define the log output location
$LogFileDirectory = "$env:ProgramData\IntuneLogs\Scripts"
$LogFile = "$LogFileDirectory\$scriptName.log"

# Ensure the log directory exists
if (-not (Test-Path $LogFileDirectory)) {
    New-Item -ItemType Directory -Path $LogFileDirectory -Force | Out-Null
}

# Function to write structured logs to file and console
function Write-Log {
    param ([string]$Message, [string]$Tag = "Info")

    if ($log -ne 1) { return } # Exit if logging is disabled

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $tagList = @("Start", "Check", "Info", "Success", "Error", "End")
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
        "End"     { "Cyan" }
        default   { "White" }
    }

    $logMessage = "$timestamp [  $rawTag ] $Message"

    # Write to file if enabled
    if ($EnableLogFile) {
        "$logMessage" | Out-File -FilePath $LogFile -Append
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

# ---------------------------[ Script Start ]---------------------------

Write-Log "======== Platform Script Started ========" -Tag "Start"
Write-Log "ComputerName: $env:COMPUTERNAME | User: $env:USERNAME | Script: $scriptName" -Tag "Info"

# ---------------------------[ Protected apps ]---------------------------

$protectedApps = @(
    "Microsoft.NET.Native.Framework.2.2",
    "Microsoft.VCLibs.140.00",
    "Microsoft.UI.Xaml.2.8",
    "Microsoft.VCLibs.140.00.UWPDesktop",
    "Microsoft.WindowsStore",
    "Microsoft.DesktopAppInstaller",
    "Microsoft.StorePurchaseApp",
    "Microsoft.WindowsTerminal",
    "Microsoft.ScreenSketch",
    "Microsoft.WindowsNotepad",
    "Microsoft.Windows.Photos"
)

# ---------------------------[ Apps to remove ]---------------------------

$appsToRemove = @(
    "Microsoft.Microsoft3DViewer",
    "Microsoft.WindowsAlarms",
    "Microsoft.Copilot",
    "Microsoft.549981C3F5F10",                  # Cortana
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.ZuneVideo",
    "Microsoft.ZuneMusic",
    "Microsoft.GetHelp",
    "Microsoft.YourPhone",
    "microsoft.windowscommunicationsapps",      # Mail and Calendar
    "Microsoft.WindowsCamera",
    "Microsoft.WindowsMaps",
    "Microsoft.People",                         # Contacts
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MixedReality.Portal",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.Office.OneNote",
    "Microsoft.OutlookForWindows",              # Outlook (new)
    "Microsoft.MSPaint",                        # Paint 3D (Windows 10)
    "Microsoft.SkypeApp",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.MicrosoftStickyNotes",
    "Microsoft.BingWeather",
    "Microsoft.Getstarted",
    "Microsoft.Windows.DevHome",
    "Clipchamp.Clipchamp",
    "Microsoft.Todos",
    "Microsoft.BingNews",
    "MicrosoftCorporationII.QuickAssist",       # Remote Help
    "Microsoft.PowerAutomateDesktop",
    "Microsoft.Whiteboard",
    "MicrosoftCorporationII.MicrosoftFamily",
    "Microsoft.MicrosoftJournal",
    "MicrosoftTeams",                           # Teams Personal
    "Microsoft.BingSearch",
    "Microsoft.XboxApp",
    "Microsoft.GamingApp",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.Xbox.TCUI"
#   "MSTeams"                                   # Teams
)

# ---------------------------[ Detect OS version ]---------------------------
 
$OSVersion = (Get-CimInstance Win32_OperatingSystem).Version
$IsWindows11 = $OSVersion -like "10.0.2*"
$IsWindows10 = $OSVersion -like "10.0.1*"
Write-Log "Detected OS Version: $OSVersion" -Tag "Info"

function Remove-AppIfInstalledForAllUsers {
    param ([string]$appName)
    Write-Log "Checking: $appName" -Tag "Check"
    $appPackages = Get-AppxPackage -Name $appName -AllUsers -ErrorAction SilentlyContinue
    if (-not $appPackages) {
        Write-Log "$appName is not installed" -Tag "Info"
        return
    }

    if ($IsWindows11) {
        foreach ($app in $appPackages) {
            try {
                Write-Log "Removing: $appName" -Tag "Info"
                Remove-AppxPackage -Package $app.PackageFullName -AllUsers -ErrorAction Stop
                Write-Log "$appName removed successfully" -Tag "Success"
            } catch {
                Write-Log "Failed to remove: $($appName): $_" -Tag "Error"
            }
        }
    } elseif ($IsWindows10) {
        foreach ($appPackage in $appPackages) {
            foreach ($userInfo in $appPackage.PackageUserInformation) {
                if ($null -ne $userInfo -and $userInfo -match "^(S-1-5-\d+-\d+-\d+-\d+-\d+)") {
                    $sid = $matches[1]
                    try {
                        Write-Log "Removing: $appName for: $sid" -Tag "Info"
                        Get-AppxPackage -User $sid -Name $appName | Remove-AppxPackage -User $sid -ErrorAction Stop
                        Write-Log "$appName removed successfully for: $sid" -Tag "Success"
                    } catch {
                        Write-Log "Failed to remove: $appName for: $($sid): $_" -Tag "Error"
                    }
                }
            }
        }
    }
}

function Remove-ProvisionedApp {
    param ([string]$appName)
    # Write-Log "Checking provisioned packages for $appName..." -Tag "Check"
    try {
        $provisionedApps = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like "*$appName*"
        if ($provisionedApps) {
            foreach ($provisionedApp in $provisionedApps) {
                # Write-Log "Removing provisioned app: $($provisionedApp.DisplayName)" -Tag "Info"
                Remove-AppxProvisionedPackage -Online -PackageName $provisionedApp.PackageName -ErrorAction Stop
                Write-Log "Provisioned app removed: $($provisionedApp.DisplayName)" -Tag "Success"
            }
        } else {
            # Write-Log "$appName is not provisioned." -Tag "Info"
        }
    } catch {
        Write-Log "Failed to remove provisioned app $($appName): $_" -Tag "Error"
    }
}

foreach ($app in $appsToRemove) {

    if ($app -in $protectedApps) {
        Write-Log "$app is protected and will not be removed" -Tag "Info"
        continue
    }

    Remove-AppIfInstalledForAllUsers -appName $app | Out-Null
    Remove-ProvisionedApp -appName $app | Out-Null
}

Complete-Script -ExitCode 0