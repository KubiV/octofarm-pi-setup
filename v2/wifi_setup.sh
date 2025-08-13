#!/bin/bash

# TP-Link WiFi Setup Module
# Installs RTL88x2BU driver and configures dual WiFi setup

set -e

log() {
    echo "[$(date '+%H:%M:%S')] WIFI: $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This WiFi setup script must be run as root (with sudo)."
   exit 1
fi

log "Installing WiFi driver dependencies..."
apt install -y git dkms build-essential raspberrypi-kernel-headers dhcpcd5

log "Removing systemd-networkd (replaced by dhcpcd)..."
systemctl stop systemd-networkd || true
systemctl disable systemd-networkd || true
rm -f /etc/systemd/network/*.network

log "Activating dhcpcd..."
systemctl enable dhcpcd
systemctl start dhcpcd

log "Installing RTL88x2BU driver..."
if [ -d "/usr/src/rtl88x2bu-git" ]; then
    log "Driver directory exists, removing old version..."
    rm -rf /usr/src/rtl88x2bu-git
fi

git clone "https://github.com/RinCat/RTL88x2BU-Linux-Driver.git" /usr/src/rtl88x2bu-git
cd /usr/src/rtl88x2bu-git
sed -i 's/PACKAGE_VERSION="@PKGVER@"/PACKAGE_VERSION="git"/g' dkms.conf
dkms add -m rtl88x2bu -v git
dkms autoinstall

log "Loading driver module..."
modprobe 88x2bu

log "Setting up network interface priorities..."
cat >> /etc/dhcpcd.conf <<EOF

# WiFi interface priorities (lower number = higher priority)
interface wlan1
    metric 100

interface wlan0
    metric 200
EOF

# Interactive WiFi configuration
echo
echo "WiFi Configuration Setup"
echo "========================="
echo
read -p "Enter SSID for primary WiFi (wlan1): " PRIMARY_SSID
read -s -p "Enter password for primary WiFi: " PRIMARY_PASS
echo
read -p "Enter SSID for backup WiFi (wlan0): " BACKUP_SSID
read -s -p "Enter password for backup WiFi: " BACKUP_PASS
echo

log "Configuring wpa_supplicant for wlan1 (primary)..."
cat > /etc/wpa_supplicant/wpa_supplicant-wlan1.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=CZ

network={
    ssid="$PRIMARY_SSID"
    psk="$PRIMARY_PASS"
    priority=10
    scan_ssid=1
}
EOF
chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan1.conf

log "Configuring wpa_supplicant for wlan0 (backup)..."
cat > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=CZ

network={
    ssid="$BACKUP_SSID"
    psk="$BACKUP_PASS"
    priority=5
    scan_ssid=1
}
EOF
chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan0.conf

log "Enabling wpa_supplicant services..."
systemctl enable wpa_supplicant@wlan1
systemctl enable wpa_supplicant@wlan0

log "Creating systemd service overrides..."
mkdir -p /etc/systemd/system/wpa_supplicant@wlan1.service.d
cat > /etc/systemd/system/wpa_supplicant@wlan1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/sbin/wpa_supplicant -c/etc/wpa_supplicant/wpa_supplicant-wlan1.conf -i wlan1 -D nl80211
EOF

mkdir -p /etc/systemd/system/wpa_supplicant@wlan0.service.d
cat > /etc/systemd/system/wpa_supplicant@wlan0.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/sbin/wpa_supplicant -c/etc/wpa_supplicant/wpa_supplicant-wlan0.conf -i wlan0 -D nl80211
EOF

log "Restarting network services..."
systemctl daemon-reload
systemctl restart wpa_supplicant@wlan1
systemctl restart wpa_supplicant@wlan0
systemctl restart dhcpcd

log "WiFi setup completed successfully"
log "Primary WiFi (wlan1): $PRIMARY_SSID"
log "Backup WiFi (wlan0): $BACKUP_SSID"
log "Note: A reboot is recommended to fully activate the new WiFi configuration"