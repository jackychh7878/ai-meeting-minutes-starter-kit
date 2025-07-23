# Offline Docker Images Packaging Script (PowerShell)
# This script packages all Docker images from docker-compose.yaml for offline deployment

param(
    [switch]$Help
)

if ($Help) {
    Write-Host @"
AI Meeting Minutes - Offline Package Creator (PowerShell)

This script packages all Docker images and models for offline deployment to Ubuntu machines.

Usage: .\offline-package.ps1

Requirements:
- Docker Desktop running on Windows
- PowerShell 5.1+ or PowerShell Core 7+
- Sufficient disk space (recommend 100GB+ free)

The script will:
1. Pull all required Docker images
2. Save them as tar files
3. Package the specified Ollama model
4. Create deployment scripts for the target Ubuntu machine
5. Generate a compressed archive ready for transfer

"@
    exit 0
}

# Configuration
$PackageDir = "offline-docker-package"
$ImagesDir = "$PackageDir\images"
$ModelsDir = "$PackageDir\models"
$ScriptsDir = "$PackageDir\scripts"

# Docker images from docker-compose.yaml
$DockerImages = @(
    "n8nio/n8n:latest",
    "pgvector/pgvector:pg17",
    "minio/minio:RELEASE.2025-06-13T11-33-47Z",
    "postgres:16-alpine",
    "qdrant/qdrant:v1.7.4",
    "ollama/ollama:latest",
    "ollama/ollama:rocm",
    "jccatomind/ai_meeting_backend:latest",
    "jccatomind/ai_meeting_chatbot_frontend:latest"
)

# Ollama model to package
# $OllamaModel = "deepseek-r1:70b-llama-distill-q8_0"
$OllamaModel = "llama3.2"

# Functions for colored output
function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-ColoredOutput "[SUCCESS] $Message" "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColoredOutput "[WARNING] $Message" "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColoredOutput "[ERROR] $Message" "Red"
}

function Write-Info {
    param([string]$Message)
    Write-ColoredOutput "[INFO] $Message" "Cyan"
}

# Check if Docker is running
function Test-Docker {
    try {
        $null = docker info 2>$null
        return $true
    }
    catch {
        return $false
    }
}

