# ---------------------------[ Script Start Timestamp ]---------------------------
$scriptStartTime = Get-Date

# ---------------------------[ Script Name ]---------------------------
$scriptName  = "Winget-SystemContext"
$logFileName = "$($scriptName).log"

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
        [string]$message,
        [string]$tag = "Info"
    )

    if (-not $log) { return }

    if (($tag -eq "Debug") -and (-not $logDebug)) { return }
    if (($tag -eq "Get")   -and (-not $logGet))   { return }
    if (($tag -eq "Run")   -and (-not $logRun))   { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $tagList   = @("Start", "Get", "Run", "Info", "Success", "Error", "Debug", "End")
    $rawTag    = $tag.Trim()

    if ($tagList -contains $rawTag) {
        $rawTag = $rawTag.PadRight(7)
    }
    else {
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

    $logMessage = "$timestamp [  $rawTag ] $message"

    if ($enableLogFile) {
        try {
            Add-Content -Path $logFile -Value $logMessage -Encoding UTF8
        }
        catch {
            # Logging must never block script execution
        }
    }

    Write-Host "$timestamp " -NoNewline
    Write-Host "[  " -NoNewline -ForegroundColor White
    Write-Host "$rawTag" -NoNewline -ForegroundColor $color
    Write-Host " ] " -NoNewline -ForegroundColor White
    Write-Host "$message"
}

# ---------------------------[ Exit Function ]---------------------------
function Complete-Script {
    param([int]$exitCode)

    $scriptEndTime = Get-Date
    $duration      = $scriptEndTime - $scriptStartTime

    Write-Log "Script execution time: $($duration.ToString('hh\:mm\:ss\.ff'))" -Tag "Info"
    Write-Log "Exit Code: $exitCode" -Tag "Info"
    Write-Log "======== Script Completed ========" -Tag "End"

    exit $exitCode
}

# ---------------------------[ Script Start ]---------------------------
Write-Log "======== Script Started ========" -Tag "Start"
Write-Log "ComputerName: $env:COMPUTERNAME | User: $env:USERNAME | Script: $scriptName" -Tag "Info"

# ---------------------------[ Winget Path Resolver ]---------------------------
function Get-WingetPath {
    $wingetBase = "$env:ProgramW6432\WindowsApps"

    try {
        $wingetFolders = Get-ChildItem -Path $wingetBase -Directory -ErrorAction Stop |
            Where-Object { $_.Name -like 'Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe' }

        # Fall back to arm64 if x64 is not available
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
    Write-Log "Starting Winget repair..." -Tag "Run"

    Register-WingetDependencyPaths

    Write-Log "Restart required to apply PATH changes." -Tag "Info"
    Complete-Script -ExitCode 0
}

function Register-WingetDependencyPaths {
    Write-Log "Registering Winget dependency DLL directories into SYSTEM PATH..." -Tag "Run"

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
        foreach ($packageName in $dllPackages) {
            # Prefer x64, fall back to arm64
            $folder = Get-ChildItem -Path $windowsApps -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "$packageName*_x64__*" } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

            if (-not $folder) {
                $folder = Get-ChildItem -Path $windowsApps -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like "$packageName*_arm64__*" } |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1

                if ($folder) {
                    Write-Log "Found $packageName (arm64) at: $($folder.FullName)" -Tag "Get"
                }
            }
            else {
                Write-Log "Found $packageName (x64) at: $($folder.FullName)" -Tag "Get"
            }

            if ($folder) {
                $pathsToAdd += $folder.FullName
            }
            else {
                Write-Log "Could not find folder for $packageName (checked x64 and arm64)" -Tag "Error"
            }
        }

        $currentPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        if ($null -eq $currentPath) { $currentPath = '' }

        $updated = $false
        foreach ($pathEntry in $pathsToAdd | Select-Object -Unique) {
            if ($currentPath -notlike "*$pathEntry*") {
                Write-Log "Adding to SYSTEM PATH: $pathEntry" -Tag "Run"
                $currentPath += ";$pathEntry"
                $updated = $true
            }
            else {
                Write-Log "Already in SYSTEM PATH: $pathEntry" -Tag "Debug"
            }
        }

        if ($updated) {
            [Environment]::SetEnvironmentVariable('Path', $currentPath, 'Machine')
            Write-Log "SYSTEM PATH updated with dependency directories." -Tag "Success"
        }
        else {
            Write-Log "All dependency paths already present in SYSTEM PATH." -Tag "Info"
        }

        return $updated
    }
    catch {
        Write-Log "Failed to update SYSTEM PATH: $_" -Tag "Error"
        return $false
    }
}

function Test-Winget {
    $wingetPath = Get-WingetPath
    $output     = & $wingetPath -v
    $exitCode   = $LASTEXITCODE

    if ($null -ne $output -and $exitCode -eq 0) {
        Write-Log "Winget version: $output" -Tag "Get"
    }
    else {
        Write-Log "Winget execution failed with exit code: $exitCode" -Tag "Error"
        Write-Log "Winget output: $output" -Tag "Debug"
    }

    return $exitCode -eq 0
}

# ---------------------------[ Main Logic ]---------------------------
try {
    if (Test-Winget) {
        Write-Log "Winget is healthy. No action required." -Tag "Success"
        Complete-Script -ExitCode 0
        return
    }

    Write-Log "Winget health check failed, attempting repair." -Tag "Info"
    Invoke-WingetRepair

    # Restart is required for PATH changes to take effect
    Write-Log "Repair completed. Exiting with 0 so Intune retries after restart." -Tag "Info"
    Complete-Script -ExitCode 0
}
catch {
    Write-Log ("Unhandled error: {0}" -f $_) -Tag "Error"
    Complete-Script -ExitCode 1
}
