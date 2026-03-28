# ---------------------------[ Script Start Timestamp ]---------------------------
$scriptStartTime = Get-Date

# ---------------------------[ Script Name ]---------------------------
$scriptName  = 'Set-WinGetClientSettings'
$logFileName = '$($scriptName).log'

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

# ===========================================================================
#                            CONFIGURATION
# ===========================================================================
# WinGet client: machine admin settings (winget CLI) + user settings.json merge.
# Set any option to $null to skip that setting entirely.
# IMPORTANT: Keep this block identical in:
#   platform-scripts\Set-WingetClientSettings.ps1
#   remediation-scripts\detection.ps1
#   remediation-scripts\remediation.ps1
# ---------------------------------------------------------------------------

# --- Admin (bool): winget settings --enable / --disable ---
# $true | $false | $null
$configAdminLocalManifestFiles                         = $null
$configAdminBypassCertificatePinningForMicrosoftStore = $null
$configAdminInstallerHashOverride                      = $true
$configAdminLocalArchiveMalwareScanOverride            = $null
$configAdminProxyCommandLineOptions                    = $null

# --- Admin (string): winget settings set / reset ---
# Proxy URL, or '__RESET__' to clear, or $null to skip
$configAdminDefaultProxy = $null

# --- User settings.json ---
# $null omits $schema from the merge; otherwise use the official schema URL
$configUserJsonSchema = 'https://aka.ms/winget-settings.schema.json'

# --- User: source ---
$configUserSourceAutoUpdateIntervalInMinutes = $null   # int (0 disables source auto-update checks)

# --- User: visual ---
$configUserVisualProgressBar             = "rainbow"       # "accent" | "rainbow" | "retro" | "sixel" | "disabled"
$configUserVisualAnonymizeDisplayedPaths = $null       # $true | $false
$configUserVisualEnableSixels            = $null       # $true | $false

# --- User: logging ---
$configUserLoggingLevel    = "verbose"       # "verbose" | "info" | "warning" | "error" | "critical"
$configUserLoggingChannels = $null       # e.g. @("default") — array or $null
$configUserLoggingFileAgeLimitInDays           = $null
$configUserLoggingFileTotalSizeLimitInMB       = $null
$configUserLoggingFileCountLimit               = $null
$configUserLoggingFileIndividualSizeLimitInMB  = $null

# --- User: installBehavior ---
$configUserInstallPreferencesScope          = $null    # "user" | "machine"
$configUserInstallPreferencesLocale         = @("de-DE", "en-US" )    # e.g. @("en-US")
$configUserInstallPreferencesArchitectures    = $null    # e.g. @("x64","arm64")
$configUserInstallPreferencesInstallerTypes   = $null    # e.g. @("msi","msix")
$configUserInstallRequirementsScope         = $null
$configUserInstallRequirementsLocale        = $null
$configUserInstallRequirementsArchitectures   = $null
$configUserInstallRequirementsInstallerTypes  = $null
$configUserInstallSkipDependencies           = $null    # $true | $false
$configUserInstallDisableInstallNotes        = $null
$configUserInstallPortablePackageUserRoot    = $null    # absolute path string
$configUserInstallPortablePackageMachineRoot = $null
$configUserInstallDefaultInstallRoot         = $null
$configUserInstallMaxResumes                 = $null    # int
$configUserInstallArchiveExtractionMethod    = $null    # "shellApi" | "tar"

# --- User: uninstallBehavior ---
$configUserUninstallPurgePortablePackage = $null       # $true | $false

# --- User: configureBehavior ---
$configUserConfigureDefaultModuleRoot = $null           # absolute path

# --- User: downloadBehavior ---
$configUserDownloadDefaultDirectory = $null            # absolute path

# --- User: telemetry ---
$configUserTelemetryDisable = $null                    # $true | $false

# --- User: network ---
$configUserNetworkDownloader                 = $null    # "default" | "wininet" | "do"
$configUserNetworkDoProgressTimeoutInSeconds = $null  # int 1..600

# --- User: interactivity ---
$configUserInteractivityDisable = $null                # $true | $false

