# Quick Installation Guide

## One-Line Installation

SSH into your Raspberry Pi and run:

```bash
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | bash
```

**Replace `YOUR_USERNAME/YOUR_REPO` with your actual GitHub repository details.**

## Alternative Methods

### Method 1: Download Specific Files (Minimal Download)

If you don't want to clone the entire repository, you can download just the installer:

```bash
# Download main installer
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh

# Make executable
chmod +x install.sh

# Run installer (it will download other files as needed)
./install.sh
```

### Method 2: Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO
chmod +x install.sh
./install.sh
```

### Method 3: Download as ZIP

1. Visit: `https://github.com/YOUR_USERNAME/YOUR_REPO/archive/refs/heads/main.zip`
2. Download and extract on your Pi
3. Navigate to extracted folder
4. Run: `chmod +x install.sh && ./install.sh`

## Prerequisites

- Raspberry Pi 4 with Raspberry Pi OS
- Internet connection
- User with sudo privileges
- At least 16GB SD card (32GB recommended)

## What to Expect

1. **System Update**: ~5-10 minutes
2. **Interactive Setup**: You'll be asked about:
   - TP-Link WiFi driver installation
   - Tailscale VPN installation
   - WiFi network credentials (if installing WiFi driver)
   - Samba password
3. **Installation Time**: 15-30 minutes total
4. **Reboot**: Recommended at the end

## After Installation

Your services will be available at:
- **OctoFarm**: `http://your-pi-ip:4000`
- **OctoPrint 1**: `http://your-pi-ip:5001`  
- **OctoPrint 2**: `http://your-pi-ip:5002`
- **Relay Control**: `http://your-pi-ip:8080`
- **Camera Stream**: `http://your-pi-ip:8081`

## Troubleshooting

If installation fails:

```bash
# Check what went wrong
tail ~/startup.log

# Restart manually
cd ~/rpi-setup
docker compose up -d

# Check service status
docker compose ps
```

## Getting Your Pi's IP Address

```bash
hostname -I | awk '{print $1}'
```

## Need Help?

See the full [README.md](README.md) for detailed documentation and troubleshooting.