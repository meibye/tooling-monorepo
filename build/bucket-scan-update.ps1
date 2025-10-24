<#
.SYNOPSIS
    Update bucket manifests for tools and plugins in the tooling-monorepo.

.DESCRIPTION
    Scans the tooling-monorepo for tool and plugin directories, builds the current set of items,
    removes obsolete JSON manifests from the bucket directory, and optionally invokes
    bucket-publish.ps1 to regenerate manifests for new or changed items.
    Detects tools in family directories (ps, py, cmd, bash, zsh) and plugins/onemore.
    Uses fallback paths for repository and bucket locations (D:\... or C:\...).

.PARAMETER NoPublish
    When specified, skip calling bucket-publish.ps1. Only performs cleanup of obsolete manifests.

.EXAMPLE
    .\bucket-scan-update.ps1
    .\bucket-scan-update.ps1 -NoPublish

.NOTES
    - Exits with code 2 on invalid arguments.
    - Errors are written to host with colored output; fatal errors cause exit 1.
#>

param(
    [switch]$NoPublish
)

# --- argument validation ---
$allowed = @('NoPublish')
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
    Write-Error "Invalid argument(s): $($invalid -join ', ')`nSupported arguments: -NoPublish"
    exit 2
}

# Use same alternate path handling as bucket-publish.ps1
$repo = 'D:\Dev\tooling-monorepo'
$bucket = 'D:\Dev\meibye-bucket\bucket'
if (-not (Test-Path $repo)) { $repo = 'C:\Dev\tooling-monorepo' }
if (-not (Test-Path $bucket)) { $bucket = 'C:\Dev\meibye-bucket\bucket' }
$families = @('ps','py','cmd','bash','zsh')

# Build set of current tools (collect all tool script names, not just apps)
$currentTools = @{}
foreach ($fam in $families) {
    $famdir = "$repo\tools\$fam"
    if (-not (Test-Path $famdir)) { continue }
    try {
        Get-ChildItem -Path $famdir -Directory | ForEach-Object {
            $app = $_.Name
            $src = "$($_.FullName)\src"
            if (Test-Path $src) {
                Get-ChildItem $src -File -Recurse | Where-Object { $_.Extension -match '\.(ps1|py|cmd|bat|sh|zsh)$' } | ForEach-Object {
                    $toolName = $_.BaseName
                    $currentTools[$toolName] = $fam
                }
            }
        }
    } catch {
        Write-Host "Error reading directory ${famdir}: $_" -ForegroundColor Red
    }
}

# Add plugins from plugins\onemore (collect all tool script names)
$pluginDir = "$repo\plugins\onemore"
if (Test-Path $pluginDir) {
    try {
        Get-ChildItem -Path $pluginDir -Directory | ForEach-Object {
            $plugin = $_.Name
            $src = "$pluginDir\$plugin\src"
            if (Test-Path $src) {
                Get-ChildItem $src -File -Recurse | Where-Object { $_.Extension -match '\.(ps1|py|cmd|bat|sh|zsh)$' } | ForEach-Object {
                    $toolName = $_.BaseName
                    $currentTools[$toolName] = "plugin-onemore"
                }
            }
        }
    } catch {
        Write-Host "Error reading plugin directory ${pluginDir}: $_" -ForegroundColor Red
    }
}

# Remove manifests for deleted tools (manifests are per tool, not per app)
$deletedCount = 0
try {
    Get-ChildItem "$bucket\*.json" | ForEach-Object {
        $tool = $_.BaseName
        if (-not $currentTools.ContainsKey($tool)) {
            Write-Host "Removing obsolete manifest: $($_.FullName)" -ForegroundColor Yellow
            try {
                Remove-Item $_.FullName -Force
                $deletedCount++
            } catch {
                Write-Host "Failed to remove $($_.FullName): $_" -ForegroundColor Red
            }
        }
    }
    if ($deletedCount -eq 0) {
        Write-Host "No obsolete manifests to delete." -ForegroundColor Cyan
    }
} catch {
    Write-Host "Error processing manifests in ${bucket}: $_" -ForegroundColor Red
}

# Optionally, call bucket-publish.ps1 for new/changed tools/plugins
if (-not $NoPublish) {
    try {
        & "$PSScriptRoot\bucket-publish.ps1" -OnlyChanged
    } catch {
        Write-Host "Error running bucket-publish.ps1: $_" -ForegroundColor Red
    }
} else {
    Write-Host "Skipping bucket-publish.ps1 as per -NoPublish argument." -ForegroundColor Cyan
}