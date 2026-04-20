# 🎨 Set-PersonalizationDefaults

PowerShell script that applies Windows **10** and **11** 🪟 personalization defaults for the **current user** via registry (`HKCU`) and the Win32 wallpaper API. Intended for **Microsoft Intune** ☁️ platform scripts running in **user context** 👤.

## 📋 What it does

- 📄 Reads the **`CONFIGURATION`** block at the top of `Set-PersonalizationDefaults.ps1`.
- 🔍 Detects **Windows 10 vs 11** and only applies settings valid for that OS.
- ⚡ Applies registry values with **`reg.exe`**, verifies each value, applies optional wallpaper 🖼️, then **restarts Explorer** 🔄 so UI changes show up.
- 📝 Writes a **per-user log** under ProgramData (see [Logging](#logging)).

## 🚀 Quick start

1. ✏️ Open **`Set-PersonalizationDefaults.ps1`** in an editor.
2. 🎛️ In the **`CONFIGURATION`** section (lines marked by the banner comments), set each **`$config…`** variable to the value you want, or **`$null`** to **skip** that setting (leave Windows default unchanged).
3. ☁️ Save the file and assign it as an **Intune** → **Scripts** (or **Remediations**) item, **running as the logged-on user** (see [Intune deployment](#intune-deployment)).
4. ✅ After a run, check the log file and exit code: **`0`** means every applied setting verified; **`1`** means at least one verification failed.

You can also run the script manually on a test machine 🧪 (same user context) to validate behavior before packaging for Intune.

## 💻 Supported platforms

| OS | Status |
| --- | --- |
| 🪟 Windows 11 | ✅ Supported |
| 🪟 Windows 10 | ✅ Supported |

Other OS versions cause the script to exit with code **`1`** ⛔ without applying settings.

## ⚙️ Configuration reference

Every option lives in the **`CONFIGURATION`** block. Allowed values are shown in the table; **`$null`** always means “do not change this setting.” ⏭️

### 🌓 Theme

| Variable | Values | Description |
| --- | --- | --- |
| `$configTaskbarTheme` | `"dark"` \| `"light"` \| `$null` | Light/dark for the system shell (e.g. taskbar) via `Themes\Personalize` |
| `$configExplorerTheme` | `"dark"` \| `"light"` \| `$null` | Light/dark for apps / Explorer via `Themes\Personalize` |

### 🎨 Color

| Variable | Values | Description |
| --- | --- | --- |
| `$configAutoColorization` | `$true` \| `$false` \| `$null` | **Automatic accent from wallpaper** 🖼️ (`Control Panel\Desktop\AutoColorization`). Set **`$false`** if you want a **fixed** accent from `$configAccentColorHex`. |
| `$configAccentColorHex` | `"#RRGGBB"`, `"RRGGBB"`, or `$null` | Custom accent 🎯. When not `$null`, the script writes **`AccentColor`** / **`AccentColorMenu`** under `...\Explorer\Accent`, **`AccentColor`** under `...\DWM`, and a generated **`AccentPalette`** (`REG_BINARY`). Colors are **clamped to Windows’ HSL luminance range (25–75%)** 📊 before encoding; if clamping changes the color, an **Info** log line records input → output hex. |
| `$configColorPrevalenceStartTaskbar` | `$true` \| `$false` \| `$null` | **Accent on Start and taskbar** — `Themes\Personalize\ColorPrevalence` |
| `$configColorPrevalenceTitleBars` | `$true` \| `$false` \| `$null` | **Accent on title bars and window borders** — `DWM\ColorPrevalence` (separate from the Personalize toggle) |
| `$configTransparency` | `$true` \| `$false` \| `$null` | **Transparency effects** ✨ — `Themes\Personalize\EnableTransparency` |

**💡 Windows 11 note (in-script comment):** Windows 11 may still override accent colors for contrast, especially with a **light** taskbar theme. For the most predictable custom accent, keep **`$configTaskbarTheme = "dark"`** when using a fixed hex accent.

### 📁 Explorer

| Variable | Values | Description |
| --- | --- | --- |
| `$configLaunchTo` | `"computer"` \| `"quick-access"` \| `$null` | Default location when opening a new Explorer window |
| `$configShowFileExtensions` | `$true` \| `$false` \| `$null` | Show file extensions for known types |
| `$configShowCheckboxes` | `$true` \| `$false` \| `$null` | Item checkboxes in Explorer |

### 📌 Taskbar

| Variable | Values | Description |
| --- | --- | --- |
| `$configShowTaskView` | `$true` \| `$false` \| `$null` | Task View button visibility |

### 🖼️ Wallpaper

| Variable | Values | Description |
| --- | --- | --- |
| `$configWallpaper` | `"default"` \| full path to an image \| `$null` | Desktop wallpaper. `"default"` uses the built-in Windows image (`img0.jpg` on Windows 10, `img19.jpg` on Windows 11). The file must exist or the script reports an error. |

### 🪟 Windows 10 only

| Variable | Values | Description |
| --- | --- | --- |
| `$configSearchbarModeWin10` | `"hidden"` \| `"icon"` \| `"box"` \| `$null` | Taskbar search appearance |
| `$configShowCortana` | `$true` \| `$false` \| `$null` | Cortana button on the taskbar |
| `$configShowNewsAndInterests` | `$true` \| `$false` \| `$null` | News and interests on the taskbar |
| `$configShowAllTrayIcons` | `$true` \| `$false` \| `$null` | Show all notification area icons |

### 🪟 Windows 11 only

| Variable | Values | Description |
| --- | --- | --- |
| `$configSearchbarModeWin11` | `"hidden"` \| `"icon"` \| `"box"` \| `"icon-label"` \| `$null` | Taskbar search appearance |
| `$configStartAlignment` | `"left"` \| `"center"` \| `$null` | Start button alignment on the taskbar |
| `$configClassicContextMenu` | `$true` \| `$false` \| `$null` | Classic context menu (registry-based; Windows 11 only) |

## ☁️ Intune deployment

| Setting | Recommended value |
| --- | --- |
| Run this script using the logged on credentials | ✅ **Yes** |
| Run script in 64-bit PowerShell host | ✅ **Yes** |

The script only touches **`HKEY_CURRENT_USER`** 🔑. It does **not** require elevation, but it **must** run as the user whose profile you want to personalize.

## 📝 Logging

Log file path (per user running the script):

```text
%ProgramData%\IntuneLogs\Scripts\<Username>\Set-PersonalizationDefaults.log
```

Example:

```text
C:\ProgramData\IntuneLogs\Scripts\JaneDoe\Set-PersonalizationDefaults.log
```

### 🏷️ Log tags

| Tag | Meaning |
| --- | --- |
| `Start` / `End` | 🟢 Script lifecycle |
| `Get` | 🔍 OS / environment information |
| `Run` | ⚡ A change is being applied |
| `Success` | ✅ Applied or already correct, or verification OK |
| `Error` | ❌ Failure or verification mismatch |
| `Info` | ℹ️ General messages (including accent luminance clamp notices) |
| `Debug` | 🐛 Extra detail (registry paths, `reg.exe` output on failure) |

Enable **`$logDebug = $true`** in the logging section of the script for troubleshooting; turn it off afterward.

## 🔄 How it works

1. 🔍 **OS detection** — Classifies Windows 10 vs 11 from the build string.
2. 📋 **Build settings** — Builds a list of registry operations from your config, filtered by OS.
3. ⚡ **Apply** — Runs `reg add` for each change; skips values that already match (including correct handling for `REG_DWORD` and `REG_BINARY` where applicable).
4. ✅ **Verify** — Reads back each value and compares to the expected state.
5. 🖼️ **Wallpaper** — If configured, sets wallpaper via `SystemParametersInfo` when the file exists.
6. 🔄 **Explorer restart** — Stops and starts `explorer.exe` so shell colors and taskbar update.
7. 🏁 **Exit code** — **`0`** if all checks passed, **`1`** if any verification failed (or unsupported OS).

## 🔢 Exit codes

| Code | Meaning |
| --- | --- |
| `0` | ✅ All processed settings verified successfully |
| `1` | ⛔ Unsupported OS, or at least one setting failed verification |