# --- User: experimentalFeatures (schema names: experimentalCMD / experimentalARG) ---
$configUserExperimentalExperimentalCMD = $null
$configUserExperimentalExperimentalARG = $null
$configUserExperimentalDirectMSI        = $null
$configUserExperimentalFonts            = $null
$configUserExperimentalResume          = $null
$configUserExperimentalSourcePriority  = $null

# ===========================================================================
#                          END OF CONFIGURATION
# ===========================================================================

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
    $tagList   = @("Start", "Get", "Run", "Info", "Success", "Error", "Debug", "End")
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

function Get-WingetExecutablePathForSystem {
    $wingetBase = Join-Path $env:ProgramW6432 'WindowsApps'
    $wingetFolders = @(
        Get-ChildItem -Path $wingetBase -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe' }
    )
    if (-not $wingetFolders -or $wingetFolders.Count -eq 0) {
        $wingetFolders = @(
            Get-ChildItem -Path $wingetBase -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like 'Microsoft.DesktopAppInstaller_*_arm64__8wekyb3d8bbwe' }
        )
    }
    if (-not $wingetFolders -or $wingetFolders.Count -eq 0) {
        Write-Log "No DesktopAppInstaller folder under $wingetBase" -Tag "Debug"
        return $null
    }
    $latestFolder = $wingetFolders | Sort-Object CreationTime -Descending | Select-Object -First 1
    $wingetExecutablePath = Join-Path $latestFolder.FullName 'winget.exe'
    if (-not (Test-Path -LiteralPath $wingetExecutablePath)) {
        Write-Log "winget.exe not found at $wingetExecutablePath" -Tag "Debug"
        return $null
    }
    Write-Log "Resolved winget.exe: $wingetExecutablePath" -Tag "Debug"
    return $wingetExecutablePath
}

function Invoke-WingetCli {
    param(
        [Parameter(Mandatory)][string]$WingetPath,
        [string[]]$Arguments = @()
    )

    try {
        $processStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $processStartInfo.FileName = $WingetPath
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.CreateNoWindow = $true
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.RedirectStandardError = $true
        if ($processStartInfo.PSObject.Properties['ArgumentList']) {
            foreach ($argument in $Arguments) {
                [void]$processStartInfo.ArgumentList.Add($argument)
            }
        } else {
            $quoted = foreach ($argument in $Arguments) {
                if ($argument -match '[\s"]') {
                    '"{0}"' -f ($argument -replace '"', '\"')
                } else {
                    $argument
                }
            }
            $processStartInfo.Arguments = $quoted -join ' '
        }
        $wingetProcess = [System.Diagnostics.Process]::Start($processStartInfo)
        $stdOut = $wingetProcess.StandardOutput.ReadToEnd()
        $stdErr = $wingetProcess.StandardError.ReadToEnd()
        $wingetProcess.WaitForExit()
        return @{
            ExitCode = $wingetProcess.ExitCode
            StdOut   = $stdOut
            StdErr   = $stdErr
        }
    } catch {
        Write-Log "Failed to start winget: $_" -Tag "Error"
        return @{ ExitCode = -1; StdOut = ''; StdErr = "$_" }
    }
}

function Get-WingetSettingsExportObject {
    param([Parameter(Mandatory)][string]$WingetPath)

    $result = Invoke-WingetCli -WingetPath $WingetPath -Arguments @('settings', 'export')
    if ($result.ExitCode -ne 0) {
        Write-Log "winget settings export failed (exit $($result.ExitCode)): $($result.StdErr)" -Tag "Debug"
        return $null
    }
    $raw = if ($result.StdOut) { $result.StdOut.Trim() } else { '' }
    if (-not $raw) {
        return $null
    }
    try {
        return ($raw | ConvertFrom-Json)
    } catch {
        Write-Log "Could not parse winget settings export JSON: $_" -Tag "Debug"
        return $null
    }
}

