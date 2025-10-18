<#
.SYNOPSIS
    Automatically updates tools by syncing deployed versions with manifest files.

.DESCRIPTION
    [bucket-auto-update.ps1] Scans a bucket directory for JSON manifest files describing tool versions and artifacts.
    For each tool, it checks the currently deployed version in the apps directory. If the deployed version
    differs from the manifest version, it extracts the new artifact, updates the directory structure, and
    manages symlinks to point to the latest version. The script supports fallback between drive letters
    (e.g., D: to C:) for flexibility across environments.
    If Scoop is available and the app is managed in Scoop, the script will prefer installing/updating into
    the Scoop apps folder (and attempt a lightweight shim reset) instead of the monorepo apps location.

.PARAMETER Path
    The path to check for existence, with fallback to C: drive if not found.

.NOTES
    - Expects manifest files in JSON format with at least 'version' and 'url' fields.
    - Assumes artifacts are zip files accessible via file URLs.
    - Requires appropriate permissions to create directories, extract archives, and manage symlinks.
    - Designed for use in a monorepo tooling environment.

.EXAMPLE
    .\bucket-auto-update.ps1
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

# Detect Scoop (prefer using Scoop-managed apps when present)
$scoopCmd = Get-Command scoop -ErrorAction SilentlyContinue
if ($scoopCmd -or $env:SCOOP) {
    $scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
    $scoopApps = Join-Path $scoopRoot 'apps'
} else {
    $scoopApps = $null
}

Get-ChildItem "$bucket\*.json" -ErrorAction Stop | ForEach-Object {
    try {
        $man = Get-Content $_.FullName -ErrorAction Stop | ConvertFrom-Json
        $app = $_.BaseName
        $ver = $man.version

        # Determine currently deployed version (check Scoop location first, then appsRoot)
        $deployed = $null
        if ($scoopApps) {
            $scoopCurrent = Join-Path $scoopApps "$app\current"
            if (Test-Path $scoopCurrent) {
                try { $deployed = Get-Item $scoopCurrent -ErrorAction Stop } catch {}
            }
        }
        if (-not $deployed) {
            $deployed = Get-ChildItem "$appsRoot\*\$app\current" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        $curver = if ($deployed) { Split-Path ($deployed.Target) -Leaf } else { "" }

        # Decide whether to use Scoop-managed path
        $useScoop = $false
        if ($scoopApps -and (Test-Path (Join-Path $scoopApps $app))) { $useScoop = $true }

        if ($curver -ne $ver) {
            if ($useScoop) {
                Write-Host "Updating (scoop) $app from $curver to $ver" -ForegroundColor Yellow
            } else {
                Write-Host "Updating $app from $curver to $ver" -ForegroundColor Yellow
            }

            # Determine destination based on Scoop vs monorepo apps root
            $zip = $man.url -replace '^file:///',''
            if ($useScoop) {
                $dest = Join-Path $scoopApps "$app\$ver"
                $cur = Join-Path $scoopApps "$app\current"
            } else {
                $fam = (Get-ChildItem "$toolsRoot\*" -ErrorAction Stop | Where-Object { Test-Path "$($_.FullName)\$app" }).Name
                $dest = Join-Path "$appsRoot\$fam\$app" $ver
                $cur = Join-Path "$appsRoot\$fam\$app" 'current'
            }

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

            # Update symlink (either in scoop apps folder or in appsRoot)
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

            # If Scoop is present, attempt to refresh shims for this app (best-effort)
            if ($useScoop -and $scoopCmd) {
                try {
                    cmd /c scoop reset $app > $null 2>&1
                } catch {
                    # non-fatal; just log verbose
                    Write-Host "scoop reset $app failed or is unavailable (non-fatal)" -ForegroundColor DarkYellow
                }
            }

            Write-Host "Installed $app $ver" -ForegroundColor Green
        }
    } catch {
        Write-Host "Error processing $($_.FullName): $_" -ForegroundColor Red
    }
}