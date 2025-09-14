# ===========================[ Script Start Timestamp ]===========================

# Capture start time to log script duration
$scriptStartTime = Get-Date

# ===============================[ Script name ]=================================

# Script name used for folder/log naming
$scriptName   = "Start menu - Windows 11"
$logFileName  = "$($scriptName).log"

# ===============================[ Logging Setup ]===============================

# Logging control switches
$log           = $true      # Set to $false to disable logging in shell
$enableLogFile = $true      # Set to $false to disable file output

# Define the log output location
$logFileDirectory = "$env:ProgramData\IntuneLogs\Scripts\$($env:USERNAME)"
$logFile          = "$logFileDirectory\$logFileName"

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
        default    { "White" }
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

# ===============================[ Exit Function ]===============================

function Complete-Script {
    param([int]$ExitCode)
    $scriptEndTime = Get-Date
    $duration = $scriptEndTime - $scriptStartTime
    Write-Log "Script execution time: $($duration.ToString('hh\:mm\:ss\.ff'))" -Tag "Info"
    Write-Log "Exit Code: $ExitCode" -Tag "Info"
    Write-Log "======== Script Completed ========" -Tag "End"
    exit $ExitCode
}

# ===============================[ Script Start ]================================

Write-Log "======== Script Started ========" -Tag "Start"
Write-Log "ComputerName: $env:COMPUTERNAME | User: $env:USERNAME | Script: $scriptName" -Tag "Info"

# --------------------------------------------------------------------------------
# Purpose
#   Set the Windows 11 Start menu (start2.bin) ONCE for the currently logged-on user
#   during enrollment, without enforcing it afterwards. Based on Sander Rozemuller's
#   approach of embedding a Base64-encoded start2.bin in the script and writing it
#   to the per-user path, then restarting StartMenuExperienceHost.
#   Source idea: https://rozemuller.com/deploy-initial-start-menu-during-intune-enrollment-without-files/
# --------------------------------------------------------------------------------

# ===============================[ Guard Rails ]=================================

# OS check: Only run on Windows 11 (10.0.2* build numbers)
$OSVersion = (Get-WmiObject -Class Win32_OperatingSystem).Version
Write-Log "Detected OS Version: $OSVersion" -Tag "Info"
if (-not $OSVersion.StartsWith("10.0.2")) {
    Write-Log "Not Windows 11. Exiting without changes." -Tag "Info"
    Complete-Script -ExitCode 0
}

# The script must run in USER CONTEXT. If it runs as SYSTEM, LOCALAPPDATA will
# point to the SYSTEM profile and the layout would be written for the wrong user.
if ($env:USERNAME -eq 'SYSTEM') {
    Write-Log "Script is running as SYSTEM. Configure the Intune assignment to 'Run this script using the logged-on credentials = Yes'." -Tag "Error"
    Complete-Script -ExitCode 1
}

# ============================[ Input: Base64 Layout ]===========================

# IMPORTANT: Replace the placeholder with your OWN Base64 of start2.bin exported
#            from a reference Windows 11 user profile.
#            Example to generate:
#            $bytes = [IO.File]::ReadAllBytes("$ENV:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin")
#            $base64String = [Convert]::ToBase64String($bytes)
#            $base64String | Out-File -FilePath .\start2-base64.txt -Encoding ASCII