function Get-WingetUserSettingsJsonPath {
    param(
        [Parameter(Mandatory)][string]$WingetPath,
        $ExportObject
    )

    if ($ExportObject -and $ExportObject.userSettingsFile) {
        $expanded = [System.Environment]::ExpandEnvironmentVariables([string]$ExportObject.userSettingsFile)
        Write-Log "User settings path from export: $expanded" -Tag "Debug"
        return $expanded
    }

    $packagesDir = Join-Path $env:LocalAppData 'Packages'
    if (-not (Test-Path -LiteralPath $packagesDir)) {
        Write-Log "Packages folder missing: $packagesDir" -Tag "Debug"
        return $null
    }
    $appFolder = Get-ChildItem -Path $packagesDir -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -like 'Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe' -or
            $_.Name -like 'Microsoft.DesktopAppInstaller_*_arm64__8wekyb3d8bbwe'
        } |
        Sort-Object CreationTime -Descending |
        Select-Object -First 1
    if (-not $appFolder) {
        Write-Log "No DesktopAppInstaller package under LocalAppData\Packages" -Tag "Debug"
        return $null
    }
    $settingsJsonPath = Join-Path $appFolder.FullName 'LocalState\settings.json'
    Write-Log "Fallback WinGet settings.json path: $settingsJsonPath" -Tag "Debug"
    return $settingsJsonPath
}

function ConvertTo-WingetOrderedHashtable {
    param($Obj)

    if ($null -eq $Obj) {
        return $null
    }
    if ($Obj -is [string] -or $Obj -is [bool] -or $Obj -is [char]) {
        return $Obj
    }
    if ($Obj -is [int] -or $Obj -is [long] -or $Obj -is [double] -or $Obj -is [decimal]) {
        return $Obj
    }
    if ($Obj -is [System.Collections.IList] -and $Obj -isnot [string]) {
        $list = [System.Collections.ArrayList]::new()
        foreach ($x in $Obj) {
            [void]$list.Add((ConvertTo-WingetOrderedHashtable $x))
        }
        return ,$list.ToArray()
    }
    if ($Obj -is [hashtable] -or $Obj -is [System.Collections.Specialized.OrderedDictionary]) {
        $od = [ordered]@{}
        foreach ($k in $Obj.Keys) {
            $od[$k] = ConvertTo-WingetOrderedHashtable $Obj[$k]
        }
        return $od
    }
    if ($Obj.PSObject -and $Obj.PSObject.Properties) {
        $od = [ordered]@{}
        foreach ($p in $Obj.PSObject.Properties) {
            $od[$p.Name] = ConvertTo-WingetOrderedHashtable $p.Value
        }
        return $od
    }
    return $Obj
}

function Remove-WingetConfigurationNulls {
    param($Node)

    if ($null -eq $Node) {
        return $null
    }
    if ($Node -is [hashtable] -or $Node -is [System.Collections.Specialized.OrderedDictionary]) {
        $out = [ordered]@{}
        foreach ($k in @($Node.Keys)) {
            $v = $Node[$k]
            if ($null -eq $v) {
                continue
            }
            if ($v -is [hashtable] -or $v -is [System.Collections.Specialized.OrderedDictionary]) {
                $nested = Remove-WingetConfigurationNulls $v
                if ($null -eq $nested -or ($nested -is [hashtable] -and $nested.Count -eq 0)) {
                    continue
                }
                $out[$k] = $nested
                continue
            }
            if ($v -is [System.Collections.IList] -and $v -isnot [string]) {
                $cleaned = [System.Collections.ArrayList]::new()
                foreach ($x in $v) {
                    if ($null -ne $x) {
                        [void]$cleaned.Add($x)
                    }
                }
                $out[$k] = ,$cleaned.ToArray()
                continue
            }
            $out[$k] = $v
        }
        return $out
    }
    if ($Node -is [System.Collections.IList] -and $Node -isnot [string]) {
        $cleaned = [System.Collections.ArrayList]::new()
        foreach ($x in $Node) {
            if ($null -ne $x) {
                [void]$cleaned.Add($x)
            }
        }
        return ,$cleaned.ToArray()
    }
    return $Node
}

