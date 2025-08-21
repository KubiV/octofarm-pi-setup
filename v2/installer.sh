#!/bin/bash

# Main Installation Script for Raspberry Pi Setup
# Usage: curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main"

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
    if [ ! -f "$SCRIPT_DIR/$script_name" ]; then
        log "Downloading $script_name..."
        curl -sSL "$REPO_URL/$script_name" -o "$SCRIPT_DIR/$script_name"
        chmod +x "$SCRIPT_DIR/$script_name"
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