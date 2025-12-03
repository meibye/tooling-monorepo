# dev-zip-excl.ps1
# Zips a directory (excluding dotfiles) to a specified destination zip file.
# Usage:
#   .\dev-zip-excl.ps1 -SourceDir "C:\path\to\dir" -DestinationZip "C:\path\to\archive.zip"

param(
    [string]$SourceDir,
    [string]$DestinationZip
)

if (-not $SourceDir -or -not $DestinationZip) {
    Write-Host "Usage: .\dev-zip-excl.ps1 -SourceDir <dir> -DestinationZip <zipfile>"
    exit 1
}

if (Test-Path $DestinationZip) {
    $response = Read-Host "Destination zip file '$DestinationZip' already exists. Overwrite? (y/n)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Aborted by user."
        exit 1
    }
    Remove-Item $DestinationZip -Force
}

powershell -Command "Get-ChildItem -Path '$SourceDir' -Recurse -Exclude '.*' | Compress-Archive -DestinationPath '$DestinationZip' -Force"