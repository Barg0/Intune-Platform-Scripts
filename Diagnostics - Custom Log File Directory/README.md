# Diagnostics – Custom Log File Directory

This **platform script** for **Microsoft Intune** configures a custom directory for the **Collect diagnostics** feature to pull logs from.

---

## 🛠️ Configuration

Set your desired path in the `ValueName` field within the `$registryKeys` array:

```powershell
$registryKeys = @(
    @{
        Hive        = 'HKEY_LOCAL_MACHINE'
        KeyPath     = 'SOFTWARE\Microsoft\MdmDiagnostics\Area\DeviceProvisioning\FileEntry'
        ValueName   = '%ProgramData%\IntuneLogs\*.*'
        ValueData   = 255
        ValueType   = 'DWord'
    }
)
```

> **Note:** Always append `*.*` to the defined path so all files are included.

---

## 📦 Behavior

Collected logs will be included in the `.cab` file under the `FoldersFiles temp_MDMDiagnostics_mdmlogs` directory.

### Example:

```
 📦 DiagLogs-WS-612C05C43D39-20250529T111442Z.zip   
> ├─📁 (77) FoldersFiles temp_MDMDiagnostics_mdmlogs-2025-05-29-11-05-38_cab
> │  └─📦 mdmlogs-2025-05-29-11-05-38.cab
> │     └─📜 IntuneLogs-Applications-7-Zip-detection.log
> │     ├─📜 IntuneLogs-Applications-7-Zip-install.log
> │     ├─📜 IntuneLogs-Scripts-Kerberos - Retrieval time.log
> │     └─📜 IntuneLogs-Scripts-Create - admin.laps.log
```

---

## ✅ Why Use a Custom Log Folder?

By default, Intune scripts log to:

```
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Scripts
```

However, if your script runs with **logged-on user credentials**, it may not have permission to write there. A custom folder like `%ProgramData%\IntuneLogs` ensures that logs are written successfully regardless of execution context.

---

## 📋 Intune Script Settings

In the [Intune Admin Center](https://intune.microsoft.com):

Navigate to:
`Devices` → `Windows` → `Scripts and remediations` → `Platform scripts` → `Create`

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run this script using logged-on credentials | `No`  |
| Enforce script signature check              | `No`  |
| Run script in 64-bit PowerShell             | `Yes` |

---
