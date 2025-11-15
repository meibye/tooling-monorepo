<#
ps-2-exe.ps1

Converts a PowerShell script (.ps1) to a Windows executable (.exe) using ps2exe.

Usage:
    .\ps-2-exe.ps1 <ScriptPath> [ExeName]

- ScriptPath: Path to the PowerShell script to convert (required).
- ExeName: Output .exe file name (optional, defaults to script name with .exe extension).
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ScriptPath,
    [string]$ExeName
)

if (-not $ExeName) {
    $ExeName = [System.IO.Path]::ChangeExtension((Split-Path $ScriptPath -Leaf), ".exe")
}

Install-Module ps2exe -Force -Scope CurrentUser

Invoke-ps2exe $ScriptPath $ExeName -noConsole
