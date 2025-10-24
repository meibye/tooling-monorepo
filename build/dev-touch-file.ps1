<#
.SYNOPSIS
    Updates the modification date and time of a file to now.
.DESCRIPTION
    Sets the LastWriteTime property of the specified file to the current date and time.
.PARAMETER Path
    The path to the file to update.
.EXAMPLE
    .\dev-touch-file.ps1 -Path "C:\path\to\yourfile.txt"
#>
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Path
)

if (-not (Test-Path $Path -PathType Leaf)) {
    Write-Error "File not found: $Path"
    exit 1
}

Set-ItemProperty -Path $Path -Name LastWriteTime -Value (Get-Date)
Write-Host "Updated LastWriteTime for $Path to $(Get-Date)" -ForegroundColor Cyan
