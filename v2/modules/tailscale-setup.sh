#!/bin/bash

# Tailscale Setup Module
# Installs and configures Tailscale VPN

set -e

log() {
    echo "[$(date '+%H:%M:%S')] TAILSCALE: $1"
}

log "Installing Tailscale repository key..."
curl -fsSL https://pkgs.tailscale.com/stable/raspbian/bullseye.noarmor.gpg | \
    sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null

log "Adding Tailscale repository..."
curl -fsSL https://pkgs.tailscale.com/stable/raspbian/bullseye.tailscale-keyring.list | \
    sudo tee /etc/apt/sources.list.d/tailscale.list > /dev/null

log "Updating package list..."
sudo apt update

log "Installing Tailscale..."
sudo apt install -y tailscale

log "Starting Tailscale..."
echo "Please follow the instructions to authenticate your device:"
sudo tailscale up

# Check if Tailscale is running
if sudo tailscale status >/dev/null 2>&1; then
    log "Tailscale is running successfully"
    TAILSCALE_IP=$(sudo tailscale ip -4 2>/dev/null || echo "Not available")
    log "Tailscale IP: $TAILSCALE_IP"
else
    log "WARNING: Tailscale may not be running properly"
fi

log "Tailscale setup completed successfully"
log "You can check status with: sudo tailscale status"