# Create bash scripts for Linux deployment
function Create-BashScripts {
    Write-Success "Creating deployment scripts..."
    
    # Create load-images.sh
    $loadImagesContent = @"
#!/bin/bash

# Load Docker Images Script for Offline Deployment

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "`${GREEN}Loading Docker images for AI Meeting Minutes...`${NC}"

# Load all image tar files
for tar_file in ../images/*.tar; do
    if [[ -f "`$tar_file" ]]; then
        echo -e "`${YELLOW}Loading: `$(basename "`$tar_file")`${NC}"
        docker load -i "`$tar_file"
        echo -e "`${GREEN}[SUCCESS] Loaded: `$(basename "`$tar_file")`${NC}"
    fi
done

echo -e "`${GREEN}All Docker images loaded successfully!`${NC}"
"@
    $loadImagesContent -replace "`r`n", "`n" | Out-File -FilePath "$ScriptsDir\load-images.sh" -Encoding UTF8 -NoNewline
    
    # Create setup-ollama.sh
    $setupOllamaContent = @"
#!/bin/bash

# Setup Ollama Models Script for Offline Deployment

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "`${GREEN}Setting up Ollama models...`${NC}"

# Create Ollama data directory if it doesn't exist
OLLAMA_DIR="`$HOME/.ollama"
mkdir -p "`$OLLAMA_DIR"

# Copy model files
if [[ -d "../models/.ollama" ]]; then
    echo -e "`${YELLOW}Copying Ollama models...`${NC}"
    cp -r ../models/.ollama/* "`$OLLAMA_DIR/"
    echo -e "`${GREEN}[SUCCESS] Ollama models copied successfully!`${NC}"
else
    echo -e "`${RED}[ERROR] Ollama models directory not found`${NC}"
    exit 1
fi

echo -e "`${GREEN}Ollama setup completed!`${NC}"
"@
    $setupOllamaContent -replace "`r`n", "`n" | Out-File -FilePath "$ScriptsDir\setup-ollama.sh" -Encoding UTF8 -NoNewline
    
    # Create deploy.sh
    $deployContent = @"
#!/bin/bash

# Main Deployment Script for AI Meeting Minutes - Offline Installation

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "`${BLUE}=== AI Meeting Minutes - Offline Deployment ===`${NC}"
echo ""

# Check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "`${RED}Docker is not installed. Please install Docker first.`${NC}"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        echo -e "`${RED}Docker is not running. Please start Docker service.`${NC}"
        exit 1
    fi
}

# Check if Docker Compose is available
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "`${RED}Docker Compose is not installed. Please install Docker Compose first.`${NC}"
        exit 1
    fi
}

echo -e "`${YELLOW}Checking prerequisites...`${NC}"
check_docker
check_docker_compose
echo -e "`${GREEN}[SUCCESS] Prerequisites satisfied`${NC}"
echo ""

# Load Docker images
echo -e "`${YELLOW}Loading Docker images...`${NC}"
./load-images.sh
echo ""

# Setup Ollama models
echo -e "`${YELLOW}Setting up Ollama models...`${NC}"
./setup-ollama.sh
echo ""

# Copy docker-compose files to parent directory
echo -e "`${YELLOW}Setting up Docker Compose files...`${NC}"
cp ../docker-compose.yaml ../
cp ../env.template ../.env
cp ../init-schema.sql ../
echo -e "`${GREEN}[SUCCESS] Docker Compose files ready`${NC}"
echo ""

echo -e "`${GREEN}=== Deployment Complete! ===`${NC}"
echo ""
echo -e "`${YELLOW}Next steps:`${NC}"
echo "1. Edit the .env file with your configuration"
echo "2. Choose your deployment profile:"
echo "   - For CPU: docker-compose --profile cpu up -d"
echo "   - For NVIDIA GPU: docker-compose --profile gpu-nvidia up -d"
echo "   - For AMD GPU: docker-compose --profile gpu-amd up -d"
echo ""
echo -e "`${BLUE}Access points after deployment:`${NC}"
echo "- AI Meeting Backend: http://localhost:8000"
echo "- Frontend: http://localhost:3000"
echo "- n8n: http://localhost:5678"
echo "- MinIO Console: http://localhost:9001"
echo "- Qdrant: http://localhost:6333"
"@
    $deployContent -replace "`r`n", "`n" | Out-File -FilePath "$ScriptsDir\deploy.sh" -Encoding UTF8 -NoNewline
}

# Create README file
function Create-ReadmeFile {
    $packageSize = if (Test-Path $PackageDir) { 
        [math]::Round((Get-ChildItem $PackageDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB, 2) 
    } else { 
        0 
    }
    
    $readmeContent = @"
# AI Meeting Minutes - Offline Deployment Package

This package contains all Docker images and models needed for offline deployment of the AI Meeting Minutes application.

## Contents

- images/ - Docker image tar files
- models/ - Ollama model files (deepseek-r1:70b-llama-distill-q8_0)
- scripts/ - Deployment scripts
- docker-compose.yaml - Docker Compose configuration
- env.template - Environment variables template
- init-schema.sql - Database initialization script

## Package Information

**Created:** $(Get-Date)
**Docker Images:** $($DockerImages.Count) images
**Ollama Model:** $OllamaModel
**Approximate Size:** $packageSize GB

## Deployment Instructions

1. Transfer this entire package to your offline Ubuntu machine
2. Extract the package: tar -xzf ai-meeting-offline-package.tar.gz
3. Navigate to the scripts directory: cd ai-meeting-offline-package/scripts
4. Make scripts executable: chmod +x *.sh
5. Run the deployment script: ./deploy.sh
6. Follow the on-screen instructions

## System Requirements

- Ubuntu 18.04+ or compatible Linux distribution
- Docker 20.10+ installed
- Docker Compose 1.27+ installed
- Minimum 16GB RAM (32GB recommended for the 70B model)
- Minimum 100GB free disk space

## Hardware Profiles

The application supports three deployment profiles:
- cpu - CPU-only deployment
- gpu-nvidia - NVIDIA GPU acceleration
- gpu-amd - AMD GPU acceleration

Choose the appropriate profile based on your hardware.

## Transfer Instructions

### Using SCP (Secure Copy):
scp ai-meeting-offline-package.tar.gz user@target-host:~/

### Using rsync:
rsync -avz --progress ai-meeting-offline-package.tar.gz user@target-host:~/

### Using Windows to Linux transfer tools:
- WinSCP (GUI)
- PuTTY/pscp (command line)
- Windows Subsystem for Linux (WSL)
"@
    $readmeContent -replace "`r`n", "`n" | Out-File -FilePath "$PackageDir\README.md" -Encoding UTF8 -NoNewline
}

# Main script execution
Write-ColoredOutput "=== AI Meeting Minutes - Offline Package Creator ===" "Blue"
Write-Warning "This script will package all Docker images and models for offline deployment"
Write-Host ""

# Create package directory structure
Write-Success "Creating package directory structure..."
if (Test-Path $PackageDir) {
    Remove-Item $PackageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $PackageDir, $ImagesDir, $ModelsDir, $ScriptsDir -Force | Out-Null

# Check if Docker is running
if (-not (Test-Docker)) {
    Write-Error "Docker is not running. Please start Docker Desktop and try again."
    exit 1
}

# Package Docker images
Write-Success "Pulling and packaging Docker images..."
foreach ($image in $DockerImages) {
    Write-Warning "Processing: $image"
    
    # Pull the image
    $pullResult = docker pull $image 2>&1
    if ($LASTEXITCODE -eq 0) {
        # Save the image to tar file
        $imageFilename = $image -replace "/", "_" -replace ":", "_"
        Write-Info "Saving $image to $imageFilename.tar"
        docker save -o "$ImagesDir\$imageFilename.tar" $image
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Saved $image"
        } else {
            Write-Error "Failed to save $image"
            exit 1
        }
    } else {
        Write-Error "Failed to pull $image"
        exit 1
    }
    Write-Host ""
}

# Package Ollama model
Write-Success "Packaging Ollama model: $OllamaModel"

# Check if Ollama is available locally
$ollamaAvailable = $false
try {
    $null = ollama --version 2>$null
    $ollamaAvailable = $true
} catch {
    $ollamaAvailable = $false
}

if (-not $ollamaAvailable) {
    Write-Warning "Ollama not found locally. Will package model using Docker..."
    
    # Start temporary Ollama container to pull the model
    Write-Info "Starting temporary Ollama container..."
    docker run -d --name temp-ollama -v ollama_temp:/root/.ollama ollama/ollama:latest
    
    # Wait for Ollama to start
    Start-Sleep 15
    
    # Pull the model
    Write-Info "Pulling model: $OllamaModel"
    docker exec temp-ollama ollama pull $OllamaModel
    
    if ($LASTEXITCODE -eq 0) {
        # Create models directory structure
        New-Item -ItemType Directory -Path "$ModelsDir\.ollama" -Force | Out-Null
        
        # Copy model files from container
        Write-Info "Extracting model files..."
        docker cp temp-ollama:/root/.ollama/. "$ModelsDir\.ollama\"
        
        Write-Success "Model files extracted"
    } else {
        Write-Error "Failed to pull model $OllamaModel"
        # Cleanup
        docker stop temp-ollama | Out-Null
        docker rm temp-ollama | Out-Null
        docker volume rm ollama_temp | Out-Null
        exit 1
    }
    
    # Cleanup
    docker stop temp-ollama | Out-Null
    docker rm temp-ollama | Out-Null
    docker volume rm ollama_temp | Out-Null
} else {
    Write-Info "Using local Ollama installation..."
    
    # Pull the model locally
    ollama pull $OllamaModel
    
    if ($LASTEXITCODE -eq 0) {
        # Copy model files
        $ollamaPath = "$env:USERPROFILE\.ollama"
        if (Test-Path $ollamaPath) {
            Copy-Item -Path $ollamaPath -Destination "$ModelsDir\.ollama" -Recurse -Force
            Write-Success "Model files copied"
        } else {
            Write-Error "Ollama models directory not found at $ollamaPath"
            exit 1
        }
    } else {
        Write-Error "Failed to pull model $OllamaModel"
        exit 1
    }
}

# Create deployment scripts and README
Create-BashScripts
Create-ReadmeFile

# Copy necessary files to package
Copy-Item "docker-compose.yaml" "$PackageDir\" -Force
Copy-Item "env.template" "$PackageDir\" -Force
Copy-Item "init-schema.sql" "$PackageDir\" -Force

# Create compressed archive
Write-Success "Creating final package archive..."

# Check if 7-Zip is available, otherwise use built-in compression
$sevenZipPath = "${env:ProgramFiles}\7-Zip\7z.exe"
if (Test-Path $sevenZipPath) {
    Write-Info "Using 7-Zip for compression..."
    & $sevenZipPath a -ttar "ai-meeting-offline-package.tar" $PackageDir
    & $sevenZipPath a -tgzip "ai-meeting-offline-package.tar.gz" "ai-meeting-offline-package.tar"
    Remove-Item "ai-meeting-offline-package.tar" -Force
} else {
    Write-Warning "7-Zip not found, using PowerShell compression (may be slower)..."
    Compress-Archive -Path $PackageDir -DestinationPath "ai-meeting-offline-package.zip" -Force
    Write-Warning "Created ZIP file instead of tar.gz. You may need to extract and repackage on Linux."
}

# Cleanup
Remove-Item $PackageDir -Recurse -Force

# Final output
Write-Host ""
Write-ColoredOutput "=== Packaging Complete! ===" "Green"

if (Test-Path "ai-meeting-offline-package.tar.gz") {
    $finalSize = [math]::Round((Get-Item "ai-meeting-offline-package.tar.gz").Length / 1GB, 2)
    Write-Warning "Package created: ai-meeting-offline-package.tar.gz"
    Write-Warning "Package size: $finalSize GB"
} elseif (Test-Path "ai-meeting-offline-package.zip") {
    $finalSize = [math]::Round((Get-Item "ai-meeting-offline-package.zip").Length / 1GB, 2)
    Write-Warning "Package created: ai-meeting-offline-package.zip"
    Write-Warning "Package size: $finalSize GB"
}

Write-Host ""
Write-ColoredOutput "To deploy on offline Ubuntu machine:" "Blue"
Write-Host "1. Transfer file using SCP, rsync, or your preferred method"
Write-Host "2. Extract: tar -xzf ai-meeting-offline-package.tar.gz (or unzip for .zip)"
Write-Host "3. Navigate: cd ai-meeting-offline-package/scripts"
Write-Host "4. Make executable: chmod +x *.sh"
Write-Host "5. Deploy: ./deploy.sh"
Write-Host ""
Write-ColoredOutput "Happy deploying!" "Green" 