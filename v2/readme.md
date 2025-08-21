# Raspberry Pi All-in-One Setup

This repository contains a modular installation system for setting up a complete Raspberry Pi environment with OctoPrint, OctoFarm, Docker, and various utilities.

## Quick Installation

### Method 1: Direct from GitHub (Recommended)

```bash
# Download and run the installer directly
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | bash
```

### Method 2: Clone and Install

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO

# Make installer executable and run
chmod +x install.sh
./install.sh
```

### Method 3: Download ZIP

1. Download the repository as ZIP
2. Extract to your Raspberry Pi
3. Navigate to the directory
4. Run: `chmod +x install.sh && ./install.sh`

## What Gets Installed

### Core Components (Always Installed)
- **System Updates**: Latest packages and security updates
- **Docker & Docker Compose**: Container runtime environment
- **OctoPrint**: 3D printer management (2 instances on ports 5001, 5002)
- **OctoFarm**: Multi-printer management dashboard (port 4000)
- **MongoDB**: Database for OctoFarm
- **Camera Support**: Pi Camera module support
- **MJPG Streamer**: Camera streaming (port 8081)
- **Samba**: File sharing service
- **Relay Controller**: Web interface for relay control (port 8080)

### Optional Components
- **TP-Link WiFi Driver**: RTL88x2BU driver for dual WiFi setup
- **Tailscale VPN**: Secure remote access

## Services and Ports

After installation, the following services will be available:

| Service | Port | URL |
|---------|------|-----|
| OctoFarm | 4000 | http://your-pi-ip:4000 |
| OctoPrint 1 | 5001 | http://your-pi-ip:5001 |
| OctoPrint 2 | 5002 | http://your-pi-ip:5002 |
| Relay Control | 8080 | http://your-pi-ip:8080 |
| Camera Stream | 8081 | http://your-pi-ip:8081 |
| MongoDB | 27017 | Internal use |

## File Structure

```
rpi-setup/
├── install.sh                 # Main installer script
├── modules/                   # Installation modules
│   ├── system-setup.sh       # System updates and basic packages
│   ├── docker-setup.sh       # Docker installation
│   ├── camera-setup.sh       # Camera configuration
│   ├── samba-setup.sh        # File sharing setup
│   ├── relay-setup.sh        # Relay controller setup
│   ├── wifi-setup.sh         # TP-Link WiFi driver (optional)
│   └── tailscale-setup.sh    # Tailscale VPN (optional)
├── relay_web.py              # Relay control web interface
├── docker-compose.yaml       # Docker services configuration
├── startup.sh               # System startup script
└── README.md                # This file
```
```
rpi-setup/
├── install-local.sh
├── modules/
│   ├── system-setup.sh
│   ├── docker-setup.sh
│   ├── camera-setup.sh
│   ├── samba-setup.sh
│   ├── relay-setup.sh
│   ├── wifi-setup.sh
│   └── tailscale-setup.sh
├── relay_web.py
├── docker-compose.yaml
└── startup.sh
```

## Requirements

- Raspberry Pi 4 (2GB RAM minimum, 4GB+ recommended)
- Raspberry Pi OS (Bullseye or newer)
- Internet connection
- User with sudo privileges (don't run as root)
- SD card with at least 16GB (32GB+ recommended)

## Hardware Setup

### Before Installation
1. **Enable Camera**: Run `sudo raspi-config` → Interface Options → Camera → Enable
2. **Enable SSH**: Run `sudo raspi-config` → Interface Options → SSH → Enable
3. **Connect Hardware**:
   - USB cameras/printers to USB ports
   - Relay controller to appropriate GPIO/USB
   - TP-Link WiFi adapter (if using)

### Serial Device Mapping
The installer includes pre-configured serial device mappings:
- OctoPrint 1: `/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0`
- OctoPrint 2: `/dev/serial/by-id/usb-STMicroelectronics_MARLIN_STM32G0B1RE_CDC_in_FS_Mode_203E345B4D41-if00`

**Important**: Update these in `docker-compose.yaml` to match your actual devices:
```bash
# Find your serial devices
ls -l /dev/serial/by-id/
```

## Configuration

### WiFi Setup (TP-Link Module)
If you choose to install the TP-Link WiFi driver, you'll be prompted to:
- Enter primary WiFi credentials (higher priority)
- Enter backup WiFi credentials (lower priority)
- Configure automatic failover between networks

### Samba File Sharing
- Share location: `/home/pi/share`
- Access via: `\\your-pi-ip\pi-share`
- You'll be prompted to set a Samba password during installation

### Relay Controller
- Supports 3 relays (R1, R2, R3)
- Web interface allows individual control
- Automatically starts on system boot

## Post-Installation

### First Steps
1. **Reboot**: Recommended after installation
2. **Test Services**: Visit each service URL to verify functionality
3. **Configure OctoPrint**: Complete initial setup for each instance
4. **Setup OctoFarm**: Add your OctoPrint instances

### Customization
- Edit `docker-compose.yaml` for service configuration changes
- Modify relay controller ports/settings in `relay_web.py`
- Adjust camera settings in the Docker compose file
- Update serial device paths to match your hardware

### Troubleshooting

#### Docker Issues
```bash
# Check Docker status
sudo systemctl status docker

# Restart Docker services
cd ~/rpi-setup
docker compose down
docker compose up -d

