# install-all-ai-hybrid-tools.ps1
<# 
   Extended installer script for WSL2 + Docker + Ollama + Neo4j + Qdrant + Model pulls + Verification 
#>

# === Parameters / Defaults ===
$dockerInstallerUrl   = "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe"
$dockerInstallerPath  = "$env:TEMP\DockerDesktopInstaller.exe"

$ollamaInstallerUrl   = "https://ollama.ai/download/OllamaSetup.exe"
$ollamaInstallerPath  = "$env:TEMP\OllamaSetup.exe"

$qdrantDataDir        = "F:\ai-hybrid\qdrant_data"
$neo4jPassword        = "password"

$ollamaModels         = @("llama3", "nomic-embed-text")    # adjust if needed
$maxRetries           = 5
$retryDelaySeconds    = 10

# === Check for elevated privileges ===
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator. Please restart PowerShell with elevated privileges."
    exit 1
}

# === Logging helper ===
function Log($msg) {
    Write-Host "$(Get-Date -Format u)  :: $msg"
}

# === Enable WSL2 and Virtual Machine Platform ===
function IsFeatureEnabled($featureName) {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName
    return $feature.State -eq "Enabled"
}

if (-not (IsFeatureEnabled "Microsoft-Windows-Subsystem-Linux")) {
    Log "Enabling WSL2 feature"
    Try {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -ErrorAction Stop
    } Catch {
        Log "Error enabling WSL2: $_"
    }
} else {
    Log "WSL2 feature is already enabled."
}

if (-not (IsFeatureEnabled "VirtualMachinePlatform")) {
    Log "Enabling Virtual Machine Platform feature"
    Try {
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -ErrorAction Stop
    } Catch {
        Log "Error enabling Virtual Machine Platform: $_"
    }
} else {
    Log "Virtual Machine Platform feature is already enabled."
}

Log "Prompt: Please reboot the machine if required. After reboot, rerun this script if needed for remaining steps."
# You can decide to stop here and reboot

# === Download and install Docker Desktop ===
function IsDockerInstalled {
    # Try to find docker in PATH or in common install locations
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    if ($dockerCmd) {
        Try {
            & $dockerCmd.Source --version | Out-Null
            return $true
        } Catch {
            return $false
        }
    } else {
        # Try common install locations if not in PATH
        $possiblePaths = @(
            "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe",
            "$env:ProgramFiles\Docker\docker.exe",
            "$env:ProgramFiles(x86)\Docker\docker.exe"
        )
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                Try {
                    & $path --version | Out-Null
                    return $true
                } Catch {
                    # continue checking other paths
                }
            }
        }
        return $false
    }
}

if (-not (IsDockerInstalled)) {
    Log "Downloading Docker Desktop installer..."
    Try {
        Invoke-WebRequest -Uri $dockerInstallerUrl -OutFile $dockerInstallerPath -UseBasicParsing
        Log "Running Docker Desktop installer..."
        Start-Process -FilePath $dockerInstallerPath -ArgumentList "install --quiet --accept-license" -Wait
        Log "Docker Desktop installation complete."
    } Catch {
        Log "ERROR: Docker Desktop installation failed: $_"
    }
} else {
    Log "Docker Desktop is already installed. Skipping installation."
}

