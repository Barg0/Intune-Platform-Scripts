# 🔧 Winget - System Context

Ensures **winget** works reliably under the **SYSTEM account** on Windows devices managed by Microsoft Intune.

When Intune runs Win32 app installations in system context, winget often fails because the SYSTEM account cannot resolve the required UWP dependency DLLs (`Microsoft.VCLibs`, `Microsoft.UI.Xaml`). This script detects and repairs that issue automatically.

> ⭐ **Recommended prerequisite** for [Intune-Winget](https://github.com/Barg0/Intune-Winget) — deploy this script via Intune before deploying winget-based Win32 apps to ensure winget is functional in system context on all target devices.

---

## 📋 How It Works

1. **🔍 Health check** — Locates the latest `winget.exe` in `WindowsApps` (x64, arm64 fallback) and runs `winget -v` to verify it executes successfully.
2. **🔨 Repair** — If the health check fails, the script registers the dependency DLL directories into the machine-level `PATH`:
   - `Microsoft.VCLibs.140.00.UWPDesktop`
   - `Microsoft.UI.Xaml.2.8`
3. **🚪 Exit** — Exits with code `0` so Intune can retry after a restart, which is required for PATH changes to take effect.

---

## 🚀 Intune Deployment

| Setting              | Value                                  |
|----------------------|----------------------------------------|
| Install command      | `powershell.exe -ExecutionPolicy Bypass -File "Winget - System Context.ps1"` |
| Install behavior     | System                                 |
| Restart behavior     | Allow app restart                      |

Deploy as a **Platform script** or package as a **Win32 app** — whichever fits your environment.

---

## 📝 Logging

Logs are written to:

```
%ProgramData%\IntuneLogs\Scripts\Winget-SystemContext.log
```

### Log Tags

| Tag       | Purpose                              |
|-----------|--------------------------------------|
| `Start`   | Script start                         |
| `Get`     | Discovery operations (paths, versions) |
| `Run`     | Execution operations (repair, PATH updates) |
| `Info`    | General status messages              |
| `Success` | Successful outcomes                  |
| `Error`   | Failures                             |
| `Debug`   | Verbose troubleshooting (disabled by default) |
| `End`     | Script completion                    |

### ⚙️ Configuration

| Variable         | Default  | Description                          |
|------------------|----------|--------------------------------------|
| `$log`           | `$true`  | Enable or disable all logging        |
| `$logDebug`      | `$false` | Enable verbose debug log entries     |
| `$logGet`        | `$true`  | Enable discovery log entries         |
| `$logRun`        | `$true`  | Enable execution log entries         |
| `$enableLogFile` | `$true`  | Write logs to file on disk           |

Set `$logDebug = $true` to get detailed troubleshooting output.

---

## 🖥️ Architecture Support

The script automatically detects and prefers **x64** packages. If x64 is not available, it falls back to **arm64** — for both the winget executable itself and its UWP dependencies.
