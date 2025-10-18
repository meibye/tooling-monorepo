<#
.SYNOPSIS
    Builds and publishes all tools and plugins from tooling-monorepo to the local bucket.
.DESCRIPTION
    [bucket-publish.ps1] For each tool and plugin, compresses the contents of its src folder into a zip archive, computes a SHA256 hash, and generates or updates a manifest JSON file in the bucket directory.
    The manifest includes version, description, license, URL to the zip, hash, and a list of executable files found in the src folder.
    Supports incremental publishing: if -OnlyChanged is specified, only tools and plugins with changes since the last published version are processed (based on file modification times).
    Handles tools in the tools directory (for families: ps, py, cmd, bash, zsh) and plugins in plugins\onemore.
    Optionally, when -CommitAndSync is provided, the script will attempt to git add/commit/pull/push the created or updated manifest in the bucket repository (best-effort).
.PARAMETER Version
    Optional. The version string to use for published artifacts. Defaults to "0.1.0".
.PARAMETER OnlyChanged
    Optional. If specified, only tools and plugins with changes since the last published version are built and published.
.PARAMETER CommitAndSync
    Optional. If specified, after writing each manifest the script will attempt to git add/commit/pull/push the manifest file in the bucket directory.
.EXAMPLE
    .\bucket-publish.ps1 -Version 1.1.0
    .\bucket-publish.ps1 -OnlyChanged -CommitAndSync
#>

param(
    [string]$Version,
    [switch]$OnlyChanged,
    [switch]$CommitAndSync
)

# --- argument validation ---
$allowed = @('Version','OnlyChanged','CommitAndSync')
$allowed = @($allowed)                # normalize allow-list to an array

# Collect invalid parameter names from bound parameters and raw args (handles typos like -Veriosn)
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
    Write-Error "Invalid argument(s): $($invalid -join ', ')`nSupported arguments: -Version -OnlyChanged -CommitAndSync"
    exit 2
}

$repo = 'D:\Dev\tooling-monorepo'
$bucket = 'D:\Dev\meibye-bucket\bucket'

if (-not (Test-Path $repo)) {
    $repo = 'C:\Dev\tooling-monorepo'
}
if (-not (Test-Path $bucket)) {
    $bucket = 'C:\Dev\meibye-bucket\bucket'
}
$outdir = "$repo\out\artifacts"

function Get-LatestVersion {
    param($name)
    $versions = @()
    if (Test-Path $outdir) {
        $versions += Get-ChildItem -Path $outdir -Filter "$name-*.zip" | ForEach-Object {
            if ($_.Name -match "$name-(.+)\.zip") { $matches[1] }
        }
    }
    if (Test-Path "$bucket\$name.json") {
        try {
            $manifest = Get-Content "$bucket\$name.json" | ConvertFrom-Json
            if ($manifest.version) { $versions += $manifest.version }
        } catch {}
    }
    $versions = $versions | Where-Object { $_ } | Sort-Object -Descending
    if ($versions.Count -gt 0) { return $versions[0] }
    return "0.1.0"
}

# New helper: optionally git add/commit/pull/push the manifest in the bucket repo
function Maybe-CommitAndSyncManifest {
    param(
        [string]$ManifestPath,
        [string]$Name,
        [string]$Version
    )
    if (-not $CommitAndSync) { return }
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        Write-Warning "git not found on PATH; skipping commit/sync for $Name"
        return
    }
    try {
        Push-Location $bucket
        # Use relative path when adding
        $relPath = Split-Path $ManifestPath -Leaf
        & git add $relPath 2>$null
        $porcelain = (& git status --porcelain) -join "`n"
        if ($porcelain) {
            & git commit -m "Publish $Name version $Version" --no-verify 2>$null
            try { & git pull --rebase --autostash 2>$null } catch {}
            try { & git push 2>$null } catch {}
            Write-Host "Committed and pushed manifest for $Name" -ForegroundColor Cyan
        } else {
            Write-Host "No git changes to commit for $Name" -ForegroundColor DarkGray
        }
    } catch {
        Write-Warning "Git commit/sync failed for ${Name}: $_"
    } finally {
        Pop-Location
    }
}

