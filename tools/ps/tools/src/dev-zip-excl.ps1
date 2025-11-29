# dev-zip-excl.ps1
# Zips a directory (excluding dotfiles) to a specified destination zip file.
# Usage:
#   .\dev-zip-excl.ps1 -SourceDir "C:\path\to\dir" -DestinationZip "C:\path\to\archive.zip"

param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir,
    [Parameter(Mandatory = $true)]
    [string]$DestinationZip
)

if (-not $SourceDir -or -not $DestinationZip) {
    Write-Host "Usage: .\dev-zip-excl.ps1 -SourceDir <dir> -DestinationZip <zipfile>"
    exit 1
}

powershell -Command "Get-ChildItem -Path '$SourceDir' -Recurse -Exclude '.*' | Compress-Archive -DestinationPath '$DestinationZip'"