function Merge-WingetSettingsHashtable {
    param(
        [hashtable]$Target,
        [hashtable]$Source
    )

    foreach ($key in $Source.Keys) {
        $srcVal = $Source[$key]
        $isTable = {
            param($x)
            return ($x -is [hashtable]) -or ($x -is [System.Collections.Specialized.OrderedDictionary])
        }
        if (& $isTable $srcVal) {
            if (-not $Target.ContainsKey($key) -or -not (& $isTable $Target[$key])) {
                $Target[$key] = [ordered]@{}
            }
            Merge-WingetSettingsHashtable -Target $Target[$key] -Source $srcVal
        } else {
            $Target[$key] = $srcVal
        }
    }
}

function Test-WingetDeepEqual {
    param(
        $Expected,
        $Actual
    )

    if ($null -eq $Expected) {
        return $true
    }
    if ($Expected -is [bool]) {
        if ($null -eq $Actual) {
            return $false
        }
        return [bool]$Actual -eq $Expected
    }
    if ($Expected -is [string]) {
        return [string]$Actual -ceq [string]$Expected
    }
    if ($Expected -is [int] -or $Expected -is [long] -or $Expected -is [double] -or $Expected -is [decimal]) {
        if ($null -eq $Actual) {
            return $false
        }
        try {
            return [double]$Actual -eq [double]$Expected
        } catch {
            return $false
        }
    }
    if ($Expected -is [System.Collections.IList] -and $Expected -isnot [string]) {
        if (-not ($Actual -is [System.Collections.IList]) -or ($Actual -is [string])) {
            return $false
        }
        if ($Expected.Count -ne $Actual.Count) {
            return $false
        }
        for ($i = 0; $i -lt $Expected.Count; $i++) {
            if (-not (Test-WingetDeepEqual -Expected $Expected[$i] -Actual $Actual[$i])) {
                return $false
            }
        }
        return $true
    }
    if ($Expected -is [hashtable] -or $Expected -is [System.Collections.Specialized.OrderedDictionary]) {
        $actualHt = ConvertTo-WingetOrderedHashtable $Actual
        if (-not ($actualHt -is [hashtable] -or $actualHt -is [System.Collections.Specialized.OrderedDictionary])) {
            return $false
        }
        foreach ($k in $Expected.Keys) {
            if (-not $actualHt.ContainsKey($k)) {
                return $false
            }
            if (-not (Test-WingetDeepEqual -Expected $Expected[$k] -Actual $actualHt[$k])) {
                return $false
            }
        }
        return $true
    }
    return "$Expected" -ceq "$Actual"
}

function Set-WingetAdminBoolSettings {
    param([Parameter(Mandatory)][string]$WingetPath)

    foreach ($pair in $WingetAdminBoolSettings.GetEnumerator()) {
        $name = $pair.Key
        $desired = $pair.Value
        if ($null -eq $desired) {
            continue
        }
        $verb = if ($desired) { '--enable' } else { '--disable' }
        Write-Log "winget settings $verb $name" -Tag "Run"
        $r = Invoke-WingetCli -WingetPath $WingetPath -Arguments @('settings', $verb, $name)
        if ($r.ExitCode -ne 0) {
            Write-Log "winget settings $verb $name failed (exit $($r.ExitCode)): $($r.StdErr)" -Tag "Error"
            return $false
        }
    }
    return $true
}

function Set-WingetAdminStringSettings {
    param([Parameter(Mandatory)][string]$WingetPath)

    foreach ($pair in $WingetAdminStringSettings.GetEnumerator()) {
        $name = $pair.Key
        $desired = $pair.Value
        if ($null -eq $desired) {
            continue
        }
        if ($desired -eq '__RESET__') {
            Write-Log "winget settings reset $name" -Tag "Run"
            $r = Invoke-WingetCli -WingetPath $WingetPath -Arguments @('settings', 'reset', $name)
            if ($r.ExitCode -ne 0) {
                Write-Log "winget settings reset $name failed (exit $($r.ExitCode)): $($r.StdErr)" -Tag "Error"
                return $false
            }
            continue
        }
        Write-Log "winget settings set $name <value>" -Tag "Run"
        $r = Invoke-WingetCli -WingetPath $WingetPath -Arguments @('settings', 'set', $name, [string]$desired)
        if ($r.ExitCode -ne 0) {
            Write-Log "winget settings set $name failed (exit $($r.ExitCode)): $($r.StdErr)" -Tag "Error"
            return $false
        }
    }
    return $true
}

