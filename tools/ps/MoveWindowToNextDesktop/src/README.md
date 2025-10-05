# PowerShell-Based Solution for Moving a Window to Another Virtual Desktop

In Windows 11, you can use PowerShell with the community [VirtualDesktop](https://www.powershellgallery.com/packages/VirtualDesktop) module to create a script that moves the active window to another virtual desktop (e.g., the next one to the right) **without showing Task View or automatically switching desktops**. This keeps the process keyboard-driven and background-only. The module provides cmdlets for desktop management, and we'll combine it with a P/Invoke call to get the active window handle.

---

## Step 1: Install the VirtualDesktop Module

Open PowerShell as an administrator and run:

```powershell
Install-Module VirtualDesktop
```

- This installs from the PowerShell Gallery (latest version as of September 2025 is 1.5.7).
- If you prefer user-scope (no admin needed):

  ```powershell
  Install-Module VirtualDesktop -Scope CurrentUser
  ```

- The module works on Windows 11 and handles virtual desktops natively via the Desktop Window Manager (DWM).

---

## Step 2: Create the PowerShell Script

Create a new file named `MoveWindowToNextDesktop.ps1` (or similar) in a convenient location (e.g., `C:\Scripts\`). Paste the following script:

> See the `*.ps1` file

### How it works

- `GetForegroundWindow()` retrieves the handle of the currently active window.
- `Get-CurrentDesktop` gets the current virtual desktop object.
- `Get-RightDesktop` finds the adjacent desktop to the right (next one).
- If no right desktop exists (you're on the last one), `New-Desktop` creates a new one.
- `Move-Window` relocates the window to the target desktop **without switching or showing anything**.

### Customization

- **To move to the left:** Replace `Get-RightDesktop` with `Get-LeftDesktop`.
- **To move to a specific desktop:** Use `Get-Desktop -Index <number>` (indexes start at 0).
- **To cycle/wrap around:** Add logic like:

  ```powershell
  $index = (Get-DesktopIndex $currentDesktop + 1) % (Get-DesktopCount)
  $nextDesktop = Get-Desktop -Index $index
  ```

### Testing

Run the script manually:

```powershell
powershell.exe -File C:\Scripts\MoveWindowToNextDesktop.ps1
```

while focusing an app window. It should move silently.

---

## Step 3: Create a Keyboard Shortcut with PowerToys

PowerToys' Keyboard Manager can remap a key combination to run the script, turning it into a true hotkey.

1. Download and install [PowerToys](https://github.com/microsoft/PowerToys) from the Microsoft Store or GitHub (free, official).
2. Open PowerToys Settings > Keyboard Manager > Remap a shortcut.
3. Click "+" to add a new shortcut:
    - **From (your hotkey):** e.g., Win + Ctrl + Shift + Right Arrow (or any unused combo).
    - **To:** Select "Run program" from the dropdown.
        - **Program:** `powershell.exe`
        - **Arguments:**  
          ```
          -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Scripts\MoveWindowToNextDesktop.ps1"
          ```
          (adjust the path; `-WindowStyle Hidden` prevents a console flash).

4. Enable the remap and test: Focus a window, press your hotkey—the window moves without visuals.

---

## Notes and Troubleshooting

- **No switching/showing desktops:** The script avoids `Switch-Desktop`, so you stay on your current desktop. The move happens in the background.
- **Limitations:** Works for most windows, but some system-protected ones (e.g., UAC prompts) may not move. If the script fails, check PowerShell errors with `-NoExit` in arguments.
- **Performance:** Runs in <100ms; no noticeable delay.
- **Alternatives if needed:** For more features (e.g., naming desktops), explore `Set-DesktopName` or other cmdlets. If you want to avoid the module, a pure P/Invoke script exists but is more complex (involves COM interfaces for `IVirtualDesktopManager`).