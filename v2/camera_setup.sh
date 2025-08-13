#!/bin/bash

# Camera Setup Module
# Configures Pi Camera support

set -e

log() {
    echo "[$(date '+%H:%M:%S')] CAMERA: $1"
}

log "Loading bcm2835-v4l2 module..."
sudo modprobe bcm2835-v4l2

log "Creating camera module configuration..."
cat <<EOF | sudo tee /etc/modules-load.d/camera.conf
bcm2835-v4l2
EOF

log "Checking for camera devices..."
if [ -e /dev/video0 ]; then
    log "Camera device /dev/video0 detected"
else
    log "WARNING: Camera device /dev/video0 not found. Camera may not be connected or enabled."
fi

# Add user to video group for camera access
sudo usermod -a -G video "$USER"

log "Camera setup completed successfully"
log "Note: If camera is not working, ensure it's enabled in raspi-config"