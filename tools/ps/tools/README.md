# ctt-windows-utility (winutil) – PowerShell Tool

## Overview

**ctt-windows-utility** (winutil) is a PowerShell-based Windows utility installer and configuration tool, created by Chris Titus Tech.  
It provides a simple, interactive way to install popular software, tweak system settings, and optimize Windows for development, gaming, or general use.

---

## Scripts in This Folder

This folder contains the following scripts:

- **winutil.ps1**  
  Installs or updates Windows utilities using Chris Titus Tech's script.  
  Downloads and executes the Windows utility setup script from https://christitus.com/win.  
  Must be run in PowerShell Core (`pwsh`).

- **dev-unblock-script.ps1**  
  Unblocks a specified file to allow script execution (removes the "blocked" status/Zone.Identifier).

- **dev-print-path.ps1**  
  Prints each entry in the current `PATH` environment variable, one per line.

---

## Scripts in the `src` Folder

This folder contains the following scripts:

- **winutil.ps1**  
  Installs or updates Windows utilities using Chris Titus Tech's script.  
  Downloads and executes the Windows utility setup script from https://christitus.com/win.  
  Must be run in PowerShell Core (`pwsh`).  
  Usage:  
  ```powershell
  pwsh -NoProfile -File winutil.ps1
  ```

- **dev-unblock-script.ps1**  
  Unblocks a specified file to allow script execution (removes the "blocked" status/Zone.Identifier).  
  Usage:  
  ```powershell
  pwsh -NoProfile -File dev-unblock-script.ps1 -Path 'C:\path\to\file.ps1'
  ```

- **dev-print-path.ps1**  
  Prints each entry in the current `PATH` environment variable, one per line.  
  Usage:  
  ```powershell
  pwsh -NoProfile -File dev-print-path.ps1
  ```

---

## Features

- Install and update common Windows applications and tools
- Apply recommended system tweaks and optimizations
- Remove unwanted bloatware and telemetry
- Configure privacy, security, and performance settings
- Easy-to-use interactive menu

## Usage

Run the following PowerShell command (requires PowerShell Core / `pwsh`):

```powershell
iwr -useb https://christitus.com/win | iex
```

Or use the provided script:

```powershell
winutil.ps1
```

## Requirements

- Windows 10/11
- PowerShell Core (`pwsh`)

## More Information

- [WinUtil Project Page](https://winutil.christitus.com/dev/)
- [Chris Titus Tech](https://christitus.com/win)
* monitor_ai (ps tool)
