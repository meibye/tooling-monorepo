<#
.SYNOPSIS
    Automatically updates tools by syncing deployed versions with manifest files.

.DESCRIPTION
    This script scans a bucket directory for JSON manifest files describing tool versions and artifacts.
    For each tool, it checks the currently deployed version in the apps directory. If the deployed version
    differs from the manifest version, it extracts the new artifact, updates the directory structure, and
    manages symlinks to point to the latest version. The script supports fallback between drive letters
    (e.g., D: to C:) for flexibility across environments.

.PARAMETER Path
    The path to check for existence, with fallback to C: drive if not found.

.NOTES
    - Expects manifest files in JSON format with at least 'version' and 'url' fields.
    - Assumes artifacts are zip files accessible via file URLs.
    - Requires appropriate permissions to create directories, extract archives, and manage symlinks.
    - Designed for use in a monorepo tooling environment.

.EXAMPLE
    .\auto-update-tools.ps1
    Runs the script to update all tools according to their manifests.
#>
function Test-OrCDrive {
    param([string]$Path)
    if (Test-Path $Path) { return $Path }
    $cPath = $Path -replace '^[A-Za-z]:', 'C:'
    if (Test-Path $cPath) { return $cPath }
    return $Path # fallback to original
}

$bucket = Test-OrCDrive 'D:\Dev\meibye-bucket\bucket'
$toolsRoot = Test-OrCDrive 'D:\Dev\tooling-monorepo\tools'
$appsRoot = Test-OrCDrive 'C:\Tools\apps'

Get-ChildItem "$bucket\*.json" -ErrorAction Stop | ForEach-Object {
    try {
        $man = Get-Content $_.FullName -ErrorAction Stop | ConvertFrom-Json
        $app = $_.BaseName
        $ver = $man.version

        # Check deployed version
        $deployed = Get-ChildItem "$appsRoot\*\$app\current" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        $curver = if ($deployed) { Split-Path ($deployed.Target) -Leaf } else { "" }
        if ($curver -ne $ver) {
            Write-Host "Updating $app from $curver to $ver" -ForegroundColor Yellow

            # Simulate install: unzip artifact to C:\Tools\apps\<family>\<app>\<ver>
            $zip = $man.url -replace '^file:///',''
            $fam = (Get-ChildItem "$toolsRoot\*" -ErrorAction Stop | Where-Object { Test-Path "$($_.FullName)\$app" }).Name
            $dest = "$appsRoot\$fam\$app\$ver"
            if (-not (Test-Path $dest)) {
                try {
                    New-Item -ItemType Directory -Force -Path $dest | Out-Null
                } catch {
                    Write-Host "Failed to create directory ${dest}: $_" -ForegroundColor Red
                    return
                }
            }
            try {
                Expand-Archive -Path $zip -DestinationPath $dest -Force
            } catch {
                Write-Host "Failed to extract $zip to ${dest}: $_" -ForegroundColor Red
                return
            }

            # Update symlink
            $cur = "$appsRoot\$fam\$app\current"
            try {
                if (Test-Path $cur) { Remove-Item $cur -Force }
            } catch {
                Write-Host "Failed to remove existing symlink ${cur}: $_" -ForegroundColor Red
                return
            }
            try {
                cmd /c mklink /D "$cur" "${dest}" | Out-Null
            } catch {
                Write-Host "Failed to create symlink ${cur}: $_" -ForegroundColor Red
                return
            }
            Write-Host "Installed $app $ver" -ForegroundColor Green
        }
    } catch {
        Write-Host "Error processing $($_.FullName): $_" -ForegroundColor Red
    }
}