$startMenuBase64 = '4nrhSwH8TRucAIEL3m5RhU5aX0cAW7FJilySr5CE+V4JpRPKUCXcAUAKAABc9u55LN8F4borYyXEGl8Q5+RZ+qERszeqUhhZXDvcjTF6rgdprauITLqPgMVMbSZbRsLN/O5uMjSLEr6nWYIwsMJkZMnZyZrhR3PugUhUKOYDqwySCY6/CPkL/Ooz/5j2R2hwWRGqc7ZsJxDFM1DWofjUiGjDUny+Y8UjowknQVaPYao0PC4bygKEbeZqCqRvSgPalSc53OFqCh2FHydzl09fChaos385QvF40EDEgSO8U9/dntAeNULwuuZBi7BkWSIOmWN1l4e+TZbtSJXwn+EINAJhRHyCSNeku21dsw+cMoLorMKnRmhJMLvE+CCdgNKIaPo/Krizva1+bMsI8bSkV/CxaCTLXodb/NuBYCsIHY1sTvbwSBRNMPvccw43RJCUKZRkBLkCVfW24ANbLfHXofHDMLxxFNUpBPSgzGHnueHknECcf6J4HCFBqzvSH1TjQ3S6J8tq2yaQ+jFNk/tsREeZ1WuUlUHz8ZYoZIUUkF11nxN8ac4L9CsoQ4Vd7EiwDz4G8RO8XGPunRSKbfDMA3WHlB0rYT92UAXh3OFfJI7W3jv9K3lmXgUpNZFFY0jsh/gAongiksSoAwZJJmGjkazIkZOd1LBO8HKbS78W1G1InQPJ+shNoeFS9jcdqev5qwVVKCAGTq3XgEdQ/yLdlKNYCH6i7QuiuJywDmlt44UXP8RPJsc3WF+ddyUOmJmGnsOZp/lcdrDBZzU9TMyNFqkgdjF/NKvux5H7toHMgWMIDP7O0a9v+cXFRNDdNd8bJKX8a7rr9eX05C0RX4UfvmZZC7h7oXqeCCZZ0Fxy/Gx87N/xZylwLqZeQW+qDPHiqiQnMuebTxJ3J5ps53YBVPB0pi4n699aGxaEw42D1IieIYH6KJTuHkmpp7Y5CiwoW96Pvm2oNCiTN/zB36zI4AccaXTFBxV1Fg691GRSCpskvkm9R4fzikt9ivSDLBDswnb3ueGgM1vfka5GB1Bz1bxKiYYjG2lPjjYSx4mY2db8Y2YhcK08dZVhdwU98Tlklx82Du/dHbtYjbCMF2gZLsLzhxfnV9PMX6QtWPD3DtWmdyIuKr6iZxIW4IttayJ1FuV2zCzvZDaldwGcnS9l87/9gZu/OW7mjnIeuVgDr4rsVfxVRdR6gRA3eFyrKp2tJZsRkJ2cbcFT7hem8TOR3DiXL1wgShjDCdXlzG6/3SHYUvwt9ieYmGwe4w3hmPzvQrUQ2Pg9Tr9y+XYEeJJ9HQ2rjfVzijV0JRMvX4IFcJnjHOMyuraaMsoJO1U+eirWs/q0nT1tSs5/IYrvERoqZzRO6V+XmHaPN4lXxqQ/OjtuGSY8f0b9Oefh3xouNyBHpG8GZxwY7xnxJEsQyGvn3dCVfnxVWubUbbp7YLLQuQ8Z03nKRshyPOv+Ei35rObIlQeUR1hyhsP8uVbXuVFO42FG3PCAvZNmn009P8+OooVxiEYQ4SQIs364B48Bx1lbG2iJ1KVpL2P+Dw46rck4yCum5wg6MEZCiNuAXdIGog6vEuB/cJiFnrL8XySvmme+9xOJ+73STpezkDX3KgVeqnsWIwXc3xgDOz4FqOUkPJx9SoJ9Vl4TdgmqG+X/xTWay574qF6rjLghQ/I+Fh5p4oCOsZgegiKpjwtBvSAkeA08b3j1PUc8a/GHJkMLq7LxzgCr6cCePyQKiX7ddgcgIjlrOsboQGMWxaftE1cFwFV8apZA8RKgSQW5JNIPv0Fd61dOLPiWEqzLRIqwm7hRfFKRSVbZ3dw0a21qcT8g/xGv+14nCM1E9sb6tTK6obV3qUBPxNlpyx6Axbx8y/r/Ri3VDEHqRmhLvlMBByxRpMvcpLwW5eLNZy5aKwk1ziKFaY5aNnEV0hnOnVHP2Hqkaq1I1586ilnxtTJySEYlQPjTGblrRkFIZ7qZtDbIzYdGCC4QAv4fnQCghSWihVMwbNuJf/4p3DvXRPUu7XvrjKXkszj7Ytu9eYtQWJr+yJeDHJkqoKOxVnk6iCsk3dZHg06QKISvPJlgu+xMZCRN7Zo4t+9+H0kHycvF/rzStwVQXqHy71FYuFfZQUVYwtJUY1N5mWtsqoWmvU3vwsAOwBfV/qIrC/BtSWnT3gutGnaR+Qye/z1bWBtgbTBqrzytcEwBGbF2SqlZz3BgDs+OL4huaYeuoLB1HSYSBqOXqX+O2MRxIYV4DGn0vU52Bsd4RGDmwkBhDSPXHHy3vNHhJz4bS7BbyBcwTZEwFSxJ79aDuaukgo56KT+xhaoeR9XIKrbp26eGbVJY4Sb+o9LmM0rD39HRy6Czlt+Wn1Ys/jv8bcUFtO8/5235LzSDOT9wqxXuMMtkO+jr7fsENjizSHtR37PHXzSKVH9kM3BdHPECYnnYUkRFGBtSRtoVVH9DqIxWmV9WnatnrbSy+73nhCjx7asy8UIQ2q3UymL3cJ0c/6IWLcdS/2Bi6Fis/FuaNdM8lDxOIDBnXNabJgJnQoMusdtD9nHaY2cBBbMb/MdGeFRBrKYWJCa5/jTCBaRWulyO6zzVS6uwDWVP51UK+MG8l7O6ymlDmTeIXQ0jRMvQG0XkT3JI25xoQ4uW/gAdWT/QvGzVyZyXBecpmZbsAcRNQP6ocuN2Ph8WsZ4fNQe3KeD0zkPrScK8m7gxvPgqECEVPXrnnijfSL36kXmsuQWO4Cs9WgPMfHqgLSzg01h/Is+FTf938r+WZa/OUi045BfcZgtyh+4AhVFPz8AGKbWujki6PBxOlKOsg58po/fY7l1SWw6hlwiDeeDpUCL3ta0pdUJxx/yVgyHazSG+kk5wP2KlmHttaUkhwbnBusmPRGgl3AqhWz+aLFYewMYWox1slWsYFnV24OrSFMxrEdcu/K0FVOjtm5T4A4GToNzQVlksBu7AC9ej8WyYiEWMboifZk++ot0c0IQb0FBqXMw/Hxxc8+2gSblo/2qeYFhdpXVWgRx9OfnUtv0u8CecaE734awCpSeLPJZEyrsq+yTJwQg9+ktbDrj4UlTq9UeTKGDHhfM+TORoWHY4GmMmu7SNbNFTJOaI+vnTFHFn0DCS7SgV2uTHu71tryTrh8oG5O/RdXmfkePs+MpciEY9MvpbXSs2bHy4egmfPMo8J5/zCJEt+ClTIsDPE2LJSiVZKX0jqzFwj/Evwl6YLoEdawiSYqyHLOwdch8incrd2TFsIohPin0fWCHH2cZsEEYL2fhNx6gME2hOW4d/Yj+gx7DdxQ6ncymxye3rjbU+huPdWQD7guUQnwCj+1hkfyFDEHC4wZHRqzeHXSrg5RGRMushdXNNiTNjDFYMJNvgRL2lu63NPE+Cxy+IKC1NdKLweFdOGZr2y1K2IkdefmN9cLZQ/CVXkw8Qw2nOr/ntwuFV/tvJoPW2EOzRmF2XO8mQDQv51k5/v4ZE2VL0dIIvj1M+KPw0nSs271QgJanYwK3CpFluK/1ilEi7JKDikT8XTSz1QZdkum5Y3uC7wc7paXh1rm11nwluCC7jiA=='

