# ---------------------------[ Script Start Timestamp ]---------------------------
$scriptStartTime = Get-Date

# ---------------------------[ Script Name ]---------------------------
$scriptName  = "Remove-BuiltInApps"
$logFileName = "Remove-BuiltInApps.log"

# ---------------------------[ Configuration ]---------------------------
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

$removeProvisionedOnWindows11 = $false

$targetApps = @(
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
    "Microsoft.People",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MixedReality.Portal",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.Office.OneNote",
    "Microsoft.OutlookForWindows",
    "Microsoft.MSPaint",
    "Microsoft.SkypeApp",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.MicrosoftStickyNotes",
    "Microsoft.BingWeather",
    "Microsoft.Getstarted",
    "Microsoft.Windows.DevHome",
    "Clipchamp.Clipchamp",
    "Microsoft.Todos",
    "Microsoft.BingNews",
    "MicrosoftCorporationII.QuickAssist",
    "Microsoft.PowerAutomateDesktop",
    "Microsoft.Whiteboard",
    "MicrosoftCorporationII.MicrosoftFamily",
    "Microsoft.MicrosoftJournal",
    "MicrosoftTeams",
    "Microsoft.BingSearch",
    "Microsoft.XboxApp",
    "Microsoft.GamingApp",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.Xbox.TCUI"
)

# ---------------------------[ Logging Setup ]---------------------------
$log           = $true
$logDebug      = $false
$logGet        = $true
$logRun        = $true
$enableLogFile = $true

$logFileDirectory = "$env:ProgramData\IntuneLogs\Scripts"
$logFile          = "$logFileDirectory\$logFileName"

if ($enableLogFile -and -not (Test-Path -Path $logFileDirectory)) {
    New-Item -ItemType Directory -Path $logFileDirectory -Force | Out-Null
}

# ---------------------------[ Logging Function ]---------------------------
function Write-Log {
    [CmdletBinding()]
    param (
        [string]$Message,
        [string]$Tag = "Info"
    )

    if (-not $log) { return }

    if (($Tag -eq "Debug") -and (-not $logDebug)) { return }
    if (($Tag -eq "Get")   -and (-not $logGet))   { return }
    if (($Tag -eq "Run")   -and (-not $logRun))   { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $tagList   = @("Start","Get","Run","Info","Success","Error","Debug","End")
    $rawTag    = $Tag.Trim()

    if ($tagList -contains $rawTag) {
        $rawTag = $rawTag.PadRight(7)
    } else {
        $rawTag = "Error  "
    }

    $color = switch ($rawTag.Trim()) {
        "Start"   { "Cyan" }
        "Get"     { "Blue" }
        "Run"     { "Magenta" }
        "Info"    { "Yellow" }
        "Success" { "Green" }
        "Error"   { "Red" }
        "Debug"   { "DarkYellow" }
        "End"     { "Cyan" }
        default   { "White" }
    }

    $logMessage = "$timestamp [  $rawTag ] $Message"

    if ($enableLogFile) {
        try {
            Add-Content -Path $logFile -Value $logMessage -Encoding UTF8
        } catch {
            # Logging must never block script execution
        }
    }

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
    $duration      = $scriptEndTime - $scriptStartTime

    Write-Log "Script execution time: $($duration.ToString('hh\:mm\:ss\.ff'))" -Tag "Info"
    Write-Log "Exit Code: $ExitCode" -Tag "Info"
    Write-Log "======== Script Completed ========" -Tag "End"

    exit $ExitCode
}

# ---------------------------[ Script Start ]---------------------------
Write-Log "======== Script Started ========" -Tag "Start"
Write-Log "ComputerName: $env:COMPUTERNAME | User: $env:USERNAME | Script: $scriptName" -Tag "Info"

# ---------------------------[ OS Detection ]---------------------------
$osVersion   = (Get-CimInstance Win32_OperatingSystem).Version
$isWindows11 = $osVersion -like "10.0.2*"
$isWindows10 = $osVersion -like "10.0.1*"

Write-Log "Detected OS version: $osVersion" -Tag "Get"

if ($isWindows11) {
    Write-Log "Operating system identified as Windows 11" -Tag "Info"
} elseif ($isWindows10) {
    Write-Log "Operating system identified as Windows 10" -Tag "Info"
} else {
    Write-Log "Unsupported OS version: $osVersion - script requires Windows 10 or 11" -Tag "Error"
    Complete-Script -ExitCode 1
}

# ---------------------------[ Functions ]---------------------------
$sidPattern = "^(S-1-5-\d+-\d+-\d+-\d+-\d+)"

function Uninstall-InstalledApp {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$AppName
    )

    Write-Log "Querying installed packages for $AppName" -Tag "Get"
    $installedPackages = Get-AppxPackage -Name $AppName -AllUsers -ErrorAction SilentlyContinue

    if (-not $installedPackages) {
        Write-Log "$AppName is not installed for any user" -Tag "Debug"
        return
    }

    if ($isWindows11) {
        foreach ($package in $installedPackages) {
            try {
                Write-Log "Removing $AppName for all users" -Tag "Run"
                Write-Log "PackageFullName: $($package.PackageFullName)" -Tag "Debug"
                Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
                Write-Log "$AppName removed successfully for all users" -Tag "Success"
            } catch {
                Write-Log "Failed to remove $AppName - $($_.Exception.Message)" -Tag "Error"
                Write-Log "Full error: $_" -Tag "Debug"
            }
        }
    } elseif ($isWindows10) {
        foreach ($package in $installedPackages) {
            foreach ($userInfo in $package.PackageUserInformation) {
                if ($null -ne $userInfo -and $userInfo -match $sidPattern) {
                    $userSid = $matches[1]
                    try {
                        Write-Log "Removing $AppName for user SID $userSid" -Tag "Run"
                        Get-AppxPackage -User $userSid -Name $AppName |
                            Remove-AppxPackage -User $userSid -ErrorAction Stop
                        Write-Log "$AppName removed successfully for user SID $userSid" -Tag "Success"
                    } catch {
                        Write-Log "Failed to remove $AppName for user SID $userSid - $($_.Exception.Message)" -Tag "Error"
                        Write-Log "Full error: $_" -Tag "Debug"
                    }
                }
            }
        }
    }
}

