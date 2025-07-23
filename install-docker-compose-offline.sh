#!/bin/bash

# Docker Compose Offline Installation Script
# This script can be used to download, transfer, and install Docker Compose on offline machines
# Usage: ./install-docker-compose-offline.sh [OPTIONS]

set -e  # Exit on any error

# Default configuration
COMPOSE_VERSION="v2.24.1"
ARCHITECTURE="x86_64"
INSTALL_DIR="/usr/local/bin"
DOWNLOAD_DIR="./docker-compose-offline"
REMOTE_USER=""
REMOTE_HOST=""
REMOTE_PATH="/tmp/docker-compose-install"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Docker Compose Offline Installation Script

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    download    Download Docker Compose binary (run on internet-connected machine)
    install     Install Docker Compose from local binary (run on offline machine)
    transfer    Transfer files to remote machine via SCP
    help        Show this help message

OPTIONS:
    -v, --version VERSION     Docker Compose version (default: $COMPOSE_VERSION)
    -a, --arch ARCH          Architecture: x86_64 or aarch64 (default: $ARCHITECTURE)
    -d, --download-dir DIR   Download directory (default: $DOWNLOAD_DIR)
    -i, --install-dir DIR    Installation directory (default: $INSTALL_DIR)
    -u, --user USER          Remote username for SCP transfer
    -h, --host HOST          Remote hostname/IP for SCP transfer
    -p, --path PATH          Remote path for transfer (default: $REMOTE_PATH)

EXAMPLES:
    # Download Docker Compose (on internet-connected machine)
    $0 download

    # Download specific version
    $0 download -v v2.23.3 -a aarch64

    # Transfer to remote machine
    $0 transfer -u myuser -h 192.168.1.100

    # Install on local machine (offline)
    $0 install

    # Install from custom directory
    $0 install -d /path/to/binaries
EOF
}

# Function to detect architecture
detect_architecture() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "x86_64"
            ;;
        aarch64|arm64)
            echo "aarch64"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate version format