# Check logs
docker compose logs -f
```

#### Serial Device Issues
```bash
# List available serial devices
ls -l /dev/serial/by-id/
ls -l /dev/ttyUSB* /dev/ttyACM*

# Check device permissions
sudo usermod -a -G dialout $USER
```

#### Camera Issues
```bash
# Check camera detection
lsusb
ls /dev/video*

# Test camera
fswebcam test.jpg

# Enable Pi Camera (if using Pi Camera module)
sudo raspi-config # Interface Options > Camera > Enable
```

#### Network Issues
```bash
# Check network interfaces
ip addr show

# WiFi status
sudo wpa_cli status

# Restart networking
sudo systemctl restart dhcpcd
```

## Manual Service Management

### Starting/Stopping Services
```bash
# All services
cd ~/rpi-setup
docker compose up -d    # Start all
docker compose down     # Stop all

# Individual services
docker compose up -d octoprint1
docker compose stop mongodb

# Relay service
sudo systemctl start relay_web.service
sudo systemctl stop relay_web.service
```

### Viewing Logs
```bash
# Docker services
docker compose logs -f octofarm
docker compose logs -f octoprint1

# Relay service
sudo journalctl -u relay_web.service -f

# System startup
tail -f ~/startup.log
```

## Security Considerations

### Default Credentials
- **MongoDB**: root/rootpassword (change in docker-compose.yaml)
- **Samba**: pi user with custom password
- **Services**: No default authentication (add reverse proxy if needed)

### Recommended Security Steps
1. Change default MongoDB credentials
2. Set up firewall (ufw)
3. Configure HTTPS with reverse proxy
4. Use Tailscale for secure remote access
5. Regularly update system packages

### Firewall Setup (Optional)
```bash
# Install and configure ufw
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow ssh

# Allow local network access to services
sudo ufw allow from 192.168.1.0/24 to any port 4000,5001,5002,8080,8081

# Enable firewall
sudo ufw enable
```

## Advanced Configuration

### Custom Docker Images
To use different Docker images, edit `docker-compose.yaml`:
```yaml
services:
  octoprint1:
    image: your-custom-octoprint:latest
    # ... rest of configuration
```

### Multiple Camera Support
Add additional cameras to `docker-compose.yaml`:
```yaml
  mjpg-streamer-cam2:
    image: openhorizon/mjpg-streamer-pi3
    container_name: mjpg-streamer-cam2
    devices:
      - /dev/video1:/dev/video1
    ports:
      - 8082:8080
    command: >
      ./mjpg_streamer
      -i "input_uvc.so -d /dev/video1 -r 1280x720 -f 30"
      -o "output_http.so -p 8080 -w ./www"
```

### Custom Startup Scripts
Add custom commands to `startup.sh`:
```bash
# Add your custom startup commands before the final disable_relays
log "Running custom startup tasks..."
# Your custom commands here
```

## Backup and Restore

### Backup Important Data
```bash
# Create backup directory
mkdir ~/backup

# Backup Docker volumes
docker run --rm -v mongodb-data:/data -v ~/backup:/backup alpine tar czf /backup/mongodb-backup.tar.gz -C /data .
docker run --rm -v octoprint1-data:/data -v ~/backup:/backup alpine tar czf /backup/octoprint1-backup.tar.gz -C /data .

# Backup configuration files
cp ~/rpi-setup/docker-compose.yaml ~/backup/
cp ~/startup.sh ~/backup/
cp ~/.bashrc ~/backup/
```

### Restore from Backup
```bash
# Stop services
cd ~/rpi-setup
docker compose down

# Restore volumes
docker run --rm -v mongodb-data:/data -v ~/backup:/backup alpine tar xzf /backup/mongodb-backup.tar.gz -C /data
docker run --rm -v octoprint1-data:/data -v ~/backup:/backup alpine tar xzf /backup/octoprint1-backup.tar.gz -C /data

# Start services
docker compose up -d
```

## Development and Modification

### File Locations
- **Installation scripts**: `~/rpi-setup/modules/`
- **Service configs**: `~/rpi-setup/docker-compose.yaml`
- **Logs**: `~/rpi-setup/logs/`, `~/startup.log`
- **Samba share**: `~/share/`

### Making Changes
1. **Service changes**: Edit `docker-compose.yaml` and run `docker compose up -d`
2. **Module changes**: Edit files in `modules/` directory
3. **Relay interface**: Modify `relay_web.py` and restart service

### Contributing
1. Fork the repository
2. Make your changes
3. Test thoroughly on a clean Raspberry Pi
4. Submit a pull request

## Getting Help

### Common Issues and Solutions

**Issue: Services not starting after reboot**
```bash
# Check startup script
cat ~/startup.log

# Manually start services
cd ~/rpi-setup
docker compose up -d
```

**Issue: OctoPrint can't connect to printer**
```bash
# Check serial devices
ls -l /dev/serial/by-id/

# Update docker-compose.yaml with correct device path
# Restart affected service
```

**Issue: Camera not detected**
```bash
# For Pi Camera
sudo raspi-config # Enable camera interface

# For USB cameras
lsusb
# Update device path in docker-compose.yaml
```

### Support Resources
- [OctoPrint Documentation](https://docs.octoprint.org/)
- [OctoFarm Wiki](https://github.com/OctoFarm/OctoFarm/wiki)
- [Docker Documentation](https://docs.docker.com/)
- [Raspberry Pi Documentation](https://www.raspberrypi.org/documentation/)

## License

This project is released under the MIT License. See individual component licenses for specific terms.