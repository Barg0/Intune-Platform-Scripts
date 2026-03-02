# 🌐 Set-NetworkPreferIpv4

A PowerShell script that configures Windows to **prefer IPv4 over IPv6** by setting the `DisabledComponents` registry value. Designed for deployment via **Microsoft Intune** (Platform Scripts) or manual execution.

---

## 📋 What Does It Do?

By default, Windows 10/11 uses a **dual-stack** approach and may prefer IPv6 when both IPv4 and IPv6 are available. This can cause issues in environments where:

- 🔌 Legacy applications or services expect IPv4
- 🏢 VPN or network infrastructure is IPv4-only
- 🌍 Some sites or services behave inconsistently over IPv6

This script sets the following registry value:

| Location | Value | Data |
|----------|-------|------|
| `HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\` | `DisabledComponents` | `32` (DWord) |

**Value `32` (0x20)** means: prefer IPv4 over IPv6 while keeping IPv6 enabled. The system will try IPv4 first when resolving names and making connections.

---

## 🚀 How to Use

### Option 1: Run Manually (Local / Testing)

1. Open **PowerShell as Administrator** (right-click → Run as administrator).
2. Navigate to the script folder and run:

```powershell
.\Set-NetworkPreferIpv4.ps1
```

3. Review the console output and check the log file if needed.

> ⚠️ **Note:** Administrator rights are required because the script writes to `HKEY_LOCAL_MACHINE`.

### Option 2: Deploy via Microsoft Intune

1. In **Microsoft Intune** → **Devices** → **Scripts** → **Platform scripts**, create a new script.
2. Upload `Set-NetworkPreferIpv4.ps1`.
3. Assign the script to the desired device group (User or Device context).
4. The script runs in **system context** and will configure the device after deployment.

---

## 📂 Requirements

| Requirement | Details |
|-------------|---------|
| **PowerShell** | 5.1 or later |
| **OS** | Windows 10 / Windows 11 / Windows Server |
| **Permissions** | Administrator (elevated) or SYSTEM |

---

## 📝 Logging

The script writes structured logs to:

```
%ProgramData%\IntuneLogs\Scripts\Set-NetworkPreferIpv4.log
```

You can adjust logging in the script:

| Variable | Default | Description |
|----------|---------|-------------|
| `$log` | `$true` | Enable/disable all logging |
| `$logDebug` | `$false` | Verbose debug output (set `$true` for troubleshooting) |
| `$logGet` | `$true` | Log verification (Get) steps |
| `$logRun` | `$true` | Log registry changes (Run) steps |
| `$enableLogFile` | `$true` | Write to log file |

---

## 🔄 Applying Changes

Registry changes take effect immediately. A **reboot is required**.

---

## 🛠️ Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success – all registry values set and validated |
| `1` | Failure – set or validation failed (check logs) |

---

## 📜 License

Use and modify as needed for your environment.

