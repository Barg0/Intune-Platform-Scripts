# ---------------------------[ Script Start Timestamp ]---------------------------
$scriptStartTime = Get-Date

# ---------------------------[ Script Name ]---------------------------
$scriptName  = "Set-PersonalizationDefaults"
$logFileName = "$scriptName.log"

# ===========================================================================
#                            CONFIGURATION
# ===========================================================================
# Customize Windows personalization by setting values below.
# Set any option to $null to skip that setting entirely.
# ---------------------------------------------------------------------------

# --- Theme ---
$configTaskbarTheme         = "dark"            # "dark" | "light" | $null
$configExplorerTheme        = "light"           # "dark" | "light" | $null
$configAutoColorization     = $true             # $true | $false  | $null
$configTransparency         = $true             # $true | $false  | $null

# --- Explorer ---
$configLaunchTo             = "computer"        # "computer" | "quick-access" | $null
$configShowFileExtensions   = $true             # $true | $false  | $null
$configShowCheckboxes       = $false            # $true | $false  | $null

# --- Taskbar ---
$configShowTaskView         = $false            # $true | $false  | $null

# --- Wallpaper ---
$configWallpaper            = "default"         # "default" | "C:\path\to\image.jpg" | $null

# ---------------------------------------------------------------------------
#                         WINDOWS 10 ONLY
# ---------------------------------------------------------------------------

# --- Taskbar ---
$configSearchbarModeWin10   = "icon"            # "hidden" | "icon" | "box" | $null
$configShowCortana          = $false            # $true | $false  | $null
$configShowNewsAndInterests = $false            # $true | $false  | $null

# --- System Tray ---
$configShowAllTrayIcons     = $true             # $true | $false  | $null

# ---------------------------------------------------------------------------
#                         WINDOWS 11 ONLY
# ---------------------------------------------------------------------------

# --- Taskbar ---
$configSearchbarModeWin11   = "icon"            # "hidden" | "icon" | "box" | "icon-label" | $null
$configStartAlignment       = "left"            # "left" | "center" | $null

# --- Explorer ---
$configClassicContextMenu   = $true             # $true | $false  | $null

# ===========================================================================
#                          END OF CONFIGURATION
# ===========================================================================

# ---------------------------[ Logging Setup ]---------------------------
$log           = $true
$logDebug      = $false
$logGet        = $true
$logRun        = $true
$enableLogFile = $true

$logFileDirectory = "$env:ProgramData\IntuneLogs\Scripts\$env:USERNAME"
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

    $logMessage = "$timestamp [  $rawTag ] $Message"

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

# ---------------------------[ Registry Helpers ]---------------------------
function Set-RegistryValue {
    [CmdletBinding()]
    param (
        [string]$KeyPath,
        [string]$ValueName,
        [string]$ValueType,
        [string]$ValueData,
        [string]$Description
    )

    $fullPath       = "HKCU:\$KeyPath"
    $isDefaultValue = [string]::IsNullOrEmpty($ValueName)
    $currentValue   = $null

    try {
        if (-not (Test-Path -Path $fullPath)) {
            $currentValue = $null
        }
        elseif ($isDefaultValue) {
            $currentValue = (Get-ItemProperty -Path $fullPath -Name "(Default)" -ErrorAction Stop).'(Default)'
        }
        else {
            $currentValue = (Get-ItemProperty -Path $fullPath -Name $ValueName -ErrorAction SilentlyContinue).$ValueName
        }
    }
    catch {
        $currentValue = $null
    }

    $valueAlreadySet = ($null -ne $currentValue) -and ("$currentValue" -eq "$ValueData")

    if ($valueAlreadySet) {
        Write-Log "$Description - already configured" -Tag "Success"
        return $false
    }

    Write-Log "$Description - applying" -Tag "Run"
    Write-Log "Registry: HKCU\$KeyPath\$ValueName = $ValueData ($ValueType)" -Tag "Debug"

    if ($isDefaultValue -and [string]::IsNullOrEmpty($ValueData)) {
        $regOutput = reg.exe add "HKCU\$KeyPath" /ve /f 2>&1
    }
    elseif ($isDefaultValue) {
        $regOutput = reg.exe add "HKCU\$KeyPath" /ve /t "$ValueType" /d "$ValueData" /f 2>&1
    }
    else {
        $regOutput = reg.exe add "HKCU\$KeyPath" /v "$ValueName" /t "$ValueType" /d "$ValueData" /f 2>&1
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Log "$Description - applied successfully" -Tag "Success"
        return $true
    }
    else {
        Write-Log "$Description - failed (exit code: $LASTEXITCODE)" -Tag "Error"
        Write-Log "reg.exe output: $regOutput" -Tag "Debug"
        return $false
    }
}

