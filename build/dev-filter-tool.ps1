<#
.SYNOPSIS
    Returns a table/list of tool script paths filtered by Family, App, and Tool arguments.
.DESCRIPTION
    Scans the development or bucket folder structure and returns matching tool script paths.
    Intended for use by other build scripts (e.g., bucket-*).
.PARAMETER Type
    Indicates whether Location is 'dev' (default, development sources) or 'bucket' (bucket manifests).
.PARAMETER Location
    Root location of the sources or bucket. Defaults to D:\Dev\tooling-monorepo for dev, D:\Dev\meibye-bucket\bucket for bucket.
.PARAMETER Family
    Tool type: ps, py, cmd, bash, zsh, plugin. Wildcard "*" for all.
.PARAMETER App
    Folder grouping for related tools. Wildcard "*" for all.
.PARAMETER Tool
    Name for the tool source file incl extension. Wildcard "*" for all.
.EXAMPLE
    .\dev-filter-tool.ps1 -Family ps -App myapp -Tool "*.ps1"
    .\dev-filter-tool.ps1 -Type bucket -Tool "*.ps1"
#>

param(
    [string]$Type = "dev",
    [string]$Location,
    [string]$Family = "*",
    [string]$App = "*",
    [string]$Tool = "*"
)

# --- argument validation ---
$allowed = @('Type','Location','Family','App','Tool')
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
    Write-Error "Invalid argument(s): $($invalid -join ', ')`nSupported arguments: -Type -Location -Family -App -Tool"
    exit 2
}

function WildMatch($value, $pattern) {
    if ($pattern -eq "*" -or [string]::IsNullOrWhiteSpace($pattern)) { return $true }
    return $value -like $pattern
}

function GetFamilyExtensions($fam) {
    switch ($fam) {
        "ps"   { return @(".ps1", ".psm1", ".psd1") }
        "py"   { return @(".py", ".pyw") }
        "cmd"  { return @(".bat", ".cmd") }
        "bash" { return @(".sh") }
        "zsh"  { return @(".sh", ".zsh") }
        default { return @() }
    }
}

# Set default location if not provided
if (-not $Location) {
    if ($Type -eq "bucket") {
        $Location = 'D:\Dev\meibye-bucket\bucket'
        if (-not (Test-Path $Location)) { $Location = 'C:\Dev\meibye-bucket\bucket' }
    } else {
        $Location = 'D:\Dev\tooling-monorepo'
        if (-not (Test-Path $Location)) { $Location = 'C:\Dev\tooling-monorepo' }
    }
}

$results = @()

