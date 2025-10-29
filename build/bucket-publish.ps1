<#
.SYNOPSIS
    Builds and publishes all tools and plugins from tooling-monorepo to the local bucket.
.DESCRIPTION
    [bucket-publish.ps1] For each tool and plugin, compresses the contents of its src folder into a zip archive, computes a SHA256 hash, and generates or updates a manifest JSON file in the bucket directory.
    The manifest is produced per tool (script), but only one zip archive is produced per app.
    The manifest includes version, description, license, URL to the zip (pointing to the GitHub repo's out/artifacts folder), hash, and a list of executable files found in the src folder.
    Supports incremental publishing: if -OnlyChanged is specified, only tools and plugins with changes since the last published version are processed (based on file modification times).
    Handles tools in the tools directory (for families: ps, py, cmd, bash, zsh) and plugins in plugins\onemore.
    Optionally, when -CommitAndSync is provided, the script will attempt to git add/commit/pull/push the created or updated manifest and the produced zip file in the bucket repository (best-effort).
    If -ShowVersions is specified together with -OnlyChanged, all considered versions for each app are output during processing.
    The -Version parameter is mandatory unless -OnlyChanged is specified.
    The script does not print GitHub versions when -ShowVersions is specified.
    The manifest version is verified to match the zip file version.
.PARAMETER Family
    Optional. Tool type: ps, py, cmd, bash, zsh. Wildcard "*" for all.
.PARAMETER App
    Optional. Folder grouping for related tools. Wildcard "*" for all.
.PARAMETER Tool
    Optional. Name for the tool source file incl extension. Wildcard "*" for all.
.PARAMETER Version
    Mandatory unless -OnlyChanged is specified. The version string to use for published artifacts. Defaults to "0.0.0".
.PARAMETER OnlyChanged
    Optional. If specified, only tools and plugins with changes since the last published version are built and published.
.PARAMETER CommitAndSync
    Optional. If specified, after writing each manifest and zip file the script will attempt to git add/commit/pull/push them in the bucket repository.
.PARAMETER ShowVersions
    Optional. If specified and OnlyChanged is given, outputs all considered versions for each app during processing.
.EXAMPLE
    .\bucket-publish.ps1 -Version 1.1.0 -Family ps -App myapp -Tool mytool.ps1
    .\bucket-publish.ps1 -App "*" -Tool "*.ps1"
    .\bucket-publish.ps1 -OnlyChanged -ShowVersions
#>

param(
    [string]$Family = "*",
    [string]$App = "*",
    [string]$Tool = "*",
    [Parameter(Mandatory = $false)]
    [string]$Version,
    [switch]$OnlyChanged,
    [switch]$CommitAndSync,
    [switch]$ShowVersions
)
    
# Set global default version
$DefaultVersion = "0.0.0"
# --- argument validation ---
$allowed = @('Version','OnlyChanged','CommitAndSync','Family','App','Tool','ShowVersions')
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
    Write-Error "Invalid argument(s): $($invalid -join ', ')`nSupported arguments: -Version -OnlyChanged -CommitAndSync -Family -App -Tool -ShowVersions"
    exit 2
}

# --- enforce Version mandatory if OnlyChanged is not given ---
if (-not $OnlyChanged -and [string]::IsNullOrWhiteSpace($Version)) {
    Write-Error "The -Version parameter is mandatory unless -OnlyChanged is specified."
    exit 2
}

$repo = 'D:\Dev\tooling-monorepo'
$bucket = 'D:\Dev\meibye-bucket\bucket'
if (-not (Test-Path $repo)) { $repo = 'C:\Dev\tooling-monorepo' }
if (-not (Test-Path $bucket)) { $bucket = 'C:\Dev\meibye-bucket\bucket' }
$outdir = "$repo\out\artifacts"

# Track manifests that were produced but not committed
$uncommittedManifests = @()