function Remove-RegistryKey {
    [CmdletBinding()]
    param (
        [string]$KeyPath,
        [string]$Description
    )

    $fullPath = "HKCU:\$KeyPath"

    if (-not (Test-Path -Path $fullPath)) {
        Write-Log "$Description - already configured" -Tag "Success"
        return $false
    }

    Write-Log "$Description - applying" -Tag "Run"
    Write-Log "Removing registry key: HKCU\$KeyPath" -Tag "Debug"

    try {
        Remove-Item -Path $fullPath -Recurse -Force
        Write-Log "$Description - applied successfully" -Tag "Success"
        return $true
    }
    catch {
        Write-Log "$Description - failed: $_" -Tag "Error"
        return $false
    }
}

function Test-RegistryValue {
    [CmdletBinding()]
    param (
        [string]$KeyPath,
        [string]$ValueName,
        [string]$ExpectedValue,
        [string]$Description
    )

    $fullPath       = "HKCU:\$KeyPath"
    $isDefaultValue = [string]::IsNullOrEmpty($ValueName)

    try {
        if ($isDefaultValue) {
            $actualValue = (Get-ItemProperty -Path $fullPath -Name "(Default)" -ErrorAction Stop).'(Default)'
        }
        else {
            $actualValue = (Get-ItemProperty -Path $fullPath -Name $ValueName -ErrorAction Stop).$ValueName
        }

        if ("$actualValue" -eq "$ExpectedValue") {
            Write-Log "$Description - verified" -Tag "Success"
            return $true
        }

        Write-Log "$Description - mismatch: expected '$ExpectedValue', got '$actualValue'" -Tag "Error"
        return $false
    }
    catch {
        Write-Log "$Description - verification failed: $_" -Tag "Error"
        return $false
    }
}

