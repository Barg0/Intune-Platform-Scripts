# 🎨 Set-PersonalizationDefaults

A PowerShell script that configures Windows 10 and Windows 11 personalization settings via registry and Win32 API. Designed for deployment through Microsoft Intune in **user context**.

## 📋 What it does

The script applies a predefined set of personalization defaults to the current user's Windows environment. It covers theme settings, Explorer behavior, taskbar layout, system tray, and desktop wallpaper.

All settings are configured in a single configuration block at the top of the script. The script detects the Windows version automatically and only applies settings that are supported on that OS.

After applying changes, the script verifies every setting and restarts Explorer to make visual changes take effect immediately.

## 💻 Supported platforms

| OS | Status |
|---|---|
| 🪟 Windows 11 | ✅ Supported |
| 🪟 Windows 10 | ✅ Supported |

## ⚙️ Configuration

All options are defined in the `CONFIGURATION` section at the top of the script. Each option accepts a specific set of values or `$null` to skip it entirely.

### 🎨 Theme

| Variable | Values | Description |
|---|---|---|
| `$configTaskbarTheme` | `"dark"` \| `"light"` \| `$null` | System/taskbar color mode |
| `$configExplorerTheme` | `"dark"` \| `"light"` \| `$null` | Explorer and apps color mode |
| `$configAutoColorization` | `$true` \| `$false` \| `$null` | Automatic accent color from wallpaper |
| `$configTransparency` | `$true` \| `$false` \| `$null` | Transparency effects |

### 📁 Explorer

| Variable | Values | Description |
|---|---|---|
| `$configLaunchTo` | `"computer"` \| `"quick-access"` \| `$null` | Explorer default view |
| `$configShowFileExtensions` | `$true` \| `$false` \| `$null` | Show known file extensions |
| `$configShowCheckboxes` | `$true` \| `$false` \| `$null` | Item selection checkboxes |

### 📌 Taskbar

| Variable | Values | Description |
|---|---|---|
| `$configShowTaskView` | `$true` \| `$false` \| `$null` | Task View button |

### 🖼️ Wallpaper

| Variable | Values | Description |
|---|---|---|
| `$configWallpaper` | `"default"` \| `"C:\path\to\image.jpg"` \| `$null` | Desktop wallpaper |

Setting `$configWallpaper` to `"default"` uses the stock OS wallpaper (`img0.jpg` on Windows 10, `img19.jpg` on Windows 11). A custom file path can be specified instead.

### 🪟 Windows 10 only

| Variable | Values | Description |
|---|---|---|
| `$configSearchbarModeWin10` | `"hidden"` \| `"icon"` \| `"box"` \| `$null` | Search bar appearance |
| `$configShowCortana` | `$true` \| `$false` \| `$null` | Cortana button |
| `$configShowNewsAndInterests` | `$true` \| `$false` \| `$null` | News and Interests widget |
| `$configShowAllTrayIcons` | `$true` \| `$false` \| `$null` | Show all icons in system tray |

### 🪟 Windows 11 only

| Variable | Values | Description |
|---|---|---|
| `$configSearchbarModeWin11` | `"hidden"` \| `"icon"` \| `"box"` \| `"icon-label"` \| `$null` | Search bar appearance |
| `$configClassicContextMenu` | `$true` \| `$false` \| `$null` | Classic right-click menu |
| `$configStartAlignment` | `"left"` \| `"center"` \| `$null` | Start menu position |

## 🚀 Intune deployment

### 🔧 Script settings

| Setting | Value |
|---|---|
| Run this script using the logged-on credentials | ✅ **Yes** |
| Run script in 64-bit PowerShell host | ✅ **Yes** |
| Enforce script signature check | ❌ No |

> ⚠️ The script **must** run in user context. All registry changes target `HKEY_CURRENT_USER` and do not require elevation.

## 📝 Logging

Logs are written to:

```
C:\ProgramData\IntuneLogs\Scripts\Set-PersonalizationDefaults\Set-PersonalizationDefaults.log
```

### 🏷️ Log tags

| Tag | Meaning |
|---|---|
| `Start` / `End` | 🟢 Script lifecycle |
| `Get` | 🔍 Information retrieval (OS detection) |
| `Run` | ⚡ A change is being applied |
| `Success` | ✅ Action completed or setting verified |
| `Error` | ❌ Action failed or verification mismatch |
| `Info` | ℹ️ General information |
| `Debug` | 🐛 Verbose troubleshooting details |

### 🐛 Debug logging

Set `$logDebug = $true` in the logging setup section to enable verbose output. Debug entries include registry paths, values, and `reg.exe` output on failure. Disable after troubleshooting.

## 🔄 How it works

1. 🔍 **OS detection** -- Identifies Windows 10 or 11 from the OS version string
2. 📋 **Build settings** -- Reads the configuration and builds a list of registry operations, filtered to the detected OS
3. ⚡ **Apply** -- Sets each registry value using `reg.exe`. Only values that differ from the desired state are changed
4. ✅ **Verify** -- Reads back every value and compares against the expected state
5. 🖼️ **Wallpaper** -- Applies the desktop wallpaper via the Win32 `SystemParametersInfo` API
6. 🔄 **Explorer restart** -- Restarts `explorer.exe` so visual changes take effect immediately
7. 🏁 **Exit** -- Returns exit code `0` if all verifications passed, `1` otherwise

## 🔢 Exit codes

| Code | Meaning |
|---|---|
| `0` | ✅ All settings applied and verified |
| `1` | ❌ One or more settings failed verification |