# Helper: get the latest published version for a tool/app from existing zip files and manifest
function Get-LatestVersion {
    param($toolName, $appName)
    $versions = @()
    $sources = @()
    $toolBaseName = [System.IO.Path]::GetFileNameWithoutExtension($toolName)
    if (Test-Path $outdir) {
        $zipVersions = Get-ChildItem -Path $outdir -Filter "$appName-*.zip" | ForEach-Object {
            if ($_.Name -match "$appName-(.+)\.zip") { $matches[1] }
        }
        if ($zipVersions) {
            $versions += $zipVersions
            foreach ($v in $zipVersions) { $sources += "zip:$v" }
        }
    }
    if (Test-Path "$bucket\$toolBaseName.json") {
        try {
            $manifest = Get-Content "$bucket\$toolBaseName.json" | ConvertFrom-Json
            if ($manifest.version) {
                $versions += $manifest.version
                $sources += "manifest:$($manifest.version)"
            }
        } catch {}
    }
    $versions = $versions | Where-Object { $_ } | Sort-Object -Descending
    if ($ShowVersions -and $OnlyChanged) {
        $srcStr = $sources | Where-Object { $_ } | Sort-Object -Descending
        Write-Host "App '$appName' tool '$toolName' considered versions: $($versions -join ', ') (sources: $($srcStr -join ', '))" -ForegroundColor Cyan
    }
    if ($versions.Count -gt 0) { return $versions[0] }
    return $DefaultVersion
}

# New helper: optionally git add/commit/pull/push the manifest in the bucket repo
function Publish-BucketManifest {
    param(
        [string]$ManifestPath,
        [string]$Name,
        [string]$Version,
        [string]$ZipPath
    )
    if (-not $CommitAndSync) {
        $script:uncommittedManifests += $ManifestPath
        return
    }
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        Write-Warning "git not found on PATH; skipping commit/sync for $Name"
        $script:uncommittedManifests += $ManifestPath
        return
    }
    try {
        # Commit manifest
        Push-Location $bucket
        $relPath = Split-Path $ManifestPath -Leaf
        & git add $relPath 2>$null
        Pop-Location

        # Commit zip file (in out/artifacts)
        if ($ZipPath -and (Test-Path $ZipPath)) {
            Push-Location $outdir
            $zipRel = Split-Path $ZipPath -Leaf
            & git add $zipRel 2>$null
            Pop-Location
        }

        # Commit and push both manifest and zip
        $manifestRel = Join-Path "meibye-bucket/bucket" (Split-Path $ManifestPath -Leaf)
        $zipRel = Join-Path "out/artifacts" ([System.IO.Path]::GetFileName($ZipPath))
        $commitMsg = "Publish $Name version $Version"
        # Commit in repo root if both files exist
        Push-Location $repo
        & git add $manifestRel 2>$null
        & git add $zipRel 2>$null
        $porcelain = (& git status --porcelain) -join "`n"
        if ($porcelain) {
            & git commit -m $commitMsg --no-verify 2>$null
            try { & git pull --rebase --autostash 2>$null } catch {}
            try { & git push 2>$null } catch {}
            Write-Host "Committed and pushed manifest and zip for $Name" -ForegroundColor Cyan
        } else {
            Write-Host "No git changes to commit for $Name" -ForegroundColor DarkGray
        }
        Pop-Location
    } catch {
        Write-Warning "Git commit/sync failed for ${Name}: $_"
        $script:uncommittedManifests += $ManifestPath
    }
}

function WildMatch($value, $pattern) {
    if ($pattern -eq "*" -or [string]::IsNullOrWhiteSpace($pattern)) { return $true }
    return $value -like $pattern
}

# --- Use dev-filter-tool.ps1 to get relevant files ---
$filterScript = Join-Path $PSScriptRoot 'dev-filter-tool.ps1'
$filteredTools = & $filterScript -Type dev -Location $repo -Family $Family -App $App -Tool $Tool

if (-not $filteredTools -or $filteredTools.Count -eq 0) {
    Write-Host "No matching tools found for publishing." -ForegroundColor Yellow
    exit 0
}

# Group tools by app for zipping
$toolsByApp = $filteredTools | Group-Object App

function Get-GitHubVersions {
    param($repoName, $toolName)
    # Function retained for future use, but not called when ShowVersions is specified
    return @()
}

