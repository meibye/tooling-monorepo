<#
.SYNOPSIS
    Deletes published manifests and artifacts from the bucket and out\artifacts folder.
.DESCRIPTION
    [bucket-clean-artifacts.ps1] Deletes published manifests (per tool) and artifacts (per app) from the bucket and out\artifacts folder.
    Uses dev-filter-tool.ps1 to filter tools by Family, App, and Tool arguments (wildcard "*" supported).
    Lists only impacted tools grouped by family and app, then asks for user confirmation before proceeding.
    Supports combined filtering by Family, App, and Tool.
.PARAMETER Family
    Optional. Tool type: ps, py, cmd, bash, zsh, plugin. Wildcard "*" for all. Filters by family.
.PARAMETER App
    Optional. App folder name. Wildcard "*" for all. Filters by app name across all families.
.PARAMETER Tool
    Optional. Name for the tool source file incl extension. Wildcard "*" for all. Filters by tool filename.
.EXAMPLE
    .\bucket-clean-artifacts.ps1
    .\bucket-clean-artifacts.ps1 -App tools
    .\bucket-clean-artifacts.ps1 -Family ps -App myapp -Tool mytool.ps1
    .\bucket-clean-artifacts.ps1 -Family plugin -App myplugin -Tool example.ps1
#>
param(
    [string]$Family = "*",
    [string]$App = "*",
    [string]$Tool = "*"
)

# --- argument validation ---
$allowed = @('App','Family','Tool')
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

$repo = 'D:\Dev\tooling-monorepo'
$bucket = 'D:\Dev\meibye-bucket\bucket'
$outdir = "$repo\out\artifacts"

if (-not (Test-Path $repo)) { $repo = 'C:\Dev\tooling-monorepo' }
if (-not (Test-Path $bucket)) { $bucket = 'C:\Dev\meibye-bucket\bucket' }

# Use dev-filter-tool.ps1 to get filtered tools from bucket manifests
$filterScript = Join-Path $PSScriptRoot 'dev-filter-tool.ps1'
$filteredTools = & $filterScript -Type bucket -Location $bucket -Family $Family -App $App -Tool $Tool

if (-not $filteredTools -or $filteredTools.Count -eq 0) {
    Write-Host "No impacted tools found. Nothing to delete." -ForegroundColor Cyan
    exit 0
}

Write-Host "The following tools will be cleaned:" -ForegroundColor Magenta
foreach ($toolObj in $filteredTools) {
    Write-Host "Family: $($toolObj.Family)  App: $($toolObj.App)  Tool: $($toolObj.Tool)" -ForegroundColor Magenta
}

$confirmation = Read-Host "Proceed with deletion? (y/n)"
if ($confirmation -notin @('y','Y')) {
    Write-Host "Aborted by user."
    exit 0
}

# Delete manifests and artifacts for each filtered tool
foreach ($toolObj in $filteredTools) {
    $manifestPath = $toolObj.Path
    if (Test-Path $manifestPath) {
        Remove-Item $manifestPath -Force -ErrorAction SilentlyContinue
        Write-Host "Deleted manifest: $manifestPath" -ForegroundColor Yellow
    }
    # Remove artifacts (zip) for the app/plugin
    $artifactPattern = "$($toolObj.App)-*.zip"
    if ($toolObj.Family -eq "plugin") {
        $artifactPattern = "$($toolObj.App)-*.zip"
    }
    if (Test-Path $outdir) {
        $zips = Get-ChildItem -Path $outdir -Filter $artifactPattern -File -ErrorAction SilentlyContinue
        if ($zips) {
            $zips | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "Deleted artifacts for $($toolObj.App) in $outdir" -ForegroundColor Yellow
        }
    }
}