# Determine effective version
$families = @('ps','py','cmd','bash','zsh')
foreach ($fam in $families) {
    $famdir = "$repo\tools\$fam"
    if (-not (Test-Path $famdir)) { continue }
    Get-ChildItem -Path $famdir -Directory | ForEach-Object {
        $app = $_.Name
        $src = "$($_.FullName)\src"
        if (-not (Test-Path $src)) { return }

        # Version selection logic
        $effectiveVersion = $null
        if ($OnlyChanged) {
            if ($Version) {
                $effectiveVersion = $Version
            } else {
                $effectiveVersion = Get-LatestVersion $app
            }
        } else {
            if ($Version) {
                $effectiveVersion = $Version
            } else {
                $effectiveVersion = "0.1.0"
            }
        }

        $zip = "$outdir\$app-$effectiveVersion.zip"
        try {
            if ($OnlyChanged -and (Test-Path $zip) -and ((Get-ChildItem $src -Recurse | Measure-Object -Property LastWriteTime -Maximum).Maximum -lt (Get-Item $zip).LastWriteTime)) {
                Write-Warning "Skipping $app (no changes)"
                return
            }
            if (-not (Test-Path $outdir)) { New-Item -ItemType Directory -Force -Path $outdir | Out-Null }
            if (Test-Path $zip) { Remove-Item $zip -Force }
            Compress-Archive -Path "$src\*" -DestinationPath $zip -ErrorAction Stop
            $sha = (Get-FileHash $zip -Algorithm SHA256 -ErrorAction Stop).Hash

            # Find all executables in src
            $bins = Get-ChildItem $src -File -Recurse | Where-Object { $_.Extension -match '\.(ps1|py|cmd|bat|sh|zsh)$' } | ForEach-Object { $_.Name }

            # Write manifest
            $manifest = @{
                version = $effectiveVersion
                description = "$app ($fam tool)"
                homepage = ""
                license = "MIT"
                url = "file:///$zip"
                hash = "sha256:$sha"
                bin = $bins
            }
            $manifestPath = "$bucket\$app.json"
            $manifest | ConvertTo-Json -Depth 8 | Set-Content -Path $manifestPath -Encoding UTF8 -ErrorAction Stop
            Write-Host "Published $app ($fam) version $effectiveVersion" -ForegroundColor Green

            # Optionally commit and sync the manifest
            Maybe-CommitAndSyncManifest -ManifestPath $manifestPath -Name $app -Version $effectiveVersion
        } catch {
            Write-Error "Failed to process $app ($fam): $_"
        }
    }
}

# Handle plugins in plugins\onemore
$pluginDir = "$repo\plugins\onemore"
if (Test-Path $pluginDir) {
    Get-ChildItem -Path $pluginDir -Directory | ForEach-Object {
        $plugin = $_.Name
        $src = "$($_.FullName)\src"
        if (-not (Test-Path $src)) { return }

        # Version selection logic for plugins
        $effectiveVersion = $null
        if ($OnlyChanged) {
            if ($Version) {
                $effectiveVersion = $Version
            } else {
                $effectiveVersion = Get-LatestVersion $plugin
            }
        } else {
            if ($Version) {
                $effectiveVersion = $Version
            } else {
                $effectiveVersion = "0.1.0"
            }
        }

        $zip = "$outdir\$plugin-$effectiveVersion.zip"
        try {
            if ($OnlyChanged -and (Test-Path $zip) -and ((Get-ChildItem $src -Recurse | Measure-Object -Property LastWriteTime -Maximum).Maximum -lt (Get-Item $zip).LastWriteTime)) {
                Write-Warning "Skipping plugin $plugin (no changes)"
                return
            }
            if (-not (Test-Path $outdir)) { New-Item -ItemType Directory -Force -Path $outdir | Out-Null }
            if (Test-Path $zip) { Remove-Item $zip -Force }
            Compress-Archive -Path "$src\*" -DestinationPath $zip -ErrorAction Stop
            $sha = (Get-FileHash $zip -Algorithm SHA256 -ErrorAction Stop).Hash

            # Find all executables in src
            $bins = Get-ChildItem $src -File -Recurse | Where-Object { $_.Extension -match '\.(ps1|py|cmd|bat|sh|zsh)$' } | ForEach-Object { $_.Name }
            
            # Write manifest
            $manifest = @{
                version = $effectiveVersion
                description = "$plugin (onemore plugin)"
                homepage = ""
                license = "MIT"
                url = "file:///$zip"
                hash = "sha256:$sha"
                bin = $bins
            }
            $manifestPath = "$bucket\$plugin.json"
            $manifest | ConvertTo-Json -Depth 8 | Set-Content -Path $manifestPath -Encoding UTF8 -ErrorAction Stop
            Write-Host "Published plugin $plugin (onemore) version $effectiveVersion" -ForegroundColor Green

            # Optionally commit and sync the manifest
            Maybe-CommitAndSyncManifest -ManifestPath $manifestPath -Name $plugin -Version $effectiveVersion
        } catch {
            Write-Error "Failed to process plugin $plugin (onemore): $_"
        }
    }
}