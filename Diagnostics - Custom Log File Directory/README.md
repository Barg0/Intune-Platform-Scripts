This script sets a registry value so that when you collect logs via the Intune Admin Center, the custom folder:

C:\ProgramData\IntuneLogs

will be crawled, and its logs will be included in the output.

The logs from the custom folder will be part of the .cab file located in:

FoldersFiles temp_MDMDiagnostics_mdmlogs

Type:                                               Platform Script
Run this script using the logged on credentials:    No
Enforce script signature check:                     No
Run script in 64 bit PowerShell Host:               Yes