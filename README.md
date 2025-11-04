FOGPatcher - Alexandre BOTZUNG (MRSH) Jan2025
---------------------------------------------

FOGPatcher patches the "Zazzles.dll" file located in the FOG client to allow the execution of a PowerShell script just before a system restart/shutdown.

During a restart or a shutdown initiated by the server, the FOG service will execute the "prereboot.ps1" script for a restart or "preshutdown.ps1" for a system shutdown. (located in the service folder)

The file responsible for this execution is syreboot.dll. This file interrupts the "just-in-time" restart/shutdown and executes the necessary script.

This DLL was compiled by me using PureBasic. The source code is located at the end of FOGPatcher.

FOGPatcher can be easily deployed via Group Policy Objects (GPO);
 - Simply create a Group Policy Object (GPO) like this: Computer Configuration -> Policies -> Windows Settings -> Scripts (Startup)    
  (If FOGPatcher detects that it's already installed, it won't do anything)    
  ... or run it manually as an administrator.    

By default, FOGPatcher includes the "prereboot.ps1" file, which is a script that controls the pre-reboot of the computer. This command:

- Checks on the FOG server if a capture/deployment task is scheduled
- If a task is scheduled
- -> Attempts to schedule a network reboot via PXE (temporarily)
- -> Removes the computer from the domain and adds it to the "WORKGROUP" workgroup
- -> Runs the .ps1 scripts located in the folder C:\Program Files (x86)\FOG\prereboot
- -> Notifies the operator and restarts the computer after confirmation (or after 30 minutes).

- If no task is scheduled, it notifies the operator and restarts the computer after confirmation (or after 30 seconds).

### Execution of .ps1 scripts by prereboot.ps1

If a task is scheduled, prereboot.ps1 will execute the scripts located in this folder, in alphabetical order:

`C:\Program Files (x86)\FOG\prereboot`

By default, this folder does not exist; it is up to the system administrator to create it.
Scripts are executed in alphabetical order. You can sort them by adding a number to the beginning of the filename (For example: 01_Cleaning_bleachbit.ps1 or 99_cleaning_winupdate.ps1).
Searching for scripts in this folder is limited to this folder only; prereboot.ps1 will not search any subfolders within the 'prereboot' folder.

### Temporary Network Reboot via prereboot.ps1

If a task is scheduled, prereboot.ps1 will attempt to schedule the next boot on the first network adapter found.

This mode only works if the system uses UEFI as its boot method.

Also, since network interface names are not standardized, it is possible that prereboot.ps1 may not find a network adapter.

This information is available in the log file located at `C:\Windows\Logs\FOG_prereboot.log`.
Please contact me if prereboot.ps1 does not correctly restart your computer via PXE. Here are the text strings that prereboot.ps1 uses to locate the network adapter:

- *nic*
- *ip4*
- *ether*
- *pxe*
- *ipv4*
- *gbe*
- *family*
- *pci lan*
- *netw*

### Event Logs
By default, prereboot.ps1 creates a log in `C:\Windows\Logs\FOG_prereboot.log`.

FOGPatcher (syreboot.dll) creates an "application" event (in the Event Viewer) during a restart or shutdown. The FOGPatcher ID is 500.

### Miscellaneous
The FOGPatcher script checks if:

- The file `C:\Program Files (x86)\FOG\Zazzles.dll` is correctly patched.
- The file `C:\Program Files (x86)\FOG\prereboot.ps1` exists AND has the same MD5 signature as the one present in FOGPatcher.
- The file `C:\Program Files (x86)\FOG\syreboot.dll` exists AND has the same MD5 signature as the one present in FOGPatcher.

If any of these five conditions are not met, FOGPatcher performs a standard installation.
Warning: FOGPatcher will overwrite your prereboot.ps1 file if you have modified it. You must modify the signature and the file present in FOGPatcher to counter this issue.

NOTE: FOGPatcher modifies the Zazzles.dll file. As a side effect, its Authenticode signature will be invalidated.
