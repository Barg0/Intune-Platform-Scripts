# Kerberos Ticket - Retrieval Time

This **Platform Script** for **Microsoft Intune** configures the `FarKdcTimeout` registry value under Kerberos settings to `0`. This optimization ensures faster Kerberos ticket retrieval in VPN scenarios involving **Windows Hello for Business** with **Microsoft Entra Kerberos for on-prem authentication** on **Entra-joined (cloud-native) devices**.

---

## ⚙️ What It Does

The script sets the following registry value:

| Registry Path                                                                 | Value Name      | Type    | Data |
| ----------------------------------------------------------------------------- | --------------- | ------- | ---- |
| `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters` | `FarKdcTimeout` | `DWORD` | `0`  |

---

### 💡 Why Are We Doing This?

When users start their devices outside the corporate network, they typically rely on a VPN to access on-prem resources such as file shares. During login process, the system may attempt to request Kerberos tickets before the VPN is connected — causing failures due to lack of connectivity with a domain controller.

By setting `FarKdcTimeout = 0`, the system avoids waiting for retries.

🔗 Microsoft Documentation:
[Entra Private Access - On-Prem SSO](https://microsoft.github.io/GlobalSecureAccess/Entra%20Private%20Access/OnPremSSO/)

---

## 📄 Logging

### Example Log Output:

```
2025-05-31 15:20:54 [  Start   ] ======== Platform Script Started ========
2025-05-31 15:20:54 [  Info    ] ComputerName: WS-81F690CC7DE6 | User: WS-81F690CC7DE6$ | Script: Kerberos Ticket - Retrieval time
2025-05-31 15:20:54 [  Info    ] Set FarKdcTimeout to 0 in HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters
2025-05-31 15:20:54 [  Success ] Verified: HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters\FarKdcTimeout = 0
2025-05-31 15:20:54 [  Success ] All registry values were set and validated successfully.
2025-05-31 15:20:54 [  Info    ] Script execution time: 00:00:00.02
2025-05-31 15:20:54 [  Info    ] Exit Code: 0
2025-05-31 15:20:54 [  End     ] ======== Platform Script Completed ========
```
> [!TIP]
> The **📄 Log file** for this script is saved at:
> `C:\ProgramData\IntuneLogs\Scripts\`
>
> ```
> C:  
> ├─📁 ProgramData
> │  └─📁 IntuneLogs
> │     └─📁 Scripts
> │        └─📄 Kerberos Ticket - Retrieval times.log
> ```
> To enable log collection from this custom directory using the **Collect diagnostics** feature in Intune, deploy the following platform script:
>
> [Diagnostics - Custom Log File Directory](https://github.com/Barg0/Intune-Platform-Scripts/tree/main/Diagnostics%20-%20Custom%20Log%20File%20Directory)

---

## 📋 Intune Script Settings

In the [Intune Admin Center](https://intune.microsoft.com):

Navigate to:
`Devices` → `Windows` → `Scripts and remediations` → `Platform scripts` → `Create`

Use these settings:

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run this script using logged-on credentials | No    |
| Enforce script signature check              | No    |
| Run script in 64-bit PowerShell             | Yes   |

---
