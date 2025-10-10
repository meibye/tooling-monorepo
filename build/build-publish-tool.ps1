<#
.SYNOPSIS
    Builds and publishes all tools and plugins from tooling-monorepo to the local bucket.
.DESCRIPTION
    For each tool and plugin, compresses the contents of its src folder into a zip archive, computes a SHA256 hash, and generates or updates a manifest JSON file in the bucket directory.
    The manifest includes version, description, license, URL to the zip, hash, and a list of executable files found in the src folder.
    Supports incremental publishing: if -OnlyChanged is specified, only tools and plugins with changes since the last published version are processed (based on file modification times).
    Handles tools in the tools directory (for families: ps, py, cmd, bash, zsh) and plugins in plugins\onemore.
.PARAMETER Version
    Optional. The version string to use for published artifacts. Defaults to "0.1.0".
.PARAMETER OnlyChanged
    Optional. If specified, only tools and plugins with changes since the last published version are built and published.
.EXAMPLE
    .\build-publish-tool.ps1 -Version 1.1.0
    .\build-publish-tool.ps1 -OnlyChanged
#>
param(
    [string]$Version = "0.1.0",
    [switch]$OnlyChanged
)

$repo = 'D:\Dev\tooling-monorepo'
$bucket = 'D:\Dev\meibye-bucket\bucket'

if (-not (Test-Path $repo)) {
    $repo = 'C:\Dev\tooling-monorepo'
}
if (-not (Test-Path $bucket)) {
    $bucket = 'C:\Dev\meibye-bucket\bucket'
}
$outdir = "$repo\out\artifacts"

$families = @('ps','py','cmd','bash','zsh')
foreach ($fam in $families) {
    $famdir = "$repo\tools\$fam"
    if (-not (Test-Path $famdir)) { continue }
    Get-ChildItem -Path $famdir -Directory | ForEach-Object {
        $app = $_.Name
        $src = "$($_.FullName)\src"
        if (-not (Test-Path $src)) { return }
        $zip = "$outdir\$app-$Version.zip"
        try {
            if ($OnlyChanged -and (Test-Path $zip) -and ((Get-ChildItem $src -Recurse | Measure-Object -Property LastWriteTime -Maximum).Maximum -lt (Get-Item $zip).LastWriteTime)) {
                Write-Host "Skipping $app (no changes)" -ForegroundColor Red
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
                version = $Version
                description = "$app ($fam tool)"
                homepage = ""
                license = "MIT"
                url = "file:///$zip"
                hash = "sha256:$sha"
                bin = $bins
            }
            $manifestPath = "$bucket\$app.json"
            $manifest | ConvertTo-Json -Depth 8 | Set-Content -Path $manifestPath -Encoding UTF8 -ErrorAction Stop
            Write-Host "Published $app ($fam) version $Version" -ForegroundColor Green
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
        $zip = "$outdir\$plugin-$Version.zip"
        try {
            if ($OnlyChanged -and (Test-Path $zip) -and ((Get-ChildItem $src -Recurse | Measure-Object -Property LastWriteTime -Maximum).Maximum -lt (Get-Item $zip).LastWriteTime)) {
                Write-Host "Skipping plugin $plugin (no changes)" -ForegroundColor Red
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
                version = $Version
                description = "$plugin (onemore plugin)"
                homepage = ""
                license = "MIT"
                url = "file:///$zip"
                hash = "sha256:$sha"
                bin = $bins
            }
            $manifestPath = "$bucket\$plugin.json"
            $manifest | ConvertTo-Json -Depth 8 | Set-Content -Path $manifestPath -Encoding UTF8 -ErrorAction Stop
            Write-Host "Published plugin $plugin (onemore) version $Version" -ForegroundColor Green
        } catch {
            Write-Error "Failed to process plugin $plugin (onemore): $_"
        }
    }
}