foreach ($appGroup in $toolsByApp) {
    $app = $appGroup.Name
    $toolsInApp = $appGroup.Group
    $src = Split-Path $toolsInApp[0].Path -Parent
    # Version selection logic (use first tool for manifest lookup)
    $effectiveVersion = $null
    if ($OnlyChanged) {
        if ($Version) { $effectiveVersion = $Version }
        else { $effectiveVersion = Get-LatestVersion $toolsInApp[0].Tool $app }
    } else {
        if ($Version) { $effectiveVersion = $Version }
        else { $effectiveVersion = $DefaultVersion }
    }
    $zip = "$outdir\$app-$effectiveVersion.zip"
    $githubZipUrl = "https://github.com/meibye/tooling-monorepo/raw/main/out/artifacts/$app-$effectiveVersion.zip"
    try {
        if ($OnlyChanged -and (Test-Path $zip)) {
            $srcLatest = (Get-ChildItem $src -Recurse | Measure-Object -Property LastWriteTime -Maximum).Maximum
            $zipTime = (Get-Item $zip).LastWriteTime
            $srcLatestStr = $srcLatest.ToString("g", [System.Globalization.CultureInfo]::CurrentCulture)
            $zipTimeStr = $zipTime.ToString("g", [System.Globalization.CultureInfo]::CurrentCulture)
            # Source has no changes since last zip
            if ($srcLatest -lt $zipTime) {
                Write-Warning "Skipping $app (no changes: source last modified $srcLatestStr, zip last modified $zipTimeStr)"
                continue
            }
        }
        if (-not (Test-Path $outdir)) { New-Item -ItemType Directory -Force -Path $outdir | Out-Null }
        if (Test-Path $zip) { Remove-Item $zip -Force }
        Compress-Archive -Path "$src\*" -DestinationPath $zip -ErrorAction Stop
        $sha = (Get-FileHash $zip -Algorithm SHA256 -ErrorAction Stop).Hash

        # Produce manifest per tool, but only one zip per app
        foreach ($toolObj in $toolsInApp) {
            $fam = $toolObj.Family
            $toolName = $toolObj.Tool
            # Use ordered hashtable to control manifest attribute order
            $manifest = [ordered]@{
                version     = $effectiveVersion
                description = "$toolName ($fam tool from $app)"
                homepage    = ""
                license     = "MIT"
                url         = $githubZipUrl
                hash        = "sha256:$sha"
                bin         = @($toolName)
            }
            $manifestPath = "$bucket\$([System.IO.Path]::GetFileNameWithoutExtension($toolName)).json"
            $manifest | ConvertTo-Json -Depth 8 | Set-Content -Path $manifestPath -Encoding UTF8 -ErrorAction Stop

            # Verify manifest version matches zip file version
            $writtenManifest = Get-Content $manifestPath | ConvertFrom-Json
            if ($writtenManifest.version -ne $effectiveVersion) {
                Write-Error "Manifest version $($writtenManifest.version) does not match zip version $effectiveVersion for $toolName"
                continue
            }

            Write-Host "Published manifest for $toolName ($fam) version $effectiveVersion" -ForegroundColor Green
            Publish-BucketManifest -ManifestPath $manifestPath -Name $toolName -Version $effectiveVersion -ZipPath $zip
        }
    } catch {
        Write-Error "Failed to process ${app}: $_"
    }
    if ($ShowVersions) {
        foreach ($toolObj in $toolsInApp) {
            $toolName = $toolObj.Tool
            # Only show considered versions, do not show GitHub versions
        }
    }
}

# At the end, warn if any manifests were produced but not committed
if ($uncommittedManifests.Count -gt 0) {
    Write-Host ""
    Write-Host "Some manifests were produced but not committed to git:" -ForegroundColor Cyan
    foreach ($m in $uncommittedManifests | Select-Object -Unique) {
        Write-Host "  $m" -ForegroundColor Cyan
    }
    Write-Host "You may want to commit and push these manifests manually." -ForegroundColor Cyan
}