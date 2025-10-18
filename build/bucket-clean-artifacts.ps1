<#
.SYNOPSIS
    Deletes published manifests and artifacts from the bucket and out\artifacts folder.
.DESCRIPTION
    [bucket-clean-artifacts.ps1] Lists only impacted apps (tools and plugins) grouped by family that currently have artifacts or manifests to delete, then asks for user confirmation before proceeding.
    If an App is specified, only deletes artifacts and manifests for that app.
.PARAMETER App
    Optional. If specified, only deletes artifacts and manifests for the given app (tool or plugin).
.EXAMPLE
    .\bucket-clean-artifacts.ps1
    .\bucket-clean-artifacts.ps1 -App mytool
#>
param(
    [string]$App
)

$repo = 'D:\Dev\tooling-monorepo'
$bucket = 'D:\Dev\meibye-bucket\bucket'
$outdir = "$repo\out\artifacts"

if (-not (Test-Path $repo)) {
    $repo = 'C:\Dev\tooling-monorepo'
}
if (-not (Test-Path $bucket)) {
    $bucket = 'C:\Dev\meibye-bucket\bucket'
}

$families = @('ps','py','cmd','bash','zsh')

# Gather impacted apps (only those with artifacts or manifests to delete)
$impactedApps = @{}
$impactedPlugins = @()
if ($App) {
    $found = $false
    foreach ($fam in $families) {
        $famdir = "$repo\tools\$fam"
        if (Test-Path "$famdir\$App") {
            $manifestPath = "$bucket\$App.json"
            $artifactExists = (Test-Path $manifestPath) -or (Test-Path $outdir -and (Get-ChildItem -Path $outdir -Filter "$App-*.zip" | Where-Object { $_ }))
            if ($artifactExists) {
                $impactedApps[$fam] = @($App)
            }
            $found = $true
        }
    }
    $pluginDir = "$repo\plugins\onemore"
    if (Test-Path "$pluginDir\$App") {
        $manifestPath = "$bucket\$App.json"
        $artifactExists = (Test-Path $manifestPath) -or (Test-Path $outdir -and (Get-ChildItem -Path $outdir -Filter "$App-*.zip" | Where-Object { $_ }))
        if ($artifactExists) {
            $impactedPlugins = @($App)
        }
        $found = $true
    }
    if (-not $found) {
        Write-Host "App '$App' not found in any family or plugins." -ForegroundColor Red
        exit 1
    }
} else {
    foreach ($fam in $families) {
        $famdir = "$repo\tools\$fam"
        if (Test-Path $famdir) {
            $apps = Get-ChildItem -Path $famdir -Directory | Select-Object -ExpandProperty Name
            $appsToClean = @()
            foreach ($app in $apps) {
                $manifestPath = "$bucket\$app.json"
                $artifactExists = (Test-Path $manifestPath) -or ((Test-Path $outdir) -and (Get-ChildItem -Path $outdir -Filter "$app-*.zip" | Where-Object { $_ }))
                if ($artifactExists) {
                    $appsToClean += $app
                }
            }
            if ($appsToClean.Count -gt 0) {
                $impactedApps[$fam] = $appsToClean
            }
        }
    }
    $pluginDir = "$repo\plugins\onemore"
    if (Test-Path $pluginDir) {
        $plugins = Get-ChildItem -Path $pluginDir -Directory | Select-Object -ExpandProperty Name
        foreach ($plugin in $plugins) {
            $manifestPath = "$bucket\$plugin.json"
            $artifactExists = (Test-Path $manifestPath) -or ((Test-Path $outdir) -and (Get-ChildItem -Path $outdir -Filter "$plugin-*.zip" | Where-Object { $_ }))
            if ($artifactExists) {
                $impactedPlugins += $plugin
            }
        }
    }
}

if (($impactedApps.Count -eq 0) -and ($impactedPlugins.Count -eq 0)) {
    Write-Host "No impacted apps found. Nothing to delete." -ForegroundColor Cyan
    exit 0
}

Write-Host "The following apps will be cleaned:" -ForegroundColor Magenta
foreach ($fam in $impactedApps.Keys) {
    Write-Host "Family: $fam" -ForegroundColor Magenta
    foreach ($app in $impactedApps[$fam]) {
        Write-Host "  $app" -ForegroundColor Magenta
    }
}
if ($impactedPlugins.Count -gt 0) {
    Write-Host "Plugins (onemore):" -ForegroundColor Magenta
    foreach ($plugin in $impactedPlugins) {
        Write-Host "  $plugin" -ForegroundColor Magenta
    }
}

$confirmation = Read-Host "Proceed with deletion? (y/n)"
if ($confirmation -notin @('y','Y')) {
    Write-Host "Aborted by user."
    exit 0
}

# Delete manifests and artifacts for each app in each family
foreach ($fam in $impactedApps.Keys) {
    foreach ($app in $impactedApps[$fam]) {
        $manifestPath = "$bucket\$app.json"
        if (Test-Path $manifestPath) {
            Remove-Item $manifestPath -Force
            Write-Host "Deleted manifest: $manifestPath" -ForegroundColor Yellow
        }
        if (Test-Path $outdir) {
            Get-ChildItem -Path $outdir -Filter "$app-*.zip" | Remove-Item -Force
            Write-Host "Deleted artifacts for $app in $outdir" -ForegroundColor Yellow
        }
    }
}

# Clean plugins\onemore
foreach ($plugin in $impactedPlugins) {
    $manifestPath = "$bucket\$plugin.json"
    if (Test-Path $manifestPath) {
        Remove-Item $manifestPath -Force
        Write-Host "Deleted manifest: $manifestPath" -ForegroundColor Yellow
    }
    if (Test-Path $outdir) {
        Get-ChildItem -Path $outdir -Filter "$plugin-*.zip" | Remove-Item -Force
        Write-Host "Deleted artifacts for plugin $plugin in $outdir" -ForegroundColor Yellow
    }
}
