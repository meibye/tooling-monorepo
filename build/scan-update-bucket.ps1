<#
.SYNOPSIS
    Updates the bucket manifests to match the current tools and plugins in the tooling-monorepo.
.DESCRIPTION
    Scans the tooling-monorepo for available tools and plugins, removes obsolete manifests from the bucket directory, and invokes build-publish-tool.ps1 to update or add manifests for new or changed items.
.EXAMPLE
    .\scan-update-bucket.ps1
#>

function Test-PathOrAlternate {
    param(
        [string]$Primary,
        [string]$Alternate
    )
    if (Test-Path $Primary) { return $Primary }
    elseif (Test-Path $Alternate) { return $Alternate }
    else { throw "Neither $Primary nor $Alternate exist." }
}

try {
    $repo = Test-PathOrAlternate 'D:\Dev\tooling-monorepo' 'C:\Dev\tooling-monorepo'
    $bucket = Test-PathOrAlternate 'D:\Dev\meibye-bucket\bucket' 'C:\Dev\meibye-bucket\bucket'
    $families = @('ps','py','cmd','bash','zsh')

    # Build set of current tools
    $current = @{}
    foreach ($fam in $families) {
        $famdir = "$repo\tools\$fam"
        if (-not (Test-Path $famdir)) { continue }
        try {
            Get-ChildItem -Path $famdir -Directory | ForEach-Object {
                $app = $_.Name
                $current["$app"] = $fam
            }
        } catch {
            Write-Host "Error reading directory ${famdir}: $_" -ForegroundColor Red
        }
    }

    # Add plugins from plugins\onemore
    $pluginDir = "$repo\plugins\onemore"
    if (Test-Path $pluginDir) {
        try {
            Get-ChildItem -Path $pluginDir -Directory | ForEach-Object {
                $plugin = $_.Name
                $current["$plugin"] = "plugin-onemore"
            }
        } catch {
            Write-Host "Error reading plugin directory ${pluginDir}: $_" -ForegroundColor Red
        }
    }

    # Remove manifests for deleted tools/plugins
    try {
        Get-ChildItem "$bucket\*.json" | ForEach-Object {
            $app = $_.BaseName
            if (-not $current.ContainsKey($app)) {
                Write-Host "Removing obsolete manifest: $($_.FullName)" -ForegroundColor Yellow
                try {
                    Remove-Item $_.FullName -Force
                } catch {
                    Write-Host "Failed to remove $($_.FullName): $_" -ForegroundColor Red
                }
            }
        }
    } catch {
        Write-Host "Error processing manifests in ${bucket}: $_" -ForegroundColor Red
    }

    # Optionally, call build-publish-tool.ps1 for new/changed tools/plugins
    try {
        & "$PSScriptRoot\build-publish-tool.ps1" -OnlyChanged
    } catch {
        Write-Host "Error running build-publish-tool.ps1: $_" -ForegroundColor Red
    }
} catch {
    Write-Host "Fatal error: $_" -ForegroundColor Red
    exit 1
}