# 🧹 Remove-BuiltInApps

PowerShell script that removes pre-installed Windows apps (bloatware) from Windows 10 and Windows 11 devices. Designed to run as a **Microsoft Intune Platform Script**.

## 📋 What It Does

The script performs two removal operations for each target app:

1. **Uninstalls installed app packages** for all user profiles on the device
2. **Removes provisioned app packages** so the apps do not reinstall for new user profiles

A configurable **protected apps list** 🛡️ prevents critical system dependencies (Store, .NET runtime, VCLibs, etc.) from being removed, even if accidentally added to the target list.

## 💻 Supported Operating Systems

| OS | Removal Method |
|---|---|
| 🪟 Windows 11 | `Remove-AppxPackage -AllUsers` |
| 🪟 Windows 10 | Per-user removal via SID enumeration |

The script detects the OS version automatically and exits with code `1` on unsupported versions.

## ⚙️ How It Works

```
Start
  |
  +--> Detect OS version (Windows 10 / 11)
  |
  +--> For each target app:
  |      |
  |      +--> Skip if app is in the protected list
  |      |
  |      +--> Uninstall installed packages (per-user on Win10, all-users on Win11)
  |      |
  |      +--> Remove provisioned package (prevents reinstall for new users)
  |
  +--> Exit with code 0
```

## 🔧 Configuration

All configurable data is at the top of the script.

### 🛡️ Protected Apps

Apps in `$protectedApps` are never removed. These are system dependencies required for Windows and the Microsoft Store to function:

```powershell
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
```

### 🗑️ Target Apps

Apps in `$targetApps` will be removed. To add or remove apps, edit this list. Use the Appx package name (not the display name).

To find the package name of an installed app:

```powershell
Get-AppxPackage | Select-Object Name | Sort-Object Name
```

### 📝 Logging

| Variable | Default | Description |
|---|---|---|
| `$log` | `$true` | Master switch for all logging |
| `$logDebug` | `$false` | Enable verbose debug-level log entries |
| `$logGet` | `$true` | Enable log entries for query operations |
| `$logRun` | `$true` | Enable log entries for removal operations |
| `$enableLogFile` | `$true` | Write log output to a file on disk |

📂 Log files are written to:

```
C:\ProgramData\IntuneLogs\Scripts\Remove-BuiltInApps\Remove-BuiltInApps.log
```

Set `$logDebug` to `$true` to enable verbose troubleshooting output, which includes full package names, package identifiers, and complete error details.

> [!TIP]
> The **📄 Log file** for this script is saved at:
> `C:\ProgramData\IntuneLogs\Scripts\`
>
> ```
> C:  
> ├─📁 ProgramData
> │  └─📁 IntuneLogs
> │     └─📁 Scripts
> │        └─📄 Remove-BuiltInApps.log
> ```
> To enable log collection from this custom directory using the **Collect diagnostics** feature in Intune, deploy the following platform script:
>
> [Diagnostics - Custom Log File Directory](https://github.com/Barg0/Intune-Platform-Scripts/tree/main/Diagnostics%20-%20Custom%20Log%20File%20Directory)

## 🚀 Deployment via Microsoft Intune

1. In the [Microsoft Intune admin center](https://intune.microsoft.com), navigate to **Devices > Scripts and remediations > Platform scripts**
2. Click **Add > Windows 10 and later**
3. Provide a name (e.g. `Remove-BuiltInApps`) and click **Next**
4. Upload `Remove-BuiltInApps.ps1` with the following settings:

| Setting | Value |
|---|---|
| Run this script using the logged on credentials | **No** |
| Enforce script signature check | **No** |
| Run script in 64 bit PowerShell Host | **Yes** |

5. Assign to a device group and click **Create**

The script runs under the **SYSTEM** context, which is required for `Remove-AppxPackage -AllUsers` and `Remove-AppxProvisionedPackage -Online`.

## ✅ Exit Codes

| Code | Meaning |
|---|---|
| `0` | ✅ Script completed successfully |
| `1` | ❌ Unsupported OS version detected |

## ⚠️ Important Notes

- 🔄 **Logoff required on Windows 10**: Apps are removed at the package level immediately, but the Start Menu does not refresh until the user logs off and back on.
- 🔒 **Run as SYSTEM**: The script must run in the system context (not as the logged-on user) to remove packages for all users and deprovision apps.
- 🧩 **PowerShell 5.1 compatibility**: The script is compatible with Windows PowerShell 5.1, which is the runtime used by Intune Platform Scripts. It uses only ASCII characters and K&R brace style to avoid encoding and parsing issues.
- ♻️ **Idempotent**: The script can run multiple times safely. Already-removed apps are skipped silently (logged at Debug level).
