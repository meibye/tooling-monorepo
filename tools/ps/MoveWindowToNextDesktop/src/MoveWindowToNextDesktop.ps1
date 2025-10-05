# Import the module (automatically loads if installed)
Import-Module VirtualDesktop

# P/Invoke to get the foreground (active) window handle
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
}
"@

# Get the active window handle
$hwnd = [Win32]::GetForegroundWindow()

# Get the current desktop
$currentDesktop = Get-CurrentDesktop

# Get the next desktop to the right (or create a new one if none exists)
$nextDesktop = Get-RightDesktop -Desktop $currentDesktop
if ($nextDesktop -eq $null) {
    $nextDesktop = New-Desktop  # Creates a new desktop if at the end
}

# Move the window to the next desktop (without switching to it)
Move-Window -Desktop $nextDesktop -Hwnd $hwnd

# Optional: If you want to move to a specific desktop (e.g., Desktop 2, indexed from 0)
# $targetDesktop = Get-Desktop -Index 1
# Move-Window -Desktop $targetDesktop -Hwnd $hwnd