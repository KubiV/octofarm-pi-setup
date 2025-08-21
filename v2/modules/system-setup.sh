#!/bin/bash

# System Setup Module
# Updates system and installs basic packages

set -e

log() {
    echo "[$(date '+%H:%M:%S')] SYSTEM: $1"
}

log "Updating system packages..."
sudo apt update
sudo apt full-upgrade -y

log "Installing basic development packages..."
sudo apt install -y \
    build-essential \
    libjpeg-dev \
    libjpeg62-turbo-dev \
    imagemagick \
    libv4l-dev \
    cmake \
    git \
    curl \
    wget \
    unzip \
    htop \
    vim \
    ffmpeg \
    fswebcam \
    python3 \
    python3-pip \
    python3-venv \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

log "System setup completed successfully"