# === Download & install Ollama ===
function GetDockerExe {
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    if ($dockerCmd) {
        return $dockerCmd.Source
    }
    $possiblePaths = @(
        "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe",
        "$env:ProgramFiles\Docker\docker.exe",
        "$env:ProgramFiles(x86)\Docker\docker.exe"
    )
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

function GetOllamaExe {
    $ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
    if ($ollamaCmd) {
        return $ollamaCmd.Source
    }
    $possiblePaths = @(
        "$env:ProgramFiles\Ollama\ollama.exe",
        "$env:ProgramFiles(x86)\Ollama\ollama.exe",
        "$env:LOCALAPPDATA\Ollama\ollama.exe"
    )
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

# Update IsOllamaInstalled to use GetOllamaExe
function IsOllamaInstalled {
    $ollamaExe = GetOllamaExe
    if ($ollamaExe) {
        Try {
            & $ollamaExe --version | Out-Null
            return $true
        } Catch {
            return $false
        }
    }
    return $false
}

if (-not (IsOllamaInstalled)) {
    Log "Downloading Ollama installer..."
    Try {
        Invoke-WebRequest -Uri $ollamaInstallerUrl -OutFile $ollamaInstallerPath -UseBasicParsing
        Log "Installing Ollama..."
        # Ollama may open a web UI after installation. To continue the script, simply proceed to the next steps.
        # If you want to suppress or close the UI, you may need to kill the browser process or instruct the user to close it.
        # For automation, just log a message and continue:
        Log "If Ollama Web UI opened, you may close it manually. Continuing script execution..."
        $proc = Start-Process -FilePath $ollamaInstallerPath -PassThru
        Log "Ollama installation process details:"
        $proc | Format-Table Id, ProcessName, StartTime
        $proc.WaitForExit()
        Log "Ollama installation complete."
    } Catch {
        Log "ERROR: Ollama installation failed: $_"
    }
} else {
    Log "Ollama is already installed. Skipping installation."
}

# === Install cypher-shell if not present ===
function IsCypherShellInstalled {
    $cypherCmd = Get-Command cypher-shell -ErrorAction SilentlyContinue
    if ($cypherCmd) {
        Try {
            & $cypherCmd.Source --version | Out-Null
            return $true
        } Catch {
            return $false
        }
    }
    # Try common Neo4j install locations
    $possiblePaths = @(
        "$env:ProgramFiles\Neo4j\bin\cypher-shell.bat",
        "$env:ProgramFiles\Neo4j Desktop\bin\cypher-shell.bat"
    )
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $true
        }
    }
    return $false
}

if (-not (IsCypherShellInstalled)) {
    Log "cypher-shell not found. Downloading and installing cypher-shell..."
    $cypherShellUrl = "https://github.com/neo4j/cypher-shell/releases/latest/download/cypher-shell.zip"
    $cypherShellZip = "$env:TEMP\cypher-shell.zip"
    $cypherShellExtractDir = "$env:ProgramFiles\Neo4j\cypher-shell"
    Try {
        Invoke-WebRequest -Uri $cypherShellUrl -OutFile $cypherShellZip -UseBasicParsing
        if (-not (Test-Path $cypherShellExtractDir)) {
            New-Item -ItemType Directory -Path $cypherShellExtractDir | Out-Null
        }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($cypherShellZip, $cypherShellExtractDir)
        $cypherShellBat = Join-Path $cypherShellExtractDir "cypher-shell.bat"
        # Add to PATH for current user
        $envPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($envPath -notlike "*$cypherShellExtractDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$envPath;$cypherShellExtractDir", "User")
            Log "Added cypher-shell to user PATH."
        }
        Log "cypher-shell installed at $cypherShellExtractDir"
    } Catch {
        Log "ERROR: Failed to install cypher-shell. Exception: $($_.Exception.Message) | StackTrace: $($_.Exception.StackTrace)"
    }
} else {
    Log "cypher-shell is already installed. Skipping installation."
}

# Ensure Docker Desktop is running
function IsDockerRunning {
    $dockerProcess = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
    return $dockerProcess -ne $null
}

if (-not (IsDockerRunning)) {
    Log "Docker Desktop is not running. Attempting to start Docker Desktop..."
    $dockerDesktopPath = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerDesktopPath) {
        Try {
            Start-Process -FilePath $dockerDesktopPath
            
            Log "Docker Desktop started. Waiting for Docker to become available..."
            # Wait for Docker daemon to be ready
            $maxWait = 60
            $waited = 0
            while ($waited -lt $maxWait) {
                if (IsDockerInstalled) {
                    Try {
                        & (GetDockerExe) info | Out-Null
                        Log "Docker daemon is available."
                        break
                    } Catch {
                        # Docker not ready yet
                    }
                }
                Start-Sleep -Seconds 2
                $waited += 2
            }
            if ($waited -ge $maxWait) {
                Log "ERROR: Docker daemon did not become available after waiting."
            }
        } Catch {
            Log "ERROR: Failed to start Docker Desktop: $_"
        }
    } else {
        Log "ERROR: Docker Desktop executable not found at $dockerDesktopPath."
    }
} else {
    Log "Docker Desktop is already running."
}

