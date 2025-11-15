# ai-hybrid-clear-datastores.ps1
# Run in PowerShell (Administrator recommended)

param(
    [string]$Neo4jUri  = "bolt://localhost:7687",
    [string]$Neo4jUser = "neo4j",
    [string]$Neo4jPass = "password",
    [string]$QdrantUrl = "http://localhost:6333",
    [string]$QdrantCollection = "trace_artifacts"
)

Write-Host "Clearing Neo4j data..."
# You might need to run this via cypher-shell
$cypher = @"
MATCH (n)
DETACH DELETE n;
"@

# Use cypher-shell (assuming installed) to run the query
& cypher-shell -u $Neo4jUser -p $Neo4jPass --format plain "$cypher"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to execute Neo4j delete query. Check credentials and connection."
} else {
    Write-Host "Neo4j: All nodes and relationships deleted."
}

Write-Host "Clearing Qdrant collection '$QdrantCollection'..."
$deleteUrl = "$QdrantUrl/collections/$QdrantCollection"
$response = Invoke-RestMethod -Method Delete -Uri $deleteUrl -ErrorAction SilentlyContinue
if ($response -and $response.result -eq $true) {
    Write-Host "Qdrant collection deleted."
} else {
    Write-Warning "Qdrant deletion request may have failed. Response: $($response | ConvertTo-Json)"
}

Write-Host "Data stores cleared. You can now re-import."