function Set-WingetUserSettingsJson {
    param(
        [Parameter(Mandatory)][string]$WingetPath,
        $ExportObject
    )

    $cleanDesired = Remove-WingetConfigurationNulls $WingetUserSettings
    if ($null -eq $cleanDesired -or ($cleanDesired -is [hashtable] -and $cleanDesired.Count -eq 0)) {
        Write-Log "No user settings.json keys configured (all `$null); skipping JSON merge" -Tag "Info"
        return $true
    }

    $jsonPath = Get-WingetUserSettingsJsonPath -WingetPath $WingetPath -ExportObject $ExportObject
    if (-not $jsonPath) {
        Write-Log "Could not resolve WinGet settings.json path" -Tag "Error"
        return $false
    }

    $parentDir = Split-Path -Parent $jsonPath
    if (-not (Test-Path -LiteralPath $parentDir)) {
        try {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        } catch {
            Write-Log "Could not create settings directory $parentDir : $_" -Tag "Error"
            return $false
        }
    }

    $targetHt = [ordered]@{}
    if (Test-Path -LiteralPath $jsonPath) {
        try {
            $raw = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8
            if ($raw.Trim().Length -gt 0) {
                $existing = $raw | ConvertFrom-Json
                $targetHt = ConvertTo-WingetOrderedHashtable $existing
            }
        } catch {
            Write-Log "Could not read/parse existing settings.json: $_" -Tag "Error"
            return $false
        }
    }

    Merge-WingetSettingsHashtable -Target $targetHt -Source $cleanDesired

    try {
        $jsonText = $targetHt | ConvertTo-Json -Depth 80 -Compress:$false
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($jsonPath, $jsonText, $utf8NoBom)
        Write-Log "Wrote WinGet user settings: $jsonPath" -Tag "Success"
    } catch {
        Write-Log "Failed to write settings.json: $_" -Tag "Error"
        return $false
    }

    try {
        $null = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Log "Wrote settings.json but it does not parse as JSON: $_" -Tag "Error"
        return $false
    }

    return $true
}

function Test-WingetAdminBoolCompliance {
    param(
        [Parameter(Mandatory)]$AdminSettingsObject
    )

    foreach ($pair in $WingetAdminBoolSettings.GetEnumerator()) {
        $name = $pair.Key
        $desired = $pair.Value
        if ($null -eq $desired) {
            continue
        }
        $prop = $AdminSettingsObject.$name
        if ($null -eq $prop) {
            Write-Log "Admin setting $name missing in export; expected $desired" -Tag "Info"
            return $false
        }
        $actual = [bool]$prop
        if ($actual -ne [bool]$desired) {
            Write-Log "Admin setting $name is $actual; expected $desired" -Tag "Info"
            return $false
        }
    }
    return $true
}

function Test-WingetAdminStringCompliance {
    param(
        [Parameter(Mandatory)]$AdminSettingsObject
    )

    foreach ($pair in $WingetAdminStringSettings.GetEnumerator()) {
        $name = $pair.Key
        $desired = $pair.Value
        if ($null -eq $desired) {
            continue
        }
        $prop = $AdminSettingsObject.$name
        if ($desired -eq '__RESET__') {
            if ($null -ne $prop -and [string]$prop -ne '') {
                Write-Log "Admin string $name should be unset; found value present" -Tag "Info"
                return $false
            }
            continue
        }
        if ([string]$prop -cne [string]$desired) {
            Write-Log "Admin string $name does not match desired value" -Tag "Info"
            return $false
        }
    }
    return $true
}

