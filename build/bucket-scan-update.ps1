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

    # Optionally, call bucket-publish.ps1 for new/changed tools/plugins
    if (-not $NoPublish) {
        try {
            & "$PSScriptRoot\bucket-publish.ps1" -OnlyChanged
        } catch {
            Write-Host "Error running bucket-publish.ps1: $_" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "Fatal error: $_" -ForegroundColor Red
    exit 1
}