validate_version() {
    if [[ ! $1 =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid version format: $1. Expected format: vX.Y.Z (e.g., v2.24.1)"
        exit 1
    fi
}

# Function to download Docker Compose
download_compose() {
    print_status "Starting Docker Compose download process..."
    
    # Validate version format
    validate_version "$COMPOSE_VERSION"
    
    # Check for required tools
    if ! command_exists wget && ! command_exists curl; then
        print_error "Neither wget nor curl is available. Please install one of them."
        exit 1
    fi
    
    # Create download directory
    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR"
    
    local compose_url="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${ARCHITECTURE}"
    local checksum_url="${compose_url}.sha256"
    local binary_name="docker-compose"
    
    print_status "Downloading Docker Compose ${COMPOSE_VERSION} for ${ARCHITECTURE}..."
    
    # Download binary
    if command_exists wget; then
        wget -O "$binary_name" "$compose_url" || {
            print_error "Failed to download Docker Compose binary"
            exit 1
        }
        wget -O "${binary_name}.sha256" "$checksum_url" 2>/dev/null || {
            print_warning "Could not download checksum file"
        }
    else
        curl -L -o "$binary_name" "$compose_url" || {
            print_error "Failed to download Docker Compose binary"
            exit 1
        }
        curl -L -o "${binary_name}.sha256" "$checksum_url" 2>/dev/null || {
            print_warning "Could not download checksum file"
        }
    fi
    
    # Make binary executable
    chmod +x "$binary_name"
    
    # Verify checksum if available
    if [[ -f "${binary_name}.sha256" ]]; then
        print_status "Verifying checksum..."
        if command_exists sha256sum; then
            local expected_sum=$(cat "${binary_name}.sha256" | cut -d' ' -f1)
            local actual_sum=$(sha256sum "$binary_name" | cut -d' ' -f1)
            if [[ "$expected_sum" == "$actual_sum" ]]; then
                print_success "Checksum verification passed"
            else
                print_error "Checksum verification failed!"
                print_error "Expected: $expected_sum"
                print_error "Actual: $actual_sum"
                exit 1
            fi
        else
            print_warning "sha256sum not available, skipping checksum verification"
        fi
    fi
    
    # Create installation script for offline machine
    create_install_script
    
    print_success "Download completed successfully!"
    print_status "Files downloaded to: $(pwd)"
    print_status "Transfer these files to your offline machine and run: ./install-on-offline.sh"
}

# Function to create installation script for offline machine
create_install_script() {
    cat > install-on-offline.sh << 'OFFLINE_SCRIPT'
#!/bin/bash

# Docker Compose installation script for offline machine
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

INSTALL_DIR="/usr/local/bin"
BINARY_NAME="docker-compose"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-i|--install-dir DIR]"
            echo "Install Docker Compose from local binary"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_status "Installing Docker Compose to offline machine..."

# Check if binary exists
if [[ ! -f "$BINARY_NAME" ]]; then
    print_error "Docker Compose binary not found in current directory!"
    print_error "Expected file: $BINARY_NAME"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker >/dev/null 2>&1; then
    print_error "Docker is not installed or not in PATH!"
    print_error "Please install Docker first."
    exit 1
fi

# Check Docker service
if ! docker info >/dev/null 2>&1; then
    print_error "Docker service is not running or user lacks permissions!"
    print_error "Try: sudo systemctl start docker"
    print_error "Or add user to docker group: sudo usermod -aG docker \$USER"
    exit 1
fi

# Create install directory if it doesn't exist
sudo mkdir -p "$INSTALL_DIR"

# Check if docker-compose already exists
if [[ -f "$INSTALL_DIR/$BINARY_NAME" ]]; then
    local existing_version=$(docker-compose --version 2>/dev/null || echo "unknown")
    print_status "Existing Docker Compose found: $existing_version"
    read -p "Do you want to replace it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Installation cancelled by user"
        exit 0
    fi
fi

# Install binary
print_status "Installing Docker Compose binary..."
sudo cp "$BINARY_NAME" "$INSTALL_DIR/"
sudo chmod +x "$INSTALL_DIR/$BINARY_NAME"

# Create symlink for compatibility
if [[ "$INSTALL_DIR" != "/usr/bin" ]]; then
    sudo ln -sf "$INSTALL_DIR/$BINARY_NAME" "/usr/bin/$BINARY_NAME" 2>/dev/null || true
fi

# Verify installation
print_status "Verifying installation..."
if command -v docker-compose >/dev/null 2>&1; then
    local version=$(docker-compose --version)
    print_success "Docker Compose installed successfully!"
    print_success "Version: $version"
    
    # Test basic functionality
    print_status "Testing basic functionality..."
    if docker-compose version >/dev/null 2>&1; then
        print_success "Docker Compose is working correctly!"
    else
        print_error "Docker Compose installation may have issues"
        exit 1
    fi
else
    print_error "Docker Compose installation failed!"
    exit 1
fi

print_success "Installation completed successfully!"
print_status "You can now use 'docker-compose' command"
OFFLINE_SCRIPT

    chmod +x install-on-offline.sh
    print_success "Created offline installation script: install-on-offline.sh"
}

# Function to transfer files to remote machine
transfer_files() {
    if [[ -z "$REMOTE_USER" || -z "$REMOTE_HOST" ]]; then
        print_error "Remote user and host must be specified for transfer"
        print_error "Use: $0 transfer -u username -h hostname"
        exit 1
    fi
    
    if [[ ! -d "$DOWNLOAD_DIR" ]]; then
        print_error "Download directory not found: $DOWNLOAD_DIR"
        print_error "Run '$0 download' first"
        exit 1
    fi
    
    if ! command_exists scp; then
        print_error "scp command not found. Please install openssh-client"
        exit 1
    fi
    
    print_status "Transferring files to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"
    
    # Create remote directory
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p $REMOTE_PATH" || {
        print_error "Failed to create remote directory"
        exit 1
    }
    
    # Transfer files
    scp -r "$DOWNLOAD_DIR"/* "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/" || {
        print_error "Failed to transfer files"
        exit 1
    }
    
    print_success "Files transferred successfully!"
    print_status "Connect to remote machine and run:"
    print_status "  ssh ${REMOTE_USER}@${REMOTE_HOST}"
    print_status "  cd $REMOTE_PATH"
    print_status "  ./install-on-offline.sh"
}

# Function to install Docker Compose locally
install_compose() {
    local binary_path="$DOWNLOAD_DIR/docker-compose"
    
    # If we're in the download directory, look for binary in current directory
    if [[ -f "./docker-compose" ]]; then
        binary_path="./docker-compose"
    elif [[ -f "docker-compose" ]]; then
        binary_path="docker-compose"
    elif [[ ! -f "$binary_path" ]]; then
        print_error "Docker Compose binary not found!"
        print_error "Expected locations:"
        print_error "  - $binary_path"
        print_error "  - ./docker-compose"
        print_error "  - docker-compose"
        exit 1
    fi
    
    print_status "Installing Docker Compose from: $binary_path"
    
    # Check if Docker is installed
    if ! command_exists docker; then
        print_error "Docker is not installed or not in PATH!"
        exit 1
    fi
    
    # Check Docker service
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker service is not running or user lacks permissions!"
        print_error "Try: sudo systemctl start docker"
        print_error "Or add user to docker group: sudo usermod -aG docker $USER"
        exit 1
    fi
    
    # Install binary
    sudo mkdir -p "$INSTALL_DIR"
    sudo cp "$binary_path" "$INSTALL_DIR/docker-compose"
    sudo chmod +x "$INSTALL_DIR/docker-compose"
    
    # Create symlink for compatibility
    if [[ "$INSTALL_DIR" != "/usr/bin" ]]; then
        sudo ln -sf "$INSTALL_DIR/docker-compose" "/usr/bin/docker-compose" 2>/dev/null || true
    fi
    
    # Verify installation
    if command_exists docker-compose; then
        local version=$(docker-compose --version)
        print_success "Docker Compose installed successfully!"
        print_success "Version: $version"
    else
        print_error "Docker Compose installation failed!"
        exit 1
    fi
}

# Parse command line arguments
COMMAND=""
while [[ $# -gt 0 ]]; do
    case $1 in
        download|install|transfer|help)
            COMMAND="$1"
            shift
            ;;
        -v|--version)
            COMPOSE_VERSION="$2"
            shift 2
            ;;
        -a|--arch)
            ARCHITECTURE="$2"
            shift 2
            ;;
        -d|--download-dir)
            DOWNLOAD_DIR="$2"
            shift 2
            ;;
        -i|--install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -u|--user)
            REMOTE_USER="$2"
            shift 2
            ;;
        -h|--host)
            REMOTE_HOST="$2"
            shift 2
            ;;
        -p|--path)
            REMOTE_PATH="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Auto-detect architecture if not specified
if [[ "$ARCHITECTURE" == "x86_64" ]]; then
    DETECTED_ARCH=$(detect_architecture)
    if [[ "$DETECTED_ARCH" != "$ARCHITECTURE" ]]; then
        print_warning "Detected architecture ($DETECTED_ARCH) differs from default ($ARCHITECTURE)"
        print_status "Using detected architecture: $DETECTED_ARCH"
        ARCHITECTURE="$DETECTED_ARCH"
    fi
fi

# Execute command
case $COMMAND in
    download)
        download_compose
        ;;
    install)
        install_compose
        ;;
    transfer)
        transfer_files
        ;;
    help|"")
        show_usage
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac 