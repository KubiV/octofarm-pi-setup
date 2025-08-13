# Raspberry Pi All-in-One Setup

Complete automation setup for Raspberry Pi with OctoPrint, OctoFarm, cameras, relay control, and optional networking components.

## 🚀 Quick Start

### Prerequisites
- Fresh Raspberry Pi OS installation
- SSH access to your Raspberry Pi
- Internet connection

### Installation
```bash
# Download and run the setup script
wget https://raw.githubusercontent.com/YOUR_REPO/main/all-in-one-setup.sh
chmod +x all-in-one-setup.sh
sudo ./all-in-one-setup.sh
```

Or copy the script manually:
```bash
nano all-in-one-setup.sh
# Paste the script content
chmod +x all-in-one-setup.sh
sudo ./all-in-one-setup.sh
```

## 📦 What's Included

### Core Components (Always Installed)
- 🐳 **Docker & Docker Compose** - Container platform
- 🖨️ **OctoPrint** - 3D printer management (2 instances)
- 🌾 **OctoFarm** - Multi-printer dashboard
- 📷 **MJPG Streamer** - Camera streaming
- 🗃️ **MongoDB** - Database for OctoFarm
- 📁 **Samba** - File sharing (/home/pi/share)
- 📷 **Camera Support** - Raspberry Pi camera module
- ⚡ **Startup Scripts** - Automated relay control

### Optional Components (Interactive Selection)
- 🌐 **Tailscale** - Secure VPN access
- 📶 **TP-Link WiFi Module** - RTL88x2BU driver with dual WiFi setup
- 🔌 **Relay Web Interface** - Web-based relay control

## 🎯 Service Ports

| Service | Port | Description |
|---------|------|-------------|
| OctoFarm | 4000 | Multi-printer dashboard |
| OctoPrint 1 | 5001 | First printer interface |
| OctoPrint 2 | 5002 | Second printer interface |
| MJPG Streamer | 8081 | Camera stream |
| Relay Web | 8080 | Relay control (if installed) |
| MongoDB | 27017 | Database (internal) |
| Samba | 445 | File sharing |

## 🔧 Post-Installation Configuration

### 1. Samba Password Setup
```bash
sudo smbpasswd -a pi
```

### 2. WiFi Configuration (if TP-Link module installed)
```bash
sudo nano /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
sudo nano /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
```

Replace placeholder values:
- `CHANGE_THIS_SSID` → Your WiFi network name
- `CHANGE_THIS_PASSWORD` → Your WiFi password

### 3. USB Device Configuration
Find your device IDs:
```bash
ls -l /dev/serial/by-id/
```

Update Docker Compose:
```bash
nano /home/pi/docker-config/docker-compose.yaml
```

### 4. Auto-Start Setup (Optional)
```bash
sudo crontab -e
```
Add: `@reboot /home/pi/startup.sh >> /home/pi/startup.log 2>&1`

### 5. Start Services
```bash
cd /home/pi/docker-config
docker compose up -d
```

### 6. Tailscale Setup (if installed)
```bash
sudo tailscale up
```

## 📁 File Structure

```
/home/pi/
├── docker-config/
│   └── docker-compose.yaml      # Main Docker configuration
├── share/                       # Samba shared folder
├── startup.sh                   # Boot startup script
├── relay_web.py                 # Relay web interface (if installed)
├── relay_env/                   # Python virtual environment (if installed)
└── startup.log                  # Startup script logs

/etc/wpa_supplicant/             # WiFi configurations (if installed)
├── wpa_supplicant-wlan0.conf    # Backup WiFi network
└── wpa_supplicant-wlan1.conf    # Primary WiFi network
```

## 🌐 Access Your Services

### Local Network Access
- **OctoFarm Dashboard**: `http://[PI_IP]:4000`
- **OctoPrint 1**: `http://[PI_IP]:5001`
- **OctoPrint 2**: `http://[PI_IP]:5002`
- **Camera Stream**: `http://[PI_IP]:8081`
- **Relay Control**: `http://[PI_IP]:8080` (if installed)
- **Samba Share**: `\\[PI_IP]\pi-share`

### Remote Access (if Tailscale installed)
Access all services using your Tailscale IP instead of local IP.

## 🔍 Monitoring & Troubleshooting

### Check Service Status
```bash
# Docker services
docker ps
docker compose logs

# Relay web service
sudo systemctl status relay_web
sudo journalctl -u relay_web -f

# WiFi status
iwconfig
sudo systemctl status wpa_supplicant@wlan1

# Startup logs
cat /home/pi/startup.log
```

### Common Issues

**Docker services not starting:**
```bash
cd /home/pi/docker-config
docker compose down
docker compose up -d
```

**WiFi not connecting:**
```bash
sudo systemctl restart wpa_supplicant@wlan1
sudo systemctl restart dhcpcd
```

**USB devices not detected:**
```bash
ls -l /dev/serial/by-id/
dmesg | tail
```

## ⚙️ Hardware Setup

### Recommended Hardware
- Raspberry Pi 4 (4GB+ RAM recommended)
- MicroSD card (32GB+ Class 10)
- USB WiFi adapter (if using TP-Link module)
- USB relay module (if using relay control)
- Raspberry Pi camera or USB camera
- 3D printers with USB connectivity

### USB Device Connections
- **Relay Module**: Usually `/dev/ttyACM0`
- **3D Printers**: Check with `ls -l /dev/serial/by-id/`
- **Camera**: `/dev/video0` for USB cameras

## 🚦 Relay Control Features

The startup script automatically:
1. Powers on USB devices via relays
2. Waits for devices to be detected
3. Starts Docker services
4. Configures network settings
5. Powers down relays after initialization

Manual relay control available via web interface at port 8080.

## 🔄 Updates & Maintenance

### Update Docker Images
```bash
cd /home/pi/docker-config
docker compose pull
docker compose up -d
```

### Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### Backup Configuration
```bash
# Backup important configs
cp -r /home/pi/docker-config ~/backup/
cp /home/pi/startup.sh ~/backup/
cp /etc/wpa_supplicant/wpa_supplicant-*.conf ~/backup/
```

## 🛠️ Customization

### Adding More OctoPrint Instances
1. Edit `docker-compose.yaml`
2. Add new service with unique port and volume
3. Configure USB device mapping
4. Restart with `docker compose up -d`

### Custom Relay Commands
Edit `/home/pi/startup.sh` to modify relay behavior and timing.

### Network Priority
WiFi interface priorities (if dual WiFi setup):
- `wlan1`: Primary (metric 100)
- `wlan0`: Backup (metric 200)

## 📄 License

This project is provided as-is for educational and personal use.

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

---

**Note**: After installation, a system restart is recommended to ensure all modules and services load properly:
```bash
sudo reboot
```