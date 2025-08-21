#!/bin/bash

# Main Installation Script for Raspberry Pi Setup
# Usage: curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main"

# TODO: Update these URLs before using!
# Replace YOUR_USERNAME with your GitHub username
# Replace YOUR_REPO with your repository name
# Example: REPO_URL="https://raw.githubusercontent.com/johndoe/rpi-setup/main"

# Check if REPO_URL still contains placeholder values
if [[ "$REPO_URL" == *"YOUR_USERNAME"* ]] || [[ "$REPO_URL" == *"YOUR_REPO"* ]]; then
    error "Repository URL not configured!"
    error "Please update the REPO_URL variable in this script with your actual GitHub repository details."
    error "Current URL: $REPO_URL"
    echo
    info "If you're running this locally, the script will look for files in the same directory instead."
    REPO_URL="file://$(pwd)"
    warn "Switching to local file mode..."
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to download a script if not present
download_script() {
    local script_name="$1"
    local target_path="$SCRIPT_DIR/$script_name"
    local target_dir=$(dirname "$target_path")
    
    # Create directory if it doesn't exist
    mkdir -p "$target_dir"
    
    if [ ! -f "$target_path" ]; then
        # Check if we're in local mode
        if [[ "$REPO_URL" == "file://"* ]]; then
            local local_path="$(pwd)/$script_name"
            if [ -f "$local_path" ]; then
                log "Copying local file $script_name..."
                cp "$local_path" "$target_path"
                chmod +x "$target_path"
            else
                error "Local file not found: $local_path"
                exit 1
            fi
        else
            log "Downloading $script_name..."
            if curl -sSL "$REPO_URL/$script_name" -o "$target_path"; then
                chmod +x "$target_path"
                log "Successfully downloaded $script_name"
            else
                error "Failed to download $script_name from $REPO_URL/$script_name"
                error "This usually means:"
                error "1. The repository URL is incorrect"
                error "2. The file doesn't exist in the repository"
                error "3. Network connectivity issues"
                echo
                info "Please check that you've updated the REPO_URL variable in this script"
                info "Current REPO_URL: $REPO_URL"
                exit 1
            fi
        fi
    fi
}

# Welcome message
clear
echo -e "${BLUE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║           Raspberry Pi All-in-One Setup Script           ║
║                                                           ║
║  This script will install and configure:                 ║
║  • Docker + Docker Compose                               ║
║  • OctoPrint + OctoFarm setup                           ║
║  • Camera support (Pi Camera)                           ║
║  • Samba file sharing                                    ║
║  • Relay web interface                                   ║
║  • Optional: TP-Link WiFi driver                        ║
║  • Optional: Tailscale VPN                              ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should NOT be run as root. Please run as regular user with sudo privileges."
   exit 1
fi

# Check if user has sudo privileges
if ! sudo -n true 2>/dev/null; then
    error "This script requires sudo privileges. Please run with a user that has sudo access."
    exit 1
fi

echo
read -p "Do you want to continue with the installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# Interactive selection
echo
info "Select components to install:"
echo

# Basic components (always installed)
echo "✓ System updates and basic packages"
echo "✓ Docker + Docker Compose"
echo "✓ OctoPrint + OctoFarm setup"
echo "✓ Pi Camera support"
echo "✓ Samba file sharing"
echo "✓ Relay web interface"
echo

# Optional components
read -p "Install TP-Link WiFi driver (RTL88x2BU)? (y/N): " -n 1 -r INSTALL_WIFI
echo
read -p "Install Tailscale VPN? (y/N): " -n 1 -r INSTALL_TAILSCALE
echo

# Confirmation
echo
info "Installation summary:"
echo "• Basic system setup: YES"
echo "• Docker ecosystem: YES"
echo "• TP-Link WiFi driver: $([ "$INSTALL_WIFI" = "y" ] && echo "YES" || echo "NO")"
echo "• Tailscale VPN: $([ "$INSTALL_TAILSCALE" = "y" ] && echo "YES" || echo "NO")"
echo

read -p "Proceed with installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# Create working directory
mkdir -p "$HOME/rpi-setup"
cd "$HOME/rpi-setup"
SCRIPT_DIR="$HOME/rpi-setup"

log "Starting installation process..."

# Download required scripts
log "Downloading installation scripts..."
download_script "modules/system-setup.sh"
download_script "modules/docker-setup.sh"
download_script "modules/camera-setup.sh"
download_script "modules/samba-setup.sh"
download_script "modules/relay-setup.sh"
download_script "relay_web.py"
download_script "docker-compose.yaml"
download_script "startup.sh"

if [[ $INSTALL_WIFI =~ ^[Yy]$ ]]; then
    download_script "modules/wifi-setup.sh"
fi

if [[ $INSTALL_TAILSCALE =~ ^[Yy]$ ]]; then
    download_script "modules/tailscale-setup.sh"
fi

# Execute installation modules
log "Running system setup..."
bash "$SCRIPT_DIR/modules/system-setup.sh"

log "Setting up Docker..."
bash "$SCRIPT_DIR/modules/docker-setup.sh"

log "Configuring camera support..."
bash "$SCRIPT_DIR/modules/camera-setup.sh"

log "Setting up Samba file sharing..."
bash "$SCRIPT_DIR/modules/samba-setup.sh"

log "Installing relay web interface..."
bash "$SCRIPT_DIR/modules/relay-setup.sh"

if [[ $INSTALL_WIFI =~ ^[Yy]$ ]]; then
    log "Installing TP-Link WiFi driver..."
    sudo bash "$SCRIPT_DIR/modules/wifi-setup.sh"
fi

if [[ $INSTALL_TAILSCALE =~ ^[Yy]$ ]]; then
    log "Setting up Tailscale..."
    bash "$SCRIPT_DIR/modules/tailscale-setup.sh"
fi

# Set up startup script
log "Configuring startup script..."
cp "$SCRIPT_DIR/startup.sh" "$HOME/startup.sh"
chmod +x "$HOME/startup.sh"

# Add to crontab if not already present
if ! crontab -l 2>/dev/null | grep -q "startup.sh"; then
    (crontab -l 2>/dev/null; echo "@reboot $HOME/startup.sh >> $HOME/startup.log 2>&1") | crontab -
    log "Startup script added to crontab"
fi

# Final setup
log "Setting up Docker Compose services..."
cd "$HOME/rpi-setup"
docker compose pull

log "Creating required directories..."
mkdir -p "$HOME/share"
mkdir -p "$HOME/rpi-setup/logs"

# Final message
echo
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗"
echo -e "║                   Installation Complete!                 ║"
echo -e "╚═══════════════════════════════════════════════════════════╝${NC}"
echo
info "Services will be available at:"
echo "• OctoFarm: http://$(hostname -I | awk '{print $1}'):4000"
echo "• OctoPrint 1: http://$(hostname -I | awk '{print $1}'):5001"
echo "• OctoPrint 2: http://$(hostname -I | awk '{print $1}'):5002"
echo "• Relay Control: http://$(hostname -I | awk '{print $1}'):8080"
echo "• Camera Stream: http://$(hostname -I | awk '{print $1}'):8081"
echo "• Samba Share: \\\\$(hostname -I | awk '{print $1}')\\pi-share"
echo
warn "A reboot is recommended to ensure all changes take effect."
read -p "Reboot now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo reboot
fi