function Test-WingetUserSettingsCompliance {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$JsonPath
    )

    $cleanDesired = Remove-WingetConfigurationNulls $WingetUserSettings
    if ($null -eq $cleanDesired -or ($cleanDesired -is [hashtable] -and $cleanDesired.Count -eq 0)) {
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($JsonPath)) {
        Write-Log "User settings configured but settings.json path could not be resolved" -Tag "Info"
        return $false
    }

    if (-not (Test-Path -LiteralPath $JsonPath)) {
        Write-Log "settings.json missing at $JsonPath" -Tag "Info"
        return $false
    }

    try {
        $raw = Get-Content -LiteralPath $JsonPath -Raw -Encoding UTF8
        $actualObj = $raw | ConvertFrom-Json
        $actualHt = ConvertTo-WingetOrderedHashtable $actualObj
    } catch {
        Write-Log "Could not parse settings.json for compliance: $_" -Tag "Error"
        return $false
    }

    foreach ($k in $cleanDesired.Keys) {
        if (-not $actualHt.ContainsKey($k)) {
            Write-Log "User settings missing key: $k" -Tag "Info"
            return $false
        }
        if (-not (Test-WingetDeepEqual -Expected $cleanDesired[$k] -Actual $actualHt[$k])) {
            Write-Log "User settings mismatch under: $k" -Tag "Info"
            return $false
        }
    }
    return $true
}

function Test-WingetClientSettingsCompliance {
    param([Parameter(Mandatory)][string]$WingetPath)

    $export = Get-WingetSettingsExportObject -WingetPath $WingetPath
    if ($export -and $export.adminSettings) {
        if (-not (Test-WingetAdminBoolCompliance -AdminSettingsObject $export.adminSettings)) {
            return $false
        }
        if (-not (Test-WingetAdminStringCompliance -AdminSettingsObject $export.adminSettings)) {
            return $false
        }
    } else {
        foreach ($pair in $WingetAdminBoolSettings.GetEnumerator()) {
            if ($null -ne $pair.Value) {
                Write-Log "winget settings export unavailable; cannot verify admin settings" -Tag "Info"
                return $false
            }
        }
        foreach ($pair in $WingetAdminStringSettings.GetEnumerator()) {
            if ($null -ne $pair.Value) {
                Write-Log "winget settings export unavailable; cannot verify admin string settings" -Tag "Info"
                return $false
            }
        }
    }

    $jsonPath = Get-WingetUserSettingsJsonPath -WingetPath $WingetPath -ExportObject $export
    if (-not (Test-WingetUserSettingsCompliance -JsonPath $jsonPath)) {
        return $false
    }

    return $true
}

function Invoke-WingetClientSettingsApply {
    param([Parameter(Mandatory)][string]$WingetPath)

    if (-not (Set-WingetAdminBoolSettings -WingetPath $WingetPath)) {
        return $false
    }
    if (-not (Set-WingetAdminStringSettings -WingetPath $WingetPath)) {
        return $false
    }

    $export = Get-WingetSettingsExportObject -WingetPath $WingetPath
    if (-not (Set-WingetUserSettingsJson -WingetPath $WingetPath -ExportObject $export)) {
        return $false
    }

    return $true
}