if ([string]::IsNullOrWhiteSpace($startMenuBase64) -or $startMenuBase64 -like '<PUT-*') {
    Write-Log "No Base64 Start layout provided. Update `$startMenuBase64 with your exported start2.bin." -Tag "Error"
    Complete-Script -ExitCode 1
}

# ===============================[ Destination ]=================================

$dest = Join-Path $ENV:LOCALAPPDATA 'Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin'
$destDir = Split-Path $dest -Parent

Write-Log "Destination path: $dest" -Tag "Info"

try {
    if (-not (Test-Path $destDir)) {
        Write-Log "Creating directory: $destDir" -Tag "Info"
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
}
catch {
    Write-Log "Failed to create destination directory: $($_.Exception.Message)" -Tag "Error"
    Complete-Script -ExitCode 1
}

# ===============================[ Write Layout ]===============================

try {
    $bytes = [Convert]::FromBase64String($startMenuBase64)

    # Backup existing file if present
    if (Test-Path $dest) {
        $ts = Get-Date -Format 'yyyyMMddHHmmss'
        $backup = "$dest.$ts.bak"
        Write-Log "Existing start2.bin found. Creating backup: $backup" -Tag "Check"
        Copy-Item -Path $dest -Destination $backup -Force
    }

    # Write new bytes
    [IO.File]::WriteAllBytes($dest, $bytes)

    # Compute hash for logging/marker
    $sha256 = [System.BitConverter]::ToString((New-Object System.Security.Cryptography.SHA256Managed).ComputeHash($bytes)).Replace('-', '')
    Write-Log "start2.bin written successfully. SHA256: $sha256" -Tag "Success"
}
catch {
    Write-Log "Failed to write start2.bin: $($_.Exception.Message)" -Tag "Error"
    Complete-Script -ExitCode 1
}

# ==============================[ Restart Process ]==============================

try {
    # Restart the Start Menu Experience Host for the current user so the new
    # layout is picked up immediately. If it's not running, ignore errors.
    $proc = Get-Process -Name 'StartMenuExperienceHost' -ErrorAction SilentlyContinue | Where-Object { $_.SI -eq $PID.SI }
    if ($null -ne $proc) {
        Write-Log "Restarting StartMenuExperienceHost (PID: $($proc.Id))" -Tag "Info"
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    } else {
        Write-Log "StartMenuExperienceHost not running for this session. It will pick up the layout on next launch/logon." -Tag "Debug"
    }
}
catch {
    Write-Log "Failed to restart StartMenuExperienceHost: $($_.Exception.Message)" -Tag "Error"
    # Not fatal for applying the layout; continue
}

# ===============================[ Finish ]======================================

Complete-Script -ExitCode 0