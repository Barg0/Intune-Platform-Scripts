# ---------------------------[ Script Start Timestamp ]---------------------------

# Capture start time to log script duration
$scriptStartTime = Get-Date

# ---------------------------[ Script name ]---------------------------

# Script name used for folder/log naming
$scriptName = "Winget - System Context"
$logFileName  = "$($scriptName).log"

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
    Write-Log "======== Script Completed ========" -Tag "End"
    exit $ExitCode
}
# Complete-Script -ExitCode 0

# ---------------------------[ Script Start ]---------------------------

Write-Log "======== Script Started ========" -Tag "Start"
Write-Log "ComputerName: $env:COMPUTERNAME | User: $env:USERNAME | Script: $scriptName" -Tag "Info"

# ---------------------------[ Winget Path Resolver ]---------------------------

function Get-WingetPath {
    $wingetBase = "$env:ProgramW6432\WindowsApps"
    try {
        # Try x64 first
        $wingetFolders = Get-ChildItem -Path $wingetBase -Directory -ErrorAction Stop |
            Where-Object { $_.Name -like 'Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe' }

        # If x64 not found, try arm64
        if (-not $wingetFolders) {
            $wingetFolders = Get-ChildItem -Path $wingetBase -Directory -ErrorAction Stop |
                Where-Object { $_.Name -like 'Microsoft.DesktopAppInstaller_*_arm64__8wekyb3d8bbwe' }
        }

        if (-not $wingetFolders) {
            throw "No matching Winget installation folders found (x64 or arm64)."
        }

        $latestWingetFolder = $wingetFolders |
            Sort-Object CreationTime -Descending |
            Select-Object -First 1

        $wingetPath = Join-Path $latestWingetFolder.FullName 'winget.exe'

        if (-not (Test-Path $wingetPath)) {
            throw "winget.exe not found at expected location."
        }

        return $wingetPath
    }
    catch {
        Write-Log "Failed to detect Winget installation: $_" -Tag "Error"
        Complete-Script -ExitCode 1
    }
}

# ---------------------------[ Winget Repair Function ]---------------------------

function Invoke-WingetRepair {
    Write-Log "Starting Winget repair..." -Tag "Info"

    Register-WingetDependencyPaths

    Write-Log "Restart required..." -Tag "Info"
    Complete-Script -ExitCode 0
}

function Register-WingetDependencyPaths {
    Write-Log "Registering Winget dependency DLL directories into SYSTEM PATH..." -Tag "Info"
    try {
        $windowsApps = "$env:ProgramW6432\WindowsApps"
        if (-not (Test-Path $windowsApps)) {
            Write-Log "WindowsApps folder not found: $windowsApps" -Tag "Error"
            return $false
        }

        $dllPackages = @(
            'Microsoft.VCLibs.140.00.UWPDesktop',
            'Microsoft.UI.Xaml.2.8'
        )

        $pathsToAdd = @()
        foreach ($pkg in $dllPackages) {
            # Prefer x64 like Get-WingetPath, then fall back to arm64
            $folder = Get-ChildItem -Path $windowsApps -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "$pkg*_x64__*" } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

            if (-not $folder) {
                $folder = Get-ChildItem -Path $windowsApps -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like "$pkg*_arm64__*" } |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1

                if ($folder) {
                    Write-Log "Found $pkg (arm64) at: $($folder.FullName)" -Tag "Info"
                }
            } else {
                Write-Log "Found $pkg (x64) at: $($folder.FullName)" -Tag "Info"
            }

            if ($folder) {
                $pathsToAdd += $folder.FullName
            } else {
                Write-Log "Could not find folder for $pkg (checked x64 and arm64)" -Tag "Error"
            }
        }

        $currentPath = [Environment]::GetEnvironmentVariable('Path','Machine')
        if ($null -eq $currentPath) { $currentPath = '' }

        $updated = $false
        foreach ($path in $pathsToAdd | Select-Object -Unique) {
            if ($currentPath -notlike "*$path*") {
                Write-Log "Adding path to SYSTEM PATH: $path" -Tag "Info"
                $currentPath += ";$path"
                $updated = $true
            } else {
                Write-Log "Path already present: $path" -Tag "Debug"
            }
        }

        if ($updated) {
            [Environment]::SetEnvironmentVariable('Path', $currentPath, 'Machine')
            Write-Log "SYSTEM PATH updated with dependency directories." -Tag "Success"
        } else {
            Write-Log "No changes made to SYSTEM PATH." -Tag "Info"
        }
        return $updated
    }
    catch {
        Write-Log "Failed to update SYSTEM PATH: $($_)" -Tag "Error"
        return $false
    }
}

function Test-Winget {
    # Write-Log "Checking Winget version" -Tag "Debug"
    $wingetPath = Get-WingetPath
    $output = & $wingetPath -v
    $exitCode = $LASTEXITCODE

    if ($null -ne $output -and $exitCode -eq 0) {
        Write-Log "Winget version: $output" -Tag "Info"
    } else {
        Write-Log "Winget execution failed with exit code: $exitCode" -Tag "Error"
        Write-Log "Winget output: $output" -Tag "Debug"
    }

    return $exitCode -eq 0
}

# ---------------------------[ Main Logic ]-------------------------------------

try {
    if (Test-Winget) {
        Write-Log "Winget is healthy. Nothing to do." -Tag "Success"
        Complete-Script -ExitCode 0
        return
    }

    Write-Log "Winget check failed - attempting repair." -Tag "Info"
    Invoke-WingetRepair

    # Do NOT re-test now: a restart is required for changes to take effect
    Write-Log "Repair completed. Restart required. Exiting with 0 so Intune can retry later." -Tag "Info"
    Complete-Script -ExitCode 0
}
catch {
    Write-Log ("Unhandled error: {0}" -f $_) -Tag "Error"
    Complete-Script -ExitCode 1
}