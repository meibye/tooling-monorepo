<#
.SYNOPSIS
    Unblocks a specified file to allow script execution.

.DESCRIPTION
    [dev-unblock-script.ps1] Takes a file path as a parameter, verifies the file exists, and removes the "blocked" status (Zone.Identifier) from the file using Unblock-File. This is useful for enabling execution of scripts downloaded from the internet.

.PARAMETER Path
    The path to the file to unblock.

.EXAMPLE
    .\dev-unblock-script.ps1 -Path 'C:\path\to\file.ps1'
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Path
)

# --- argument validation ---
$allowed = @('Path')
$invalid = @()
if ($PSBoundParameters) {
    $invalid += $PSBoundParameters.Keys | Where-Object { $allowed -notcontains $_ }
}
if ($args) {
    foreach ($token in $args) {
        if ($token -is [string] -and $token -match '^-{1,2}([^:=]+)') {
            $paramName = $matches[1]
            if ($allowed -notcontains $paramName) {
                $invalid += $paramName
            }
        }
    }
}
$invalid = $invalid | Select-Object -Unique
if ($invalid.Count -gt 0) {
    Write-Error "Invalid argument(s): $($invalid -join ', ')`nSupported arguments: -Path"
    exit 2
}

if (-not (Test-Path $Path -PathType Leaf)) {
    Write-Error "File not found: $Path"
    exit 1
}

Unblock-File -Path $Path