# ---------------------------[ Feeds Hash (Win 10) ]---------------------------
# Windows 10 validates the feeds taskbar setting against a machine-specific hash.
# Setting ShellFeedsTaskbarViewMode alone is insufficient on certain builds.
function Get-FeedsHashValue {
    [CmdletBinding()]
    param ([int]$Option)

    $methodDefinition = @'
    [DllImport("Shlwapi.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = false)]
    public static extern int HashData(byte[] pbData, int cbData, byte[] piet, int outputLen);
'@

    $shlwapi        = Add-Type -MemberDefinition $methodDefinition -Name 'Shlwapi' -Namespace 'Win32' -PassThru
    $machineIdEntry = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\SQMClient' -Name 'MachineId' -ErrorAction SilentlyContinue
    $machineId      = if ($machineIdEntry) { $machineIdEntry.MachineId } else { '{C283D224-5CAD-4502-95F0-2569E4C85074}' }

    $combined = "$machineId`_$Option"
    $reversed = $combined[($combined.Length - 1)..0] -join ''
    $bytesIn  = [System.Text.Encoding]::Unicode.GetBytes($reversed)
    $bytesOut = [byte[]]::new(4)

    $shlwapi::HashData($bytesIn, 0x53, $bytesOut, $bytesOut.Count) | Out-Null

    return [System.BitConverter]::ToUInt32($bytesOut, 0)
}

# ---------------------------[ Wallpaper ]---------------------------
function Set-DesktopWallpaper {
    [CmdletBinding()]
    param ([string]$Path)

    $methodDefinition = @'
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
'@

    $user32              = Add-Type -MemberDefinition $methodDefinition -Name 'User32' -Namespace 'Win32Wallpaper' -PassThru
    $spiSetDeskWallpaper = 0x0014
    $spifUpdateAndNotify = 0x03

    Write-Log "Setting desktop wallpaper: $Path" -Tag "Run"

    $result = $user32::SystemParametersInfo($spiSetDeskWallpaper, 0, $Path, $spifUpdateAndNotify)

    if ($result -ne 0) {
        Write-Log "Desktop wallpaper applied successfully" -Tag "Success"
        return $true
    }
    else {
        Write-Log "Failed to apply desktop wallpaper" -Tag "Error"
        return $false
    }
}

# ---------------------------[ Explorer Restart ]---------------------------
function Restart-ExplorerProcess {
    Write-Log "Restarting explorer to apply visual changes" -Tag "Run"

    try {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
            Start-Process -FilePath "explorer.exe"
        }

        Write-Log "Explorer restarted successfully" -Tag "Success"
    }
    catch {
        Write-Log "Failed to restart explorer: $_" -Tag "Error"
        Start-Process -FilePath "explorer.exe"
    }
}

# ---------------------------[ Settings Builder ]---------------------------
function Get-PersonalizationSettings {
    [CmdletBinding()]
    param (
        [bool]$IsWindows10,
        [bool]$IsWindows11
    )

    $settings = [System.Collections.ArrayList]::new()

    # ---- Theme ----

    if ($null -ne $configTaskbarTheme) {
        $value = switch ($configTaskbarTheme) { "dark" { 0 } "light" { 1 } }
        if ($null -ne $value) {
            [void]$settings.Add(@{
                Action      = "Set"
                Description = "Taskbar theme ($configTaskbarTheme)"
                KeyPath     = "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
                ValueName   = "SystemUsesLightTheme"
                ValueType   = "REG_DWORD"
                ValueData   = $value
                SupportedOS = @("Windows10", "Windows11")
            })
        }
        else {
            Write-Log "Invalid configTaskbarTheme: '$configTaskbarTheme' (expected: dark, light)" -Tag "Error"
        }
    }

    if ($null -ne $configExplorerTheme) {
        $value = switch ($configExplorerTheme) { "dark" { 0 } "light" { 1 } }
        if ($null -ne $value) {
            [void]$settings.Add(@{
                Action      = "Set"
                Description = "Explorer theme ($configExplorerTheme)"
                KeyPath     = "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
                ValueName   = "AppsUseLightTheme"
                ValueType   = "REG_DWORD"
                ValueData   = $value
                SupportedOS = @("Windows10", "Windows11")
            })
        }
        else {
            Write-Log "Invalid configExplorerTheme: '$configExplorerTheme' (expected: dark, light)" -Tag "Error"
        }
    }

    if ($null -ne $configAutoColorization) {
        $value = if ($configAutoColorization) { 1 } else { 0 }
        [void]$settings.Add(@{
            Action      = "Set"
            Description = "Automatic accent color"
            KeyPath     = "Control Panel\Desktop"
            ValueName   = "AutoColorization"
            ValueType   = "REG_DWORD"
            ValueData   = $value
            SupportedOS = @("Windows10", "Windows11")
        })
    }

    if ($null -ne $configTransparency) {
        $value = if ($configTransparency) { 1 } else { 0 }
        [void]$settings.Add(@{
            Action      = "Set"
            Description = "Transparency effects"
            KeyPath     = "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
            ValueName   = "EnableTransparency"
            ValueType   = "REG_DWORD"
            ValueData   = $value
            SupportedOS = @("Windows10", "Windows11")
        })
    }

    # ---- Explorer ----

    if ($null -ne $configLaunchTo) {
        $value = switch ($configLaunchTo) { "computer" { 1 } "quick-access" { 2 } }
        if ($null -ne $value) {
            [void]$settings.Add(@{
                Action      = "Set"
                Description = "Explorer opens to ($configLaunchTo)"
                KeyPath     = "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                ValueName   = "LaunchTo"
                ValueType   = "REG_DWORD"
                ValueData   = $value
                SupportedOS = @("Windows10", "Windows11")
            })
        }
        else {
            Write-Log "Invalid configLaunchTo: '$configLaunchTo' (expected: computer, quick-access)" -Tag "Error"
        }
    }

    if ($null -ne $configShowFileExtensions) {
        $value = if ($configShowFileExtensions) { 0 } else { 1 }
        [void]$settings.Add(@{
            Action      = "Set"
            Description = "File extensions visible"
            KeyPath     = "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            ValueName   = "HideFileExt"
            ValueType   = "REG_DWORD"
            ValueData   = $value
            SupportedOS = @("Windows10", "Windows11")
        })
    }

    if ($null -ne $configShowCheckboxes) {
        $value = if ($configShowCheckboxes) { 1 } else { 0 }
        [void]$settings.Add(@{
            Action      = "Set"
            Description = "Item checkboxes in Explorer"
            KeyPath     = "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            ValueName   = "AutoCheckSelect"
            ValueType   = "REG_DWORD"
            ValueData   = $value
            SupportedOS = @("Windows10", "Windows11")
        })
    }

    if ($null -ne $configClassicContextMenu) {
        if ($configClassicContextMenu) {
            [void]$settings.Add(@{
                Action      = "Set"
                Description = "Classic context menu"
                KeyPath     = "Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
                ValueName   = ""
                ValueType   = "REG_SZ"
                ValueData   = ""
                SupportedOS = @("Windows11")
            })
        }
        else {
            [void]$settings.Add(@{
                Action      = "Remove"
                Description = "New context menu (remove classic override)"
                KeyPath     = "Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
                SupportedOS = @("Windows11")
            })
        }
    }

    # ---- Taskbar ----

    if ($null -ne $configSearchbarModeWin10) {
        $value = switch ($configSearchbarModeWin10) { "hidden" { 0 } "icon" { 1 } "box" { 2 } }
        if ($null -ne $value) {
            [void]$settings.Add(@{
                Action      = "Set"
                Description = "Search bar mode ($configSearchbarModeWin10)"
                KeyPath     = "Software\Microsoft\Windows\CurrentVersion\Search"
                ValueName   = "SearchboxTaskbarMode"
                ValueType   = "REG_DWORD"
                ValueData   = $value
                SupportedOS = @("Windows10")
            })
        }
        else {
            Write-Log "Invalid configSearchbarModeWin10: '$configSearchbarModeWin10' (expected: hidden, icon, box)" -Tag "Error"
        }
    }

    if ($null -ne $configSearchbarModeWin11) {
        $value = switch ($configSearchbarModeWin11) { "hidden" { 0 } "icon" { 1 } "box" { 2 } "icon-label" { 3 } }
        if ($null -ne $value) {
            [void]$settings.Add(@{
                Action      = "Set"
                Description = "Search bar mode ($configSearchbarModeWin11)"
                KeyPath     = "Software\Microsoft\Windows\CurrentVersion\Search"
                ValueName   = "SearchboxTaskbarMode"
                ValueType   = "REG_DWORD"
                ValueData   = $value
                SupportedOS = @("Windows11")
            })
        }
        else {
            Write-Log "Invalid configSearchbarModeWin11: '$configSearchbarModeWin11' (expected: hidden, icon, box, icon-label)" -Tag "Error"
        }
    }

    if ($null -ne $configShowTaskView) {
        $value = if ($configShowTaskView) { 1 } else { 0 }
        [void]$settings.Add(@{
            Action      = "Set"
            Description = "Task View button"
            KeyPath     = "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            ValueName   = "ShowTaskViewButton"
            ValueType   = "REG_DWORD"
            ValueData   = $value
            SupportedOS = @("Windows10", "Windows11")
        })
    }

    if ($null -ne $configShowCortana) {
        $value = if ($configShowCortana) { 1 } else { 0 }
        [void]$settings.Add(@{
            Action      = "Set"
            Description = "Cortana button"
            KeyPath     = "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            ValueName   = "ShowCortanaButton"
            ValueType   = "REG_DWORD"
            ValueData   = $value
            SupportedOS = @("Windows10")
        })
    }

    if ($null -ne $configStartAlignment) {
        $value = switch ($configStartAlignment) { "left" { 0 } "center" { 1 } }
        if ($null -ne $value) {
            [void]$settings.Add(@{
                Action      = "Set"
                Description = "Start menu alignment ($configStartAlignment)"
                KeyPath     = "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                ValueName   = "TaskbarAl"
                ValueType   = "REG_DWORD"
                ValueData   = $value
                SupportedOS = @("Windows11")
            })
        }
        else {
            Write-Log "Invalid configStartAlignment: '$configStartAlignment' (expected: left, center)" -Tag "Error"
        }
    }

    if ($null -ne $configShowNewsAndInterests) {
        $feedsOption = if ($configShowNewsAndInterests) { 0 } else { 2 }
        try {
            $feedsHashValue = Get-FeedsHashValue -Option $feedsOption
            Write-Log "Computed feeds hash for option $feedsOption : $feedsHashValue" -Tag "Debug"
            [void]$settings.Add(@{
                Action      = "Set"
                Description = "News and Interests"
                KeyPath     = "SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds"
                ValueName   = "EnShellFeedsTaskbarViewMode"
                ValueType   = "REG_DWORD"
                ValueData   = $feedsHashValue
                SupportedOS = @("Windows10")
            })
        }
        catch {
            Write-Log "Failed to compute feeds hash value: $_" -Tag "Error"
        }
    }

    # ---- System Tray ----

    if ($null -ne $configShowAllTrayIcons) {
        $value = if ($configShowAllTrayIcons) { 0 } else { 1 }
        [void]$settings.Add(@{
            Action      = "Set"
            Description = "Show all system tray icons"
            KeyPath     = "Software\Microsoft\Windows\CurrentVersion\Explorer"
            ValueName   = "EnableAutoTray"
            ValueType   = "REG_DWORD"
            ValueData   = $value
            SupportedOS = @("Windows10")
        })
    }

    # ---- Filter by detected OS ----

    $detectedOS    = if ($IsWindows11) { "Windows11" } else { "Windows10" }
    $totalCount    = $settings.Count
    $filtered      = @($settings | Where-Object { $_.SupportedOS -contains $detectedOS })
    $skippedCount  = $totalCount - $filtered.Count

    if ($skippedCount -gt 0) {
        Write-Log "$skippedCount setting(s) skipped - not applicable to $detectedOS" -Tag "Debug"
    }

    return $filtered
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
}
elseif ($isWindows10) {
    Write-Log "Operating system identified as Windows 10" -Tag "Info"
}
else {
    Write-Log "Unsupported OS version: $osVersion - script requires Windows 10 or 11" -Tag "Error"
    Complete-Script -ExitCode 1
}

# ---------------------------[ Build Settings ]---------------------------
$personalizationSettings = @(Get-PersonalizationSettings -IsWindows10 $isWindows10 -IsWindows11 $isWindows11)

if ($personalizationSettings.Count -eq 0) {
    Write-Log "No personalization settings to apply" -Tag "Info"
    Complete-Script -ExitCode 0
}

Write-Log "$($personalizationSettings.Count) setting(s) to process" -Tag "Info"

# ---------------------------[ Apply Settings ]---------------------------
$changesApplied = 0

foreach ($setting in $personalizationSettings) {
    $changed = $false

    if ($setting.Action -eq "Remove") {
        $changed = Remove-RegistryKey `
            -KeyPath    $setting.KeyPath `
            -Description $setting.Description
    }
    else {
        $changed = Set-RegistryValue `
            -KeyPath     $setting.KeyPath `
            -ValueName   $setting.ValueName `
            -ValueType   $setting.ValueType `
            -ValueData   $setting.ValueData `
            -Description $setting.Description
    }

    if ($changed) { $changesApplied++ }
}

Write-Log "$changesApplied of $($personalizationSettings.Count) setting(s) changed" -Tag "Info"

# ---------------------------[ Verify Settings ]---------------------------
Write-Log "Verifying applied settings" -Tag "Info"

$allChecksPassed = $true

foreach ($setting in $personalizationSettings) {
    if ($setting.Action -eq "Remove") {
        if (Test-Path "HKCU:\$($setting.KeyPath)") {
            Write-Log "$($setting.Description) - verification failed: key still exists" -Tag "Error"
            $allChecksPassed = $false
        }
        else {
            Write-Log "$($setting.Description) - verified" -Tag "Success"
        }
    }
    else {
        $verified = Test-RegistryValue `
            -KeyPath       $setting.KeyPath `
            -ValueName     $setting.ValueName `
            -ExpectedValue $setting.ValueData `
            -Description   $setting.Description

        if (-not $verified) {
            $allChecksPassed = $false
        }
    }
}

# ---------------------------[ Apply Wallpaper ]---------------------------
if ($null -ne $configWallpaper) {
    $defaultWallpaperWin10 = "C:\Windows\Web\Wallpaper\Windows\img0.jpg"
    $defaultWallpaperWin11 = "C:\Windows\Web\Wallpaper\Windows\img19.jpg"

    $wallpaperPath = switch ($configWallpaper) {
        "default" { if ($isWindows11) { $defaultWallpaperWin11 } else { $defaultWallpaperWin10 } }
        default   { $configWallpaper }
    }

    if (Test-Path -Path $wallpaperPath) {
        $currentWallpaper = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Wallpaper" -ErrorAction SilentlyContinue).Wallpaper

        if ($currentWallpaper -eq $wallpaperPath) {
            Write-Log "Desktop wallpaper - already configured" -Tag "Success"
        }
        else {
            [void](Set-DesktopWallpaper -Path $wallpaperPath)
        }
    }
    else {
        Write-Log "Wallpaper file not found: $wallpaperPath" -Tag "Error"
        $allChecksPassed = $false
    }
}

# ---------------------------[ Explorer Restart ]---------------------------
Restart-ExplorerProcess

# ---------------------------[ Exit ]---------------------------
if ($allChecksPassed) {
    Complete-Script -ExitCode 0
}
else {
    Complete-Script -ExitCode 1
}