# Helper to get docker executable path
$dockerExe = GetDockerExe
if (-not $dockerExe) {
    Log "ERROR: Docker executable not found in PATH or common locations. Please ensure Docker is installed and available."
} else {
    function EnsureContainerStoppedAndRemoved($containerName) {
        $exists = & $dockerExe ps -a --filter "name=$containerName" --format "{{.Names}}" | Where-Object { $_ -eq $containerName }
        if ($exists) {
            Log "Container '$containerName' already exists. Stopping and removing..."
            Try {
                & $dockerExe stop $containerName | Out-Null
            } Catch {
                Log "Warning: Could not stop container '$containerName': $_"
            }
            Try {
                & $dockerExe rm $containerName | Out-Null
                Log "Container '$containerName' removed."
            } Catch {
                Log "Warning: Could not remove container '$containerName': $_"
            }
        }
    }

    Log "Starting Neo4j container..."
    EnsureContainerStoppedAndRemoved "neo4j"
    Try {
        & $dockerExe run -d --name neo4j -p 7474:7474 -p 7687:7687 `
            -e NEO4J_AUTH="neo4j/$neo4jPassword" neo4j:latest | Out-Null
        Log "Neo4j container started."
    } Catch {
        Log "ERROR: Failed to start Neo4j container: $_"
    }

    Log "Starting Qdrant container..."
    if (-Not (Test-Path $qdrantDataDir)) {
        Try {
            New-Item -ItemType Directory -Path $qdrantDataDir | Out-Null
            Log "Created Qdrant data directory."
        } Catch {
            Log "ERROR: Failed to create Qdrant data directory: $_"
        }
    }
    EnsureContainerStoppedAndRemoved "qdrant"
    Try {
        & $dockerExe run -d --name qdrant -p 6333:6333 -v ${qdrantDataDir}:/qdrant/storage qdrant/qdrant:latest | Out-Null
        Log "Qdrant container started."
    } Catch {
        Log "ERROR: Failed to start Qdrant container: $_"
    }

    Log "Starting Ollama server container..."
    EnsureContainerStoppedAndRemoved "ollama"
    Try {
        & $dockerExe run -d --name ollama -p 11434:11434 ollama/ollama:latest | Out-Null
        Log "Ollama container started."
    } Catch {
        Log "ERROR: Failed to start Ollama container: $_"
    }
}

# === Set environment variables ===
Log "Setting environment variables for current user"
[Environment]::SetEnvironmentVariable("NEO4J_URI", "bolt://localhost:7687", "User")
[Environment]::SetEnvironmentVariable("NEO4J_USER", "neo4j",             "User")
[Environment]::SetEnvironmentVariable("NEO4J_PASS", $neo4jPassword,        "User")
[Environment]::SetEnvironmentVariable("QDRANT_URL", "http://localhost:6333", "User")
[Environment]::SetEnvironmentVariable("OLLAMA_URL", "http://localhost:11434","User")
[Environment]::SetEnvironmentVariable("EMBED_MODEL", "nomic-embed-text",   "User")
[Environment]::SetEnvironmentVariable("CHAT_MODEL",  "llama3",              "User")

Log "Environment variables set for user session. You may need to restart your PowerShell or log off for them to take effect."

# === Pull Ollama models ===
$ollamaExe = GetOllamaExe
foreach ($model in $ollamaModels) {
    Log "Pulling Ollama model: $model"
    Try {
        if ($ollamaExe) {
            & $ollamaExe pull $model
            if ($LASTEXITCODE -ne 0) {
                Log "Error pulling model ${model}. Exit code: $LASTEXITCODE"
            } else {
                Log "Model ${model} pulled successfully."
            }
        } else {
            Log "ERROR: Ollama executable not found for model pull."
        }
    } Catch {
        Log "Exception while pulling model ${model}: $_"
    }
}

# === Verification with retries ===
function WaitForService($uri, $serviceName) {
    for ($i=1; $i -le $maxRetries; $i++) {
        Try {
            $resp = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 10
            if ($resp.StatusCode -eq 200) {
                Log "$serviceName is up (status 200)."
                return $true
            }
        } Catch {
            Log "$serviceName not yet responding. Attempt $i of $maxRetries."
        }
        Start-Sleep -Seconds $retryDelaySeconds
    }
    Log "ERROR: $serviceName failed to respond after $maxRetries attempts."
    return $false
}

Log "Verifying Neo4j (http://localhost:7474)..."
$okNeo4j = WaitForService "http://localhost:7474" "Neo4j"

Log "Verifying Qdrant (http://localhost:6333)..."
$okQdrant = WaitForService "http://localhost:6333" "Qdrant"

Log "Verifying Ollama API (http://localhost:11434)..."
$okOllama = WaitForService "http://localhost:11434" "Ollama"

if ($okNeo4j -and $okQdrant -and $okOllama) {
    Log "All services appear to be running successfully."
} else {
    Log "One or more services did not respond. Please check logs/debug further."
}

Log "Install-and-start script complete."