function Uninstall-ProvisionedApp {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$AppName
    )

    try {
        Write-Log "Querying provisioned packages for $AppName" -Tag "Get"
        $provisionedPackages = Get-AppxProvisionedPackage -Online |
            Where-Object { $_.DisplayName -eq $AppName }

        if (-not $provisionedPackages) {
            Write-Log "$AppName is not provisioned" -Tag "Debug"
            return
        }

        foreach ($package in $provisionedPackages) {
            try {
                Write-Log "Removing provisioned package $($package.DisplayName)" -Tag "Run"
                Write-Log "PackageName: $($package.PackageName)" -Tag "Debug"
                Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction Stop | Out-Null
                Write-Log "Provisioned package $($package.DisplayName) removed successfully" -Tag "Success"
            } catch {
                Write-Log "Failed to remove provisioned package $($package.DisplayName) - $($_.Exception.Message)" -Tag "Error"
                Write-Log "Full error: $_" -Tag "Debug"
            }
        }
    } catch {
        Write-Log "Failed to query provisioned packages for $AppName - $($_.Exception.Message)" -Tag "Error"
        Write-Log "Full error: $_" -Tag "Debug"
    }
}

# ---------------------------[ Main Execution ]---------------------------
Write-Log "Processing $($targetApps.Count) apps for removal" -Tag "Info"
Write-Log "Protected apps count: $($protectedApps.Count)" -Tag "Debug"

foreach ($appName in $targetApps) {
    if ($appName -in $protectedApps) {
        Write-Log "$appName is protected - skipping removal" -Tag "Info"
        continue
    }

    Uninstall-InstalledApp -AppName $appName

    if ($isWindows10 -or $removeProvisionedOnWindows11) {
        Uninstall-ProvisionedApp -AppName $appName
    }
}

# ---------------------------[ Complete ]---------------------------
Complete-Script -ExitCode 0
