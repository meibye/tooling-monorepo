# start-hybrid-ai.ps1
<#
   Script to start Docker Desktop, Ollama, Neo4j, Qdrant, and Ollama server containers if not already running.
   Only starts services that are not already running.
#>

# === Logging helper ===
function Log($msg) {
    Write-Host "$(Get-Date -Format u)  :: $msg"
}

# === Helper: Get Docker Desktop Path ===
function GetDockerDesktopPath {
    return "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
}

# === Helper: Get Docker Exe Path ===
function GetDockerExe {
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    if ($dockerCmd) { return $dockerCmd.Source }
    $possiblePaths = @(
        "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe",
        "$env:ProgramFiles\Docker\docker.exe",
        "$env:ProgramFiles(x86)\Docker\docker.exe"
    )
    foreach ($path in $possiblePaths) { if (Test-Path $path) { return $path } }
    return $null
}

# === Helper: Get Ollama Exe Path ===
function GetOllamaExe {
    $ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
    if ($ollamaCmd) { return $ollamaCmd.Source }
    $possiblePaths = @(
        "$env:ProgramFiles\Ollama\ollama.exe",
        "$env:ProgramFiles(x86)\Ollama\ollama.exe",
        "$env:LOCALAPPDATA\Ollama\ollama.exe"
    )
    foreach ($path in $possiblePaths) { if (Test-Path $path) { return $path } }
    return $null
}

# === Check if Docker Desktop is running ===
function IsDockerRunning {
    $dockerProcess = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
    return $dockerProcess -ne $null
}

# === Check if Docker daemon is available ===
function IsDockerDaemonAvailable {
    $dockerExe = GetDockerExe
    if ($dockerExe) {
        Try {
            & $dockerExe info | Out-Null
            return $true
        } Catch { return $false }
    }
    return $false
}

# === Check if Ollama is running ===
function IsOllamaRunning {
    $ollamaProcess = Get-Process -Name "ollama" -ErrorAction SilentlyContinue
    return $ollamaProcess -ne $null
}

# === Check if container is running ===
function IsContainerRunning($name) {
    $dockerExe = GetDockerExe
    if ($dockerExe) {
        $result = & $dockerExe ps --filter "name=$name" --filter "status=running" --format "{{.Names}}"
        return $result -eq $name
    }
    return $false
}

# === Start Docker Desktop if needed ===
if (-not (IsDockerRunning)) {
    $dockerDesktopPath = GetDockerDesktopPath
    if (Test-Path $dockerDesktopPath) {
        Log "Starting Docker Desktop..."
        Start-Process -FilePath $dockerDesktopPath
        # Wait for Docker daemon
        $maxWait = 60
        $waited = 0
        while ($waited -lt $maxWait) {
            if (IsDockerDaemonAvailable) {
                Log "Docker daemon is available."
                break
            }
            Start-Sleep -Seconds 2
            $waited += 2
        }
        if ($waited -ge $maxWait) { Log "ERROR: Docker daemon did not become available after waiting." }
    } else {
        Log "ERROR: Docker Desktop executable not found."
    }
} else {
    Log "Docker Desktop is already running."
}

# === Start Ollama if needed ===
if (-not (IsOllamaRunning)) {
    $ollamaExe = GetOllamaExe
    if ($ollamaExe) {
        Log "Starting Ollama..."
        Start-Process -FilePath $ollamaExe
    } else {
        Log "ERROR: Ollama executable not found."
    }
} else {
    Log "Ollama is already running."
}

# === Start Neo4j container if needed ===
if (-not (IsContainerRunning "neo4j")) {
    $dockerExe = GetDockerExe
    if ($dockerExe) {
        Log "Starting Neo4j container..."
        & $dockerExe run -d --name neo4j -p 7474:7474 -p 7687:7687 -e NEO4J_AUTH="neo4j/password" neo4j:latest | Out-Null
    } else {
        Log "ERROR: Docker executable not found."
    }
} else {
    Log "Neo4j container is already running."
}

# === Start Qdrant container if needed ===
$qdrantDataDir = "F:\ai-hybrid\qdrant_data"
if (-not (IsContainerRunning "qdrant")) {
    $dockerExe = GetDockerExe
    if ($dockerExe) {
        if (-Not (Test-Path $qdrantDataDir)) {
            Try {
                New-Item -ItemType Directory -Path $qdrantDataDir | Out-Null
                Log "Created Qdrant data directory."
            } Catch {
                Log "ERROR: Failed to create Qdrant data directory: $_"
            }
        }
        Log "Starting Qdrant container..."
        & $dockerExe run -d --name qdrant -p 6333:6333 -v ${qdrantDataDir}:/qdrant/storage qdrant/qdrant:latest | Out-Null
    } else {
        Log "ERROR: Docker executable not found."
    }
} else {
    Log "Qdrant container is already running."
}

# === Start Ollama server container if needed ===
if (-not (IsContainerRunning "ollama")) {
    $dockerExe = GetDockerExe
    if ($dockerExe) {
        Log "Starting Ollama server container..."
        & $dockerExe run -d --name ollama -p 11434:11434 ollama/ollama:latest | Out-Null
    } else {
        Log "ERROR: Docker executable not found."
    }
} else {
    Log "Ollama server container is already running."
}

Log "Hybrid AI startup script complete."
