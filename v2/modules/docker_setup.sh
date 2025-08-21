#!/bin/bash

# Docker Setup Module
# Installs Docker and Docker Compose

set -e

log() {
    echo "[$(date '+%H:%M:%S')] DOCKER: $1"
}

log "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

log "Adding user '$USER' to docker group..."
sudo usermod -aG docker "$USER"

log "Enabling and starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

log "Installing Docker Compose plugin..."

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    "aarch64")
        PLATFORM="aarch64"
        ;;
    "armv7l")
        PLATFORM="armv7"
        ;;
    "x86_64")
        PLATFORM="x86_64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Create plugin directory
mkdir -p ~/.docker/cli-plugins/

# Download and install Docker Compose plugin
log "Downloading Docker Compose for $PLATFORM..."
curl -SL "https://github.com/docker/compose/releases/download/v2.24.7/docker-compose-linux-$PLATFORM" \
    -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose

# Add to PATH if not already present
if ! echo "$PATH" | grep -q "$HOME/.docker/cli-plugins"; then
    echo 'export PATH="$HOME/.docker/cli-plugins:$PATH"' >> ~/.bashrc
    export PATH="$HOME/.docker/cli-plugins:$PATH"
fi

log "Docker installation completed"

# Test Docker (without requiring group membership to be active)
if sudo docker --version >/dev/null 2>&1; then
    log "Docker version: $(sudo docker --version)"
else
    echo "WARNING: Docker installation may have issues"
fi

log "Docker setup completed successfully"
log "Note: You may need to log out and back in for group membership to take effect"