function Initialize-WingetClientSettingsDesiredState {
    $script:WingetAdminBoolSettings = [ordered]@{
        LocalManifestFiles                        = $configAdminLocalManifestFiles
        BypassCertificatePinningForMicrosoftStore = $configAdminBypassCertificatePinningForMicrosoftStore
        InstallerHashOverride                     = $configAdminInstallerHashOverride
        LocalArchiveMalwareScanOverride           = $configAdminLocalArchiveMalwareScanOverride
        ProxyCommandLineOptions                   = $configAdminProxyCommandLineOptions
    }
    $script:WingetAdminStringSettings = [ordered]@{
        DefaultProxy = $configAdminDefaultProxy
    }

    $userRoot = [ordered]@{
        '$schema'            = $configUserJsonSchema
        source               = [ordered]@{ autoUpdateIntervalInMinutes = $configUserSourceAutoUpdateIntervalInMinutes }
        visual               = [ordered]@{
            progressBar             = $configUserVisualProgressBar
            anonymizeDisplayedPaths = $configUserVisualAnonymizeDisplayedPaths
            enableSixels            = $configUserVisualEnableSixels
        }
        logging              = [ordered]@{
            level    = $configUserLoggingLevel
            channels = $configUserLoggingChannels
            file     = [ordered]@{
                ageLimitInDays          = $configUserLoggingFileAgeLimitInDays
                totalSizeLimitInMB      = $configUserLoggingFileTotalSizeLimitInMB
                countLimit              = $configUserLoggingFileCountLimit
                individualSizeLimitInMB = $configUserLoggingFileIndividualSizeLimitInMB
            }
        }
        installBehavior      = [ordered]@{
            preferences              = [ordered]@{
                scope          = $configUserInstallPreferencesScope
                locale         = $configUserInstallPreferencesLocale
                architectures  = $configUserInstallPreferencesArchitectures
                installerTypes = $configUserInstallPreferencesInstallerTypes
            }
            requirements             = [ordered]@{
                scope          = $configUserInstallRequirementsScope
                locale         = $configUserInstallRequirementsLocale
                architectures  = $configUserInstallRequirementsArchitectures
                installerTypes = $configUserInstallRequirementsInstallerTypes
            }
            skipDependencies             = $configUserInstallSkipDependencies
            disableInstallNotes          = $configUserInstallDisableInstallNotes
            portablePackageUserRoot      = $configUserInstallPortablePackageUserRoot
            portablePackageMachineRoot   = $configUserInstallPortablePackageMachineRoot
            defaultInstallRoot           = $configUserInstallDefaultInstallRoot
            maxResumes                   = $configUserInstallMaxResumes
            archiveExtractionMethod      = $configUserInstallArchiveExtractionMethod
        }
        uninstallBehavior    = [ordered]@{
            purgePortablePackage = $configUserUninstallPurgePortablePackage
        }
        configureBehavior    = [ordered]@{
            defaultModuleRoot = $configUserConfigureDefaultModuleRoot
        }
        downloadBehavior     = [ordered]@{
            defaultDownloadDirectory = $configUserDownloadDefaultDirectory
        }
        telemetry            = [ordered]@{
            disable = $configUserTelemetryDisable
        }
        network              = [ordered]@{
            downloader                 = $configUserNetworkDownloader
            doProgressTimeoutInSeconds = $configUserNetworkDoProgressTimeoutInSeconds
        }
        interactivity        = [ordered]@{
            disable = $configUserInteractivityDisable
        }
        experimentalFeatures = [ordered]@{
            experimentalCMD = $configUserExperimentalExperimentalCMD
            experimentalARG = $configUserExperimentalExperimentalARG
            directMSI         = $configUserExperimentalDirectMSI
            fonts             = $configUserExperimentalFonts
            resume            = $configUserExperimentalResume
            sourcePriority    = $configUserExperimentalSourcePriority
        }
    }
    $script:WingetUserSettings = Remove-WingetConfigurationNulls $userRoot
}

Initialize-WingetClientSettingsDesiredState

# ---------------------------[ Script Start ]---------------------------
Write-Log "======== Script Started ========" -Tag "Start"
Write-Log "ComputerName: $env:COMPUTERNAME | User: $env:USERNAME | Script: $scriptName (Platform)" -Tag "Info"

try {
    Write-Log "Applying WinGet client configuration" -Tag "Run"
    $wingetExecutablePath = Get-WingetExecutablePathForSystem
    if (-not $wingetExecutablePath) {
        Write-Log "Could not resolve winget.exe; is App Installer installed?" -Tag "Error"
        Complete-Script -ExitCode 1
    }

    $applied = Invoke-WingetClientSettingsApply -WingetPath $wingetExecutablePath
    if ($applied) {
        Write-Log "WinGet client settings applied successfully" -Tag "Success"
        Complete-Script -ExitCode 0
    }
    Complete-Script -ExitCode 1
} catch {
    Write-Log "Unexpected failure: $_" -Tag "Error"
    Complete-Script -ExitCode 1
}
