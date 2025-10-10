<#
.SYNOPSIS
    Creates the folder structure for the AI Knowledge Base project.

.DESCRIPTION
    This script creates a set of directories for the AI Knowledge Base (ai-kb) project on a specified drive (default: F).
    It also generates helper PowerShell scripts to start and stop the Docker Compose stack for the project.
    Error handling is included for directory and file creation.

.PARAMETER Drive
    The drive letter where the ai-kb root folder will be created. Defaults to 'F'.

.EXAMPLE
    .\create-ai-kb-structure.ps1
    .\create-ai-kb-structure.ps1 -Drive D
#>

param(
    [string]$Drive = "F"
)

$root="$Drive`:\ai-kb"
$paths=@(
  "$root\data\qdrant",
  "$root\data\ollama",
  "$root\data\neo4j\data",
  "$root\data\neo4j\logs",
  "$root\data\neo4j\plugins",
  "$root\appflowy-data",
  "$root\exports",
  "$root\media\audio",
  "$root\media\video",
  "$root\media\images",
  "$root\media\diagrams\visio_src",
  "$root\media\diagrams\visio_export",
  "$root\notes",
  "$root\ingest"
)
foreach($p in $paths){
    try {
        New-Item -ItemType Directory -Force -Path $p | Out-Null
    } catch {
        Write-Host "Failed to create directory: $p" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# helper start/stop
try {
    @"
cd $root
docker compose up -d
"@ | Set-Content -Path "$root\start-ai.ps1" -Encoding UTF8
} catch {
    Write-Host "Failed to write start-ai.ps1" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

try {
    @"
cd $root
docker compose down
"@ | Set-Content -Path "$root\stop-ai.ps1" -Encoding UTF8
} catch {
    Write-Host "Failed to write stop-ai.ps1" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
