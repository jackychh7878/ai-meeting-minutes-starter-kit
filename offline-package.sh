#!/bin/bash

# Offline Docker Images Packaging Script
# This script packages all Docker images from docker-compose.yaml for offline deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PACKAGE_DIR="offline-docker-package"
IMAGES_DIR="${PACKAGE_DIR}/images"
MODELS_DIR="${PACKAGE_DIR}/models"
SCRIPTS_DIR="${PACKAGE_DIR}/scripts"

# Docker images from docker-compose.yaml
DOCKER_IMAGES=(
    "n8nio/n8n:latest"
    "pgvector/pgvector:pg17"
    "minio/minio:RELEASE.2025-06-13T11-33-47Z"
    "postgres:16-alpine"
    "qdrant/qdrant:v1.7.4"
    "ollama/ollama:latest"
    "ollama/ollama:rocm"
    "jccatomind/ai_meeting_backend:latest"
    "jccatomind/ai_meeting_chatbot_frontend:latest"
)

# Ollama model to package
OLLAMA_MODEL="deepseek-r1:70b-llama-distill-q8_0"

echo -e "${BLUE}=== AI Meeting Minutes - Offline Package Creator ===${NC}"
echo -e "${YELLOW}This script will package all Docker images and models for offline deployment${NC}"
echo ""

# Create package directory structure
echo -e "${GREEN}Creating package directory structure...${NC}"
mkdir -p "${IMAGES_DIR}" "${MODELS_DIR}" "${SCRIPTS_DIR}"

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}Error: Docker is not running. Please start Docker and try again.${NC}"
        exit 1
    fi
}

# Function to pull and save Docker images
package_docker_images() {
    echo -e "${GREEN}Pulling and packaging Docker images...${NC}"
    
    for image in "${DOCKER_IMAGES[@]}"; do
        echo -e "${YELLOW}Processing: ${image}${NC}"
        
        # Pull the image
        if docker pull "${image}"; then
            # Save the image to tar file
            image_filename=$(echo "${image}" | sed 's|/|_|g' | sed 's|:|_|g')
            echo -e "${BLUE}Saving ${image} to ${image_filename}.tar${NC}"
            docker save -o "${IMAGES_DIR}/${image_filename}.tar" "${image}"
            echo -e "${GREEN}✓ Saved ${image}${NC}"
        else
            echo -e "${RED}✗ Failed to pull ${image}${NC}"
            exit 1
        fi
        echo ""
    done
}

# Function to package Ollama model
package_ollama_model() {
    echo -e "${GREEN}Packaging Ollama model: ${OLLAMA_MODEL}${NC}"
    
    # Check if Ollama is running
    if ! command -v ollama &> /dev/null; then
        echo -e "${YELLOW}Ollama not found locally. Will package model using Docker...${NC}"
        
        # Start temporary Ollama container to pull the model
        echo -e "${BLUE}Starting temporary Ollama container...${NC}"
        docker run -d --name temp-ollama -v ollama_temp:/root/.ollama ollama/ollama:latest
        
        # Wait for Ollama to start
        sleep 10
        
        # Pull the model
        echo -e "${BLUE}Pulling model: ${OLLAMA_MODEL}${NC}"
        docker exec temp-ollama ollama pull "${OLLAMA_MODEL}"
        
        # Copy model files from container
        echo -e "${BLUE}Extracting model files...${NC}"
        docker cp temp-ollama:/root/.ollama "${MODELS_DIR}/"
        
        # Cleanup
        docker stop temp-ollama
        docker rm temp-ollama
        docker volume rm ollama_temp
        
    else
        echo -e "${BLUE}Using local Ollama installation...${NC}"
        
        # Pull the model locally
        ollama pull "${OLLAMA_MODEL}"
        
        # Copy model files
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            OLLAMA_MODELS_PATH="$HOME/.ollama"
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            OLLAMA_MODELS_PATH="$HOME/.ollama"
        else
            OLLAMA_MODELS_PATH="$HOME/.ollama"
        fi
        
        if [ -d "${OLLAMA_MODELS_PATH}" ]; then
            cp -r "${OLLAMA_MODELS_PATH}" "${MODELS_DIR}/"
            echo -e "${GREEN}✓ Model files copied${NC}"
        else
            echo -e "${RED}✗ Ollama models directory not found${NC}"
            exit 1
        fi
    fi
}

