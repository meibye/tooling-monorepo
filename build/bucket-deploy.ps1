<#
.SYNOPSIS
Automatically updates tools by syncing deployed versions with manifest files.

.DESCRIPTION
[bucket-deploy.ps1] Scans a bucket directory for JSON manifest files describing tool versions and artifacts.
For each tool, it checks the currently deployed version in the apps directory. If the deployed version
differs from the manifest version, it extracts the new artifact, updates the directory structure, and
manages symlinks to point to the latest version. The script supports fallback between drive letters
(e.g., D: to C:) for flexibility across environments.
If Scoop is available and the app is managed in Scoop, the script will prefer installing/updating into
the Scoop apps folder (and attempt a lightweight shim reset) instead of the monorepo apps location.

.PARAMETER Family
Optional. Tool type: ps, py, cmd, bash, zsh, plugin. Wildcard "*" for all.
.PARAMETER App
Optional. App folder name. Wildcard "*" for all.
.PARAMETER Tool
Optional. Name for the tool source file incl extension. Wildcard "*" for all.

.NOTES
- Expects manifest files in JSON format with at least 'version' and 'url' fields.
- Assumes artifacts are zip files accessible via file URLs.
- Requires appropriate permissions to create directories, extract archives, and manage symlinks.
- Designed for use in a monorepo tooling environment.

.EXAMPLE
.\bucket-deploy.ps1
Runs the script to update all tools according to their manifests.
.\bucket-deploy.ps1 -Family ps -App tools -Tool winutil.ps1
#>

param(
    [string]$Family = "*",
    [string]$App = "*",
    [string]$Tool = "*"
)

# --- argument validation ---
$allowed = @('Family','App','Tool')
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
    Write-Error "Invalid argument(s): $($invalid -join ', ')`nSupported arguments: -Family -App -Tool"
    exit 2
}

function Get-AltPath {
    param([string]$primary, [string]$alternate)
    if (Test-Path $primary) { return $primary }
    if (Test-Path $alternate) { return $alternate }
    return $primary
}

$repo   = Get-AltPath 'D:\Dev\tooling-monorepo' 'C:\Dev\tooling-monorepo'
$bucket = Get-AltPath 'D:\Dev\meibye-bucket\bucket' 'C:\Dev\meibye-bucket\bucket'
$toolsRoot = "$repo\tools"
$appsRoot = Get-AltPath 'C:\Tools\apps' 'D:\Tools\apps'

# Detect Scoop (prefer using Scoop-managed apps when present)
$scoopCmd = Get-Command scoop -ErrorAction SilentlyContinue
if ($scoopCmd -or $env:SCOOP) {
    $scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
    $scoopApps = Join-Path $scoopRoot 'apps'
} else {
    $scoopApps = $null
}

# Use dev-filter-tool.ps1 to get relevant tools from bucket manifests
$filterScript = Join-Path $PSScriptRoot 'dev-filter-tool.ps1'
$filteredTools = & $filterScript -Type bucket -Location $bucket -Family $Family -App $App -Tool $Tool

if (-not $filteredTools -or $filteredTools.Count -eq 0) {
    Write-Host "No matching tools found for deployment." -ForegroundColor Yellow
    exit 0
}

foreach ($toolObj in $filteredTools) {
    try {
        $app = $toolObj.App
        $toolName = $toolObj.Tool
        $fam = $toolObj.Family
        $manifestPath = $toolObj.Path
        $man = Get-Content $manifestPath -ErrorAction Stop | ConvertFrom-Json
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
                $dest = Join-Path "$appsRoot\$fam\$app" $ver
                $cur = Join-Path "$appsRoot\$fam\$app" 'current'
            }

            if (-not (Test-Path $dest)) {
                try {
                    New-Item -ItemType Directory -Force -Path $dest | Out-Null
                } catch {
                    Write-Host "Failed to create directory ${dest}: $_" -ForegroundColor Red
                    continue
                }
            }
            try {
                Expand-Archive -Path $zip -DestinationPath $dest -Force
            } catch {
                Write-Host "Failed to extract $zip to ${dest}: $_" -ForegroundColor Red
                continue
            }

            # Update symlink (either in scoop apps folder or in appsRoot)
            try {
                if (Test-Path $cur) { Remove-Item $cur -Force }
            } catch {
                Write-Host "Failed to remove existing symlink ${cur}: $_" -ForegroundColor Red
                continue
            }
            try {
                cmd /c mklink /D "$cur" "${dest}" | Out-Null
            } catch {
                Write-Host "Failed to create symlink ${cur}: $_" -ForegroundColor Red
                continue
            }

            # If Scoop is present, attempt to refresh shims for this app (best-effort)
            if ($useScoop -and $scoopCmd) {
                try {
                    cmd /c scoop reset $app > $null 2>&1
                } catch {
                    Write-Host "scoop reset $app failed or is unavailable (non-fatal)" -ForegroundColor DarkYellow
                }
            }

            Write-Host "Installed $app $ver" -ForegroundColor Green
        }
    } catch {
        Write-Host "Error processing $($toolObj.Path): $_" -ForegroundColor Red
    }
}

# Suggestion for dev-filter-tool.ps1:
# If you want to deploy only the latest version or filter by manifest version, consider adding a -Version parameter to dev-filter-tool.ps1.
# If you want to deploy only tools with a specific bin name, ensure bin filtering works for all manifest structures.