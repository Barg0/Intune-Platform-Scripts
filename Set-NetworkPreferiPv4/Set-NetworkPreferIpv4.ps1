$ErrorActionPreference = 'Stop'
# ---------------------------[ Script Start Timestamp ]---------------------------
$scriptStartTime       = Get-Date

# ---------------------------[ Script Name ]---------------------------
$scriptName      = "Set-NetworkPreferIpv4"
$logFileName     = "$scriptName.log"

# ---------------------------[ Configuration ]---------------------------
$disabledComponentsPreferIpv4 = 32
$tcpip6ParametersPath        = 'SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\'

$registryKeys = @(
    @{
        Hive      = 'HKEY_LOCAL_MACHINE'
        KeyPath   = $tcpip6ParametersPath
        ValueName = 'DisabledComponents'
        ValueData = $disabledComponentsPreferIpv4
        ValueType = 'DWord'
    }
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
    param([int]$exitCode)

    $scriptEndTime = Get-Date
    $duration      = $scriptEndTime - $scriptStartTime

    Write-Log "Script execution time: $($duration.ToString('hh\:mm\:ss\.ff'))" -Tag "Info"
    Write-Log "Exit Code: $exitCode" -Tag "Info"
    Write-Log "======== Script Completed ========" -Tag "End"

    exit $exitCode
}

# ---------------------------[ Helper Functions ]---------------------------
function Test-RegistryKeyValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$hive,
        [Parameter(Mandatory = $true)]
        [string]$keyPath,
        [Parameter(Mandatory = $true)]
        [string]$valueName,
        [Parameter(Mandatory = $true)]
        [object]$expectedValue
    )

    $fullRegistryPath = "Registry::$(Join-Path $hive $keyPath)"

    try {
        $actualValue = Get-ItemProperty -Path $fullRegistryPath -Name $valueName -ErrorAction Stop |
            Select-Object -ExpandProperty $valueName

        return ("$actualValue" -eq "$expectedValue")
    }
    catch {
        return $false
    }
}

function Set-RegistryValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$hive,
        [Parameter(Mandatory = $true)]
        [string]$keyPath,
        [Parameter(Mandatory = $true)]
        [string]$valueName,
        [Parameter(Mandatory = $true)]
        [object]$valueData,
        [Parameter(Mandatory = $true)]
        [string]$valueType
    )

    $fullRegistryPath = "Registry::$(Join-Path $hive $keyPath)"

    if (-not (Test-Path -Path $fullRegistryPath)) {
        New-Item -Path $fullRegistryPath -Force | Out-Null
    }

    Set-ItemProperty -Path $fullRegistryPath -Name $valueName -Value $valueData -Type $valueType -Force
}

# ---------------------------[ Script Start ]---------------------------
Write-Log "======== Script Started ========" -Tag "Start"
Write-Log "ComputerName: $env:COMPUTERNAME | User: $env:USERNAME | Script: $scriptName" -Tag "Info"

foreach ($registryKey in $registryKeys) {
    $regPath   = Join-Path $registryKey.Hive $registryKey.KeyPath
    $setParams = @{
        hive      = $registryKey.Hive
        keyPath   = $registryKey.KeyPath
        valueName = $registryKey.ValueName
        valueData = $registryKey.ValueData
        valueType = $registryKey.ValueType
    }

    try {
        Set-RegistryValue @setParams
        Write-Log "Set $($registryKey.ValueName) = $($registryKey.ValueData) in $regPath to prefer IPv4 over IPv6" -Tag "Run"
    }
    catch {
        Write-Log "Failed to set $($registryKey.ValueName) in ${regPath}: $($_.Exception.Message)" -Tag "Error"
        Complete-Script -exitCode 1
    }

    $testParams = @{
        hive          = $registryKey.Hive
        keyPath       = $registryKey.KeyPath
        valueName     = $registryKey.ValueName
        expectedValue = $registryKey.ValueData
    }
    $isValid = Test-RegistryKeyValue @testParams

    if ($isValid) {
        Write-Log "Verified $($registryKey.ValueName) = $($registryKey.ValueData) in $regPath" -Tag "Get"
    }
    else {
        Write-Log "Validation failed: $($registryKey.ValueName) in $regPath does not match expected value $($registryKey.ValueData)" -Tag "Error"
        Complete-Script -exitCode 1
    }
}

Write-Log "All registry values set and validated successfully; system will prefer IPv4 over IPv6" -Tag "Success"

Complete-Script -exitCode 0