if ($Type -eq "dev") {
    $familyList = @('ps','py','cmd','bash','zsh','plugin')
    # Handle tool families
    foreach ($famItem in $familyList[0..4]) {
        if (-not (WildMatch $famItem $Family)) { continue }
        $famDir = "$Location\tools\$famItem"
        if (-not (Test-Path $famDir)) { continue }
        Get-ChildItem -Path $famDir -Directory | ForEach-Object {
            $appItem = $_.Name
            if (-not (WildMatch $appItem $App)) { return }
            $srcDir = "$($_.FullName)\src"
            if (-not (Test-Path $srcDir)) { return }
            $toolFiles = Get-ChildItem $srcDir -File -Recurse | Where-Object { $_.Extension -match '\.(ps1|py|cmd|bat|sh|zsh)$' }
            # Tool filter logic with extension fallback
            if ($Tool -eq "*" -or [string]::IsNullOrWhiteSpace($Tool)) {
                foreach ($toolFileObj in $toolFiles) {
                    $results += [PSCustomObject]@{
                        Family = $famItem
                        App = $appItem
                        Tool = $toolFileObj.Name
                        Path = $toolFileObj.FullName
                    }
                }
            } else {
                $toolMatches = @()
                $toolMatches += $toolFiles | Where-Object { $_.Name -eq $Tool }
                if ($toolMatches.Count -eq 0 -and [System.IO.Path]::GetExtension($Tool) -eq "") {
                    $exts = GetFamilyExtensions($famItem)
                    foreach ($ext in $exts) {
                        $tryName = "$Tool$ext"
                        $toolMatches += @($toolFiles | Where-Object { $_.Name -eq $tryName })
                    }
                }
                foreach ($toolFileObj in $toolMatches) {
                    $results += [PSCustomObject]@{
                        Family = $famItem
                        App = $appItem
                        Tool = $toolFileObj.Name
                        Path = $toolFileObj.FullName
                    }
                }
            }
        }
    }
    # Handle plugins
    if ($Family -eq "*" -or $Family -eq "plugin") {
        $pluginDir = "$Location\plugins\onemore"
        if (Test-Path $pluginDir) {
            Get-ChildItem -Path $pluginDir -Directory | ForEach-Object {
                $pluginItem = $_.Name
                if (-not (WildMatch $pluginItem $App)) { return }
                $srcDir = "$($_.FullName)\src"
                if (-not (Test-Path $srcDir)) { return }
                $toolFiles = Get-ChildItem $srcDir -File -Recurse | Where-Object { $_.Extension -match '\.(ps1|py|cmd|bat|sh|zsh)$' }
                if ($Tool -eq "*" -or [string]::IsNullOrWhiteSpace($Tool)) {
                    foreach ($toolFileObj in $toolFiles) {
                        $results += [PSCustomObject]@{
                            Family = "plugin"
                            App = $pluginItem
                            Tool = $toolFileObj.Name
                            Path = $toolFileObj.FullName
                        }
                    }
                } else {
                    $toolMatches = @()
                    $toolMatches += $toolFiles | Where-Object { $_.Name -eq $Tool }
                    # For plugins, try all extensions if no match and no extension given
                    if ($toolMatches.Count -eq 0 -and [System.IO.Path]::GetExtension($Tool) -eq "") {
                        $exts = @(".ps1", ".py", ".cmd", ".bat", ".sh", ".zsh", ".psm1", ".psd1", ".pyw")
                        foreach ($ext in $exts) {
                            $tryName = "$Tool$ext"
                            $toolMatches += @($toolFiles | Where-Object { $_.Name -eq $tryName })
                        }
                    }
                    foreach ($toolFileObj in $toolMatches) {
                        $results += [PSCustomObject]@{
                            Family = "plugin"
                            App = $pluginItem
                            Tool = $toolFileObj.Name
                            Path = $toolFileObj.FullName
                        }
                    }
                }
            }
        }
    }
}
elseif ($Type -eq "bucket") {
    $bucketDir = $Location
    if (-not (Test-Path $bucketDir)) {
        Write-Error "Bucket location not found: $bucketDir"
        exit 1
    }
    Get-ChildItem "$bucketDir\*.json" | ForEach-Object {
        $manifestPath = $_.FullName
        try {
            $manObj = Get-Content $manifestPath -ErrorAction Stop | ConvertFrom-Json
        } catch {
            return
        }
        $toolBaseName = $_.BaseName
        $binList = @()
        if ($manObj.bin -is [System.Collections.IEnumerable]) { $binList = $manObj.bin }
        elseif ($manObj.bin) { $binList = @($manObj.bin) }
        foreach ($binItem in $binList) {
            $desc = $manObj.description
            $famMatch = ""
            $appMatch = ""
            if ($desc -match '\(([^ ]+) tool from ([^)]+)\)') {
                $famMatch = $matches[1]
                $appMatch = $matches[2]
            }
            # Tool filter logic with extension fallback for bucket
            $toolMatches = @()
            if ($Tool -eq "*" -or [string]::IsNullOrWhiteSpace($Tool)) {
                $toolMatches += $binItem
            } else {
                if ($binItem -eq $Tool) {
                    $toolMatches += $binItem
                } elseif ([System.IO.Path]::GetExtension($Tool) -eq "") {
                    $exts = GetFamilyExtensions($famMatch)
                    foreach ($ext in $exts) {
                        $tryName = "$Tool$ext"
                        if ($binItem -eq $tryName) {
                            # Update Tool to match the actual tool name with extension
                            $Tool = $tryName
                            $toolMatches += $binItem
                        }
                    }
                }
            }
            foreach ($matchedTool in $toolMatches) {
                if (-not (WildMatch $famMatch $Family)) { continue }
                if (-not (WildMatch $appMatch $App)) { continue }
                if (-not (WildMatch $matchedTool $Tool)) { continue }
                $results += [PSCustomObject]@{
                    Family = $famMatch
                    App = $appMatch
                    Tool = $matchedTool
                    Path = $manifestPath
                }
            }
        }
    }
} else {
    Write-Error "Invalid Type parameter: $Type. Supported values are 'dev' and 'bucket'."
    exit 2
}
    
# Output as table if run directly, otherwise return results for script use
if ($MyInvocation.ScriptName -and ($MyInvocation.InvocationName -eq $MyInvocation.ScriptName)) {
    # Run directly: print table
    if ($results.Count -eq 0) {
        Write-Host "No matching tools found." -ForegroundColor Yellow
    } else {
        $results | Format-Table -AutoSize
    }
} else {
    # Called from another script: output objects only
    $results
}