# Function to create deployment scripts
create_deployment_scripts() {
    echo -e "${GREEN}Creating deployment scripts...${NC}"
    
    # Create load images script
    cat > "${SCRIPTS_DIR}/load-images.sh" << 'EOF'
#!/bin/bash

# Load Docker Images Script for Offline Deployment

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Loading Docker images for AI Meeting Minutes...${NC}"

# Load all image tar files
for tar_file in ../images/*.tar; do
    if [ -f "$tar_file" ]; then
        echo -e "${YELLOW}Loading: $(basename "$tar_file")${NC}"
        docker load -i "$tar_file"
        echo -e "${GREEN}✓ Loaded: $(basename "$tar_file")${NC}"
    fi
done

echo -e "${GREEN}All Docker images loaded successfully!${NC}"
EOF

    # Create setup Ollama script
    cat > "${SCRIPTS_DIR}/setup-ollama.sh" << 'EOF'
#!/bin/bash

# Setup Ollama Models Script for Offline Deployment

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Setting up Ollama models...${NC}"

# Create Ollama data directory if it doesn't exist
OLLAMA_DIR="$HOME/.ollama"
mkdir -p "$OLLAMA_DIR"

# Copy model files
if [ -d "../models/.ollama" ]; then
    echo -e "${YELLOW}Copying Ollama models...${NC}"
    cp -r ../models/.ollama/* "$OLLAMA_DIR/"
    echo -e "${GREEN}✓ Ollama models copied successfully!${NC}"
else
    echo -e "${RED}✗ Ollama models directory not found${NC}"
    exit 1
fi

echo -e "${GREEN}Ollama setup completed!${NC}"
EOF

    # Create main deployment script
    cat > "${SCRIPTS_DIR}/deploy.sh" << 'EOF'
#!/bin/bash

# Main Deployment Script for AI Meeting Minutes - Offline Installation

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== AI Meeting Minutes - Offline Deployment ===${NC}"
echo ""

# Check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}Docker is not running. Please start Docker service.${NC}"
        exit 1
    fi
}

# Check if Docker Compose is available
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
        exit 1
    fi
}

echo -e "${YELLOW}Checking prerequisites...${NC}"
check_docker
check_docker_compose
echo -e "${GREEN}✓ Prerequisites satisfied${NC}"
echo ""

# Load Docker images
echo -e "${YELLOW}Loading Docker images...${NC}"
./load-images.sh
echo ""

# Setup Ollama models
echo -e "${YELLOW}Setting up Ollama models...${NC}"
./setup-ollama.sh
echo ""

# Copy docker-compose files to parent directory
echo -e "${YELLOW}Setting up Docker Compose files...${NC}"
cp ../docker-compose.yaml ../
cp ../env.template ../.env
cp ../init-schema.sql ../
echo -e "${GREEN}✓ Docker Compose files ready${NC}"
echo ""

echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Edit the .env file with your configuration"
echo "2. Choose your deployment profile:"
echo "   - For CPU: docker-compose --profile cpu up -d"
echo "   - For NVIDIA GPU: docker-compose --profile gpu-nvidia up -d"
echo "   - For AMD GPU: docker-compose --profile gpu-amd up -d"
echo ""
echo -e "${BLUE}Access points after deployment:${NC}"
echo "- AI Meeting Backend: http://localhost:8000"
echo "- Frontend: http://localhost:3000"
echo "- n8n: http://localhost:5678"
echo "- MinIO Console: http://localhost:9001"
echo "- Qdrant: http://localhost:6333"
EOF

    # Make scripts executable
    chmod +x "${SCRIPTS_DIR}"/*.sh
}

# Function to create package info
create_package_info() {
    cat > "${PACKAGE_DIR}/README.md" << EOF
# AI Meeting Minutes - Offline Deployment Package

This package contains all Docker images and models needed for offline deployment of the AI Meeting Minutes application.

## Contents

- \`images/\` - Docker image tar files
- \`models/\` - Ollama model files (deepseek-r1:70b-llama-distill-q8_0)
- \`scripts/\` - Deployment scripts
- \`docker-compose.yaml\` - Docker Compose configuration
- \`env.template\` - Environment variables template
- \`init-schema.sql\` - Database initialization script

## Package Information

**Created:** $(date)
**Docker Images:** ${#DOCKER_IMAGES[@]} images
**Ollama Model:** ${OLLAMA_MODEL}
**Total Size:** $(du -sh "${PACKAGE_DIR}" | cut -f1)

## Deployment Instructions

1. Transfer this entire package to your offline Ubuntu machine
2. Extract the package: \`tar -xzf ai-meeting-offline-package.tar.gz\`
3. Navigate to the scripts directory: \`cd ai-meeting-offline-package/scripts\`
4. Run the deployment script: \`./deploy.sh\`
5. Follow the on-screen instructions

## System Requirements

- Ubuntu 18.04+ or compatible Linux distribution
- Docker 20.10+ installed
- Docker Compose 1.27+ installed
- Minimum 16GB RAM (32GB recommended for the 70B model)
- Minimum 100GB free disk space

## Hardware Profiles

The application supports three deployment profiles:
- \`cpu\` - CPU-only deployment
- \`gpu-nvidia\` - NVIDIA GPU acceleration
- \`gpu-amd\` - AMD GPU acceleration

Choose the appropriate profile based on your hardware.
EOF

    # Copy necessary files to package
    cp docker-compose.yaml "${PACKAGE_DIR}/"
    cp env.template "${PACKAGE_DIR}/"
    cp init-schema.sql "${PACKAGE_DIR}/"
}

# Main execution
main() {
    echo -e "${YELLOW}Starting packaging process...${NC}"
    echo ""
    
    check_docker
    package_docker_images
    package_ollama_model
    create_deployment_scripts
    create_package_info
    
    echo -e "${GREEN}Creating final package archive...${NC}"
    tar -czf "ai-meeting-offline-package.tar.gz" "${PACKAGE_DIR}"
    
    # Cleanup
    rm -rf "${PACKAGE_DIR}"
    
    echo ""
    echo -e "${GREEN}=== Packaging Complete! ===${NC}"
    echo -e "${YELLOW}Package created: ai-meeting-offline-package.tar.gz${NC}"
    echo -e "${YELLOW}Package size: $(du -sh ai-meeting-offline-package.tar.gz | cut -f1)${NC}"
    echo ""
    echo -e "${BLUE}To deploy on offline Ubuntu machine:${NC}"
    echo "1. Transfer: scp ai-meeting-offline-package.tar.gz user@target-host:~/"
    echo "2. Extract: tar -xzf ai-meeting-offline-package.tar.gz"
    echo "3. Deploy: cd ai-meeting-offline-package/scripts && ./deploy.sh"
    echo ""
    echo -e "${GREEN}Happy deploying! 🚀${NC}"
}

# Run main function
main "$@" 