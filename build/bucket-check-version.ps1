<#
.SYNOPSIS
    Shows the version from the bucket manifest and the deployed version for a specified tool/app.
.DESCRIPTION
    [bucket-check-version.ps1] Reads the manifest for a tool/app from a local bucket directory, displays its version, and compares it to the version currently deployed in the apps directory. Supports filtering by Family, App, and Tool.
.PARAMETER Family
    Optional. Tool type (e.g., ps, py, cmd, bash, zsh, plugin). Use "*" for all types.
.PARAMETER App
    Required. Name of the tool/app to check (without file extension).
.PARAMETER Tool
    Optional. Source file name including extension. Use "*" for all.
.EXAMPLE
    .\bucket-check-version.ps1 -App my-ps-tool
    .\bucket-check-version.ps1 -Family ps -App tools -Tool dev-print-path.ps1
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

try {
    $bucket = 'D:\Dev\meibye-bucket\bucket'
    if (-not (Test-Path $bucket)) { $bucket = 'C:\Dev\meibye-bucket\bucket' }
    if (-not (Test-Path $bucket)) {
        Write-Error "Bucket path not found: D:\Dev\meibye-bucket\bucket or C:\Dev\meibye-bucket\bucket"
        exit 1
    }

    # Use dev-filter-tool.ps1 to find relevant manifest(s)
    $filterScript = Join-Path $PSScriptRoot 'dev-filter-tool.ps1'
    $filtered = & $filterScript -Type bucket -Location $bucket -Family $Family -App $App -Tool $Tool

    if (-not $filtered -or $filtered.Count -eq 0) {
        Write-Error "No matching manifest found for Family='$Family', App='$App', Tool='$Tool'"
        exit 1
    }

    $results = @()
    foreach ($toolObj in $filtered) {
        $manifest = $toolObj.Path
        $toolName = $toolObj.Tool
        $appName = $toolObj.App
        $famName = $toolObj.Family

        $bucketVersion = ""
        $deployedVersion = ""
        try {
            $man = Get-Content $manifest -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            $bucketVersion = $man.version
        } catch {
            $bucketVersion = "<manifest error>"
        }

        $appsRoot = 'C:\Tools\apps'
        if (-not (Test-Path $appsRoot)) { $appsRoot = 'D:\Tools\apps' }
        if (-not (Test-Path $appsRoot)) {
            $deployedVersion = "<apps root not found>"
        } else {
            $deployed = Get-ChildItem "$appsRoot\*\$appName\current" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($deployed) {
                try {
                    $deployedVersion = Split-Path ($deployed.Target) -Leaf
                } catch {
                    $deployedVersion = "<deployed version error>"
                }
            } else {
                $deployedVersion = "<not deployed>"
            }
        }

        $results += [PSCustomObject]@{
            Family = $famName
            App = $appName
            Script = $toolName
            BucketVersion = $bucketVersion
            DeployedVersion = $deployedVersion
            Differs = ($bucketVersion -ne $deployedVersion)
        }
    }

    if ($results.Count -eq 0) {
        Write-Host "No matching manifest found for Family='$Family', App='$App', Tool='$Tool'" -ForegroundColor Yellow
        exit 1
    }

    # Print table header
    $header = "{0,-10} {1,-30} {2,-35} {3,-18} {4,-18}" -f "Family", "App", "Script", "BucketVersion", "DeployedVersion"
    Write-Host $header -ForegroundColor Cyan
    Write-Host ("-" * ($header.Length + 2)) -ForegroundColor Cyan

    # Sort results by Family, then App
    $results | Sort-Object Family, App | ForEach-Object {
        $row = $_
        $line = "{0,-10} {1,-30} {2,-35} {3,-18} {4,-18}" -f $row.Family, $row.App, $row.Script, $row.BucketVersion, $row.DeployedVersion
        if ($row.Differs -and $row.BucketVersion -notmatch "^<" -and $row.DeployedVersion -notmatch "^<") {
            Write-Host $line -ForegroundColor Yellow
        } else {
            Write-Host $line
        }
    }
    Write-Host ""

} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}