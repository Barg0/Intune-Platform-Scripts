# Create - admin.laps (Local Admin Account Script)

This **Platform Script** for **Microsoft Intune** creates a dedicated local user account named `admin.laps`. By default, this user is **not** added to the local `Administrators` group to avoid conflicts in hybrid environments where group memberships are managed via **Group Policy**.

---

## ⚙️ How to Use

To change the `account name`, `display name`, or `description`, modify these values at the top of the script:

```powershell
$userName = "admin.laps"
$userFullName = "LAPS Administrator"
$userDescription = "LAPS"
```
---

## 🧭 Why Not Add to the Administrators Group Automatically?

In hybrid or on-prem environments, local administrator group membership is often managed by Group Policy:

* Domain Admins may be removed
* Specific delegated accounts may be added

Modifying group membership via script can create conflicts or unintended overrides.

### ✅ Recommended Approach

* **Cloud-native devices**: Use a separate Intune policy to manage group membership
* **Hybrid/on-prem devices**: Use Group Policy to assign the user to the Administrators group

---

## 🛡️ Group Policy for Hybrid Devices

Create a new `Group Policy` and give it a descriptive name that reflects its purpose. 
Navigate to:
`Computer Configuration` → `Preferences` → `Control Panel Settings` → `Local Users and Groups` → `New` → `Local Group`

* **Action**: `Update`
* **Group name**: `Administrators (built-in)`
* **Description**: `Administrators have complete and unrestricted access to the computer/domain`

> [!CAUTION]
> My preferred approach is to check both `Delete all members` and `Delete all member groups`. This ensures the group is fully reset on every policy refresh and only includes the accounts and groups you explicitly define — removing any unauthorized local admin access.

* ✅ `Delete all members`
* ✅ `Delete all member groups`

Example:
| Members          |
| ---------------- |
| AD\Domain Admins |
| AD\admin.client  |
| admin.laps       |

> [!IMPORTANT]
> This is just an example configuration showing how `admin.laps` can be added to the local Administrators group. Always review and tailor group membership entries to fit your organization's needs.

> [!NOTE]
> If you change the `$userName` variable in the script, make sure to reflect that in this policy.

---

## 🧮 Dynamic Group for Cloud-native devices (Entra joined)

Use this rule to create a dynamic group that targets only cloud-native (Entra joined) Windows devices:
```kusto
(device.deviceTrustType -eq "AzureAD") and (device.deviceOSType -eq "Windows")
```

---

## 🔒 Intune Policy: Add to Administrators Group (Cloud-native devices)

In the [Intune Admin Center](https://intune.microsoft.com):
Navigate to `Endpoint security` → `Account protection` → `Create Policy`

* **Platform**: `Windows`
* **Profile**: `Local user group membership`

| Local Group    | Group and user action | User selection type | Selected user(s) |
| -------------- | --------------------- | ------------------- | ---------------- |
| Administrators | Add (Update)          | Manual              | admin.laps       |

> [!NOTE]
> If you change the `$userName` variable in the script, make sure to reflect that in this policy.

---

## 📄 Example Log Output

### ✅ User Does Not Exist

```
2025-05-29 14:00:00 [  Start   ] ======== Platform Script Started ========
2025-05-29 14:00:00 [  Info    ] ComputerName: WS-81F690CC7DE6 | User: WS-81F690CC7DE6$ | Script: Create - admin.laps
2025-05-29 14:00:00 [  Check   ] Checking if user admin.laps exists...
2025-05-29 14:00:00 [  Info    ] User admin.laps does not exist.
2025-05-29 14:00:00 [  Success ] Generated secure random password.
2025-05-29 14:00:01 [  Info    ] Attempting to create local user admin.laps...
2025-05-29 14:00:01 [  Success ] User admin.laps created successfully.
2025-05-29 14:00:01 [  Success ] User admin.laps successfully verified after creation.
2025-05-29 14:00:01 [  Info    ] Script execution time: 00:00:01.00
2025-05-29 14:00:01 [  Info    ] Exit Code: 0
2025-05-29 14:00:01 [  End     ] ======== Platform Script Completed ========
```

### ⚠️ User Already Exists

```
2025-05-04 08:46:06 [  Start   ] ======== Platform Script Started ========
2025-05-04 08:46:06 [  Info    ] ComputerName: WS-81F690CC7DE6 | User: WS-81F690CC7DE6$ | Script: Create - admin.laps
2025-05-04 08:46:06 [  Check   ] Checking if user admin.laps exists...
2025-05-04 08:46:06 [  Success ] User admin.laps exists.
2025-05-04 08:46:06 [  Info    ] No action needed. Exiting script.
2025-05-04 08:46:06 [  Info    ] Script execution time: 00:00:00.01
2025-05-04 08:46:06 [  Info    ] Exit Code: 0
2025-05-04 08:46:06 [  End     ] ======== Platform Script Completed ========
```

---

> [!TIP]
> The **📄 Log file** for this script is saved at:
> `C:\ProgramData\IntuneLogs\Scripts\`
>
> ```
> C:  
> ├─📁 ProgramData
> │  └─📁 IntuneLogs
> │     └─📁 Scripts
> │        └──📄 Create - admin.laps.log
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

| Setting                         | Value |
| ------------------------------- | ----- |
| Run using logged-on credentials | No    |
| Enforce script signature check  | No    |
| Run script in 64-bit PowerShell | Yes   |

---
