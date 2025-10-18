<#
.SYNOPSIS
    Installs or updates Windows utilities using Chris Titus Tech's script.
.DESCRIPTION
    Downloads and executes the Windows utility setup script from https://christitus.com/win.
    Must be run in PowerShell Core (pwsh).
#>

if ($PSVersionTable.PSEdition -ne 'Core') {
    Write-Host "Restarting in pwsh..."
    $cmd = 'iwr -useb https://christitus.com/win | iex'
    pwsh -NoProfile -Command $cmd
    exit $LASTEXITCODE
}

try {
    iwr -useb https://christitus.com/win | iex
} catch {
    Write-Error "Failed to run Chris Titus Tech Windows utility script: $_"
    exit 1
}