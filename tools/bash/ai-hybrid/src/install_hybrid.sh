#!/usr/bin/env bash
# install_hybrid.sh
#
# Installs and starts Neo4j, Qdrant, and Ollama containers for hybrid AI setup.
# Pulls required Ollama models and sets environment variables for local development.
#
# Usage:
#   bash install_hybrid.sh

set -e

# --- Check for root privileges ---
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run as root (sudo bash install_hybrid.sh)"
  exit 1
fi

# --- Install Docker if not present ---
if ! command -v docker &> /dev/null; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  usermod -aG docker $USER
  echo "Docker installed. You may need to log out/in for Docker permissions."
else
  echo "Docker is already installed."
fi

# --- Install Ollama if not present ---
if ! command -v ollama &> /dev/null; then
  echo "Installing Ollama..."
  curl -fsSL https://ollama.ai/install.sh | sh
else
  echo "Ollama is already installed."
fi

# --- Start containers ---
echo "Starting Neo4j container..."
docker run -d --name neo4j -p 7474:7474 -p 7687:7687 -e NEO4J_AUTH=neo4j/password neo4j:latest

echo "Starting Qdrant container..."
mkdir -p ~/qdrant_data
docker run -d --name qdrant -p 6333:6333 -v ~/qdrant_data:/qdrant/storage qdrant/qdrant:latest

echo "Starting Ollama server container..."
docker run -d --name ollama -p 11434:11434 ollama/ollama:latest

# --- Set environment variables (print for user to add to shell) ---
echo "Add these to your shell profile (~/.bashrc or ~/.zshrc):"
echo 'export NEO4J_URI="bolt://localhost:7687"'
echo 'export NEO4J_USER="neo4j"'
echo 'export NEO4J_PASS="password"'
echo 'export QDRANT_URL="http://localhost:6333"'
echo 'export OLLAMA_URL="http://localhost:11434"'
echo 'export EMBED_MODEL="nomic-embed-text"'
echo 'export CHAT_MODEL="llama3"'

# --- Pull Ollama models ---
echo "Pulling Ollama models..."
docker exec ollama ollama pull llama3
docker exec ollama olloma pull nomic-embed-text

# --- Verification with retries ---
retry_count=5
delay=10
for service in "http://localhost:7474" "http://localhost:6333" "http://localhost:11434"; do
  i=1
  while [ $i -le $retry_count ]; do
    if curl -s --head --request GET $service | grep "200 OK" > /dev/null; then
      echo "$service is up"
      break
    else
      echo "$service is not responding, attempt $i/$retry_count"
      sleep $delay
      i=$((i+1))
    fi
  done
  if [ $i -gt $retry_count ]; then
    echo "ERROR: $service failed to respond after $retry_count attempts"
    exit 1
  fi
done

echo "Installation and startup complete."
