<#
.SYNOPSIS
    Displays the version of a specified tool as defined in the bucket manifest and the currently deployed version.
.DESCRIPTION
    This script checks the version of a given tool/app by reading its manifest from a local bucket directory and compares it to the version currently deployed in the apps directory.
.PARAMETER App
    The name of the tool/app to check (without file extension).
.EXAMPLE
    .\check-tool-version.ps1 -App my-ps-tool
    Shows the version in the bucket and the deployed version for 'my-ps-tool'.
#>
param(
    [Parameter(Mandatory)]
    [string]$App
)

try {
    # Check bucket path
    $bucket = 'D:\Dev\meibye-bucket\bucket'
    if (-not (Test-Path $bucket)) {
        $bucket = 'C:\Dev\meibye-bucket\bucket'
    }
    if (-not (Test-Path $bucket)) {
        Write-Error "Bucket path not found: D:\Dev\meibye-bucket\bucket or C:\Dev\meibye-bucket\bucket"
        exit 1
    }

    $manifest = "$bucket\$App.json"
    if (-not (Test-Path $manifest)) {
        Write-Error "No manifest for $App at $manifest"
        exit 1
    }

    try {
        $man = Get-Content $manifest -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Error "Failed to read or parse manifest: $_"
        exit 1
    }

    Write-Host "$App version in bucket: $($man.version)" -ForegroundColor Yellow

    # Check deployed path
    $appsRoot = 'C:\Tools\apps'
    if (-not (Test-Path $appsRoot)) {
        $appsRoot = 'D:\Tools\apps'
    }
    if (-not (Test-Path $appsRoot)) {
        Write-Error "Apps root path not found: C:\Tools\apps or D:\Tools\apps"
        exit 1
    }

    $deployed = Get-ChildItem "$appsRoot\*\$App\current" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($deployed) {
        try {
            $ver = Split-Path ($deployed.Target) -Leaf
            Write-Host "$App deployed version: $ver" -ForegroundColor Green
        } catch {
            Write-Error "Failed to determine deployed version: $_"
        }
    } else {
        Write-Warning "$App is not currently deployed."
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}