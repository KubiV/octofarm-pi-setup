#!/bin/bash

# Local Installation Script for Raspberry Pi Setup
# Use this when you have all files locally (downloaded ZIP or cloned repo)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Check for required files
check_file() {
    local file="$1"
    if [ ! -f "$SCRIPT_DIR/$file" ]; then
        error "Required file not found: $file"
        return 1
    fi
}

# Welcome message
clear
echo -e "${BLUE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║           Raspberry Pi All-in-One Setup Script           ║
║                      (Local Version)                     ║
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

# Check for required files
log "Checking for required files..."
REQUIRED_FILES=(
    "modules/system-setup.sh"
    "modules/docker-setup.sh"
    "modules/camera-setup.sh"
    "modules/samba-setup.sh"
    "modules/relay-setup.sh"
    "relay_web.py"
    "docker-compose.yaml"
    "startup.sh"
)

OPTIONAL_FILES=(
    "modules/wifi-setup.sh"
    "modules/tailscale-setup.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
    if ! check_file "$file"; then
        error "Missing required files. Please ensure you have the complete installation package."
        exit 1
    fi
done

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
INSTALL_WIFI="n"
INSTALL_TAILSCALE="n"

if check_file "modules/wifi-setup.sh" 2>/dev/null; then
    read -p "Install TP-Link WiFi driver (RTL88x2BU)? (y/N): " -n 1 -r INSTALL_WIFI
    echo
else
    warn "WiFi setup module not found, skipping..."
fi

if check_file "modules/tailscale-setup.sh" 2>/dev/null; then
    read -p "Install Tailscale VPN? (y/N): " -n 1 -r INSTALL_TAILSCALE
    echo
else
    warn "Tailscale setup module not found, skipping..."
fi

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

# Create working directory and copy files
log "Setting up installation directory..."
mkdir -p "$HOME/rpi-setup"
cd "$HOME/rpi-setup"

# Copy all required files
for file in "${REQUIRED_FILES[@]}"; do
    mkdir -p "$(dirname "$file")"
    cp "$SCRIPT_DIR/$file" "$file"
    chmod +x "$file"
done

# Copy optional files if they exist and are selected
if [[ $INSTALL_WIFI =~ ^[Yy]$ ]] && check_file "modules/wifi-setup.sh" 2>/dev/null; then
    cp "$SCRIPT_DIR/modules/wifi-setup.sh" "modules/wifi-setup.sh"
    chmod +x "modules/wifi-setup.sh"
fi

if [[ $INSTALL_TAILSCALE =~ ^[Yy]$ ]] && check_file "modules/tailscale-setup.sh" 2>/dev/null; then
    cp "$SCRIPT_DIR/modules/tailscale-setup.sh" "modules/tailscale-setup.sh"
    chmod +x "modules/tailscale-setup.sh"
fi

log "Starting installation process..."

# Execute installation modules
log "Running system setup..."
bash "$HOME/rpi-setup/modules/system-setup.sh"

log "Setting up Docker..."
bash "$HOME/rpi-setup/modules/docker-setup.sh"

log "Configuring camera support..."
bash "$HOME/rpi-setup/modules/camera-setup.sh"

log "Setting up Samba file sharing..."
bash "$HOME/rpi-setup/modules/samba-setup.sh"

log "Installing relay web interface..."
bash "$HOME/rpi-setup/modules/relay-setup.sh"

if [[ $INSTALL_WIFI =~ ^[Yy]$ ]]; then
    log "Installing TP-Link WiFi driver..."
    sudo bash "$HOME/rpi-setup/modules/wifi-setup.sh"
fi

if [[ $INSTALL_TAILSCALE =~ ^[Yy]$ ]]; then
    log "Setting up Tailscale..."
    bash "$HOME/rpi-setup/modules/tailscale-setup.sh"
fi

# Set up startup script
log "Configuring startup script..."
cp "$HOME/rpi-setup/startup.sh" "$HOME/startup.sh"
chmod +x "$HOME/startup.sh"

# Add to crontab if not already present
if ! crontab -l 2>/dev/null | grep -q "startup.sh"; then
    (crontab -l 2>/dev/null; echo "@reboot $HOME/startup.sh >> $HOME/startup.log 2>&1") | crontab -
    log "Startup script added to crontab"
fi

# Final setup
log "Setting up Docker Compose services..."
cd "$HOME/rpi-setup"

# Pull Docker images (may fail if not logged into Docker group yet, that's ok)
docker compose pull || warn "Could not pull Docker images yet - will happen after reboot"

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