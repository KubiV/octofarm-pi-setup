#!/bin/bash

# TP-Link WiFi Setup Module - Improved Version
# Based on working tplinkwifiinstall.sh with interactive configuration
# Installs RTL88x2BU driver and configures dual WiFi setup

set -e

log() {
    echo "[$(date '+%H:%M:%S')] WIFI: $1"
}

error() {
    echo "[$(date '+%H:%M:%S')] WIFI ERROR: $1" >&2
}

warn() {
    echo "[$(date '+%H:%M:%S')] WIFI WARNING: $1" >&2
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This WiFi setup script must be run as root (with sudo)."
   exit 1
fi

# Fix locale warnings
export LC_ALL=C
export LANG=C

log "Starting TP-Link WiFi adapter setup..."

# Test internet connectivity before proceeding
log "Testing internet connectivity..."
if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
    error "No internet connectivity detected!"
    error "Please ensure you have internet access before running WiFi setup."
    error "You may need to connect via ethernet or existing WiFi first."
    exit 1
fi

# Interactive WiFi Configuration
echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    WiFi Configuration                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
echo "You will configure two WiFi networks:"
echo "• Primary WiFi (wlan1) - Higher priority, external adapter"
echo "• Backup WiFi (wlan0)  - Lower priority, built-in adapter"
echo

# Get Primary WiFi credentials
echo "=== Primary WiFi Network (wlan1) ==="
read -p "Enter Primary WiFi SSID: " PRIMARY_SSID
while [[ -z "$PRIMARY_SSID" ]]; do
    echo "SSID cannot be empty!"
    read -p "Enter Primary WiFi SSID: " PRIMARY_SSID
done

read -s -p "Enter Primary WiFi Password: " PRIMARY_PASS
echo
while [[ -z "$PRIMARY_PASS" ]]; do
    echo "Password cannot be empty!"
    read -s -p "Enter Primary WiFi Password: " PRIMARY_PASS
    echo
done

echo
echo "=== Backup WiFi Network (wlan0) ==="
read -p "Enter Backup WiFi SSID: " BACKUP_SSID
while [[ -z "$BACKUP_SSID" ]]; do
    echo "SSID cannot be empty!"
    read -p "Enter Backup WiFi SSID: " BACKUP_SSID
done

read -s -p "Enter Backup WiFi Password: " BACKUP_PASS
echo
while [[ -z "$BACKUP_PASS" ]]; do
    echo "Password cannot be empty!"
    read -s -p "Enter Backup WiFi Password: " BACKUP_PASS
    echo
done

echo
read -p "WiFi Country Code (default: CZ): " COUNTRY_CODE
COUNTRY_CODE=${COUNTRY_CODE:-CZ}

echo
log "Configuration Summary:"
log "Primary WiFi: $PRIMARY_SSID (wlan1)"
log "Backup WiFi: $BACKUP_SSID (wlan0)"
log "Country: $COUNTRY_CODE"
echo
read -p "Proceed with installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "WiFi setup cancelled."
    exit 0
fi

log "== 1. System update and tool installation =="
apt update
apt install -y git dkms build-essential raspberrypi-kernel-headers dhcpcd5

log "== 2. Removing systemd-networkd (replaced by dhcpcd) =="
systemctl stop systemd-networkd 2>/dev/null || true
systemctl disable systemd-networkd 2>/dev/null || true
rm -f /etc/systemd/network/*.network

log "== 3. Activating dhcpcd =="
systemctl enable dhcpcd
systemctl start dhcpcd

log "== 4. Installing RTL88x2BU driver =="
# Remove existing installation if present
if [ -d "/usr/src/rtl88x2bu-git" ]; then
    log "Removing existing driver installation..."
    dkms remove -m rtl88x2bu -v git --all 2>/dev/null || true
    rm -rf /usr/src/rtl88x2bu-git
fi

log "Downloading driver source..."
if ! git clone "https://github.com/RinCat/RTL88x2BU-Linux-Driver.git" /usr/src/rtl88x2bu-git; then
    error "Failed to download driver from GitHub!"
    error "Please check your internet connection and try again."
    exit 1
fi

cd /usr/src/rtl88x2bu-git
log "Configuring driver for DKMS..."
sed -i 's/PACKAGE_VERSION="@PKGVER@"/PACKAGE_VERSION="git"/g' dkms.conf

log "Adding driver to DKMS..."
dkms add -m rtl88x2bu -v git

log "Building and installing driver..."
if ! dkms autoinstall; then
    error "Driver compilation failed!"
    error "This may be due to kernel version mismatch or missing dependencies."
    exit 1
fi

log "Loading driver module..."
modprobe 88x2bu

# Verify the driver loaded successfully
if ! lsmod | grep -q 88x2bu; then
    error "Driver module failed to load!"
    exit 1
fi

log "== 5. Setting interface priorities: wlan1 primary, wlan0 backup =="
# Backup existing dhcpcd.conf
cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup

# Add interface metrics (lower number = higher priority)
cat >> /etc/dhcpcd.conf <<EOF

# WiFi interface priorities (added by wifi-setup.sh)
interface wlan1
    metric 100

interface wlan0
    metric 200
EOF

log "== 6. Configuring wpa_supplicant for wlan1 (primary) =="
cat > /etc/wpa_supplicant/wpa_supplicant-wlan1.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=$COUNTRY_CODE

network={
    ssid="$PRIMARY_SSID"
    psk="$PRIMARY_PASS"
    key_mgmt=WPA-PSK
    priority=10
    scan_ssid=1
}
EOF
chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan1.conf

log "== 7. Configuring wpa_supplicant for wlan0 (backup) =="
cat > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=$COUNTRY_CODE

network={
    ssid="$BACKUP_SSID"
    psk="$BACKUP_PASS"
    key_mgmt=WPA-PSK
    priority=5
    scan_ssid=1
}
EOF
chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan0.conf

log "== 8. Enabling wpa_supplicant services for both interfaces =="
systemctl enable wpa_supplicant@wlan1
systemctl enable wpa_supplicant@wlan0

log "== 9. Configuring systemd services for specific configurations =="
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

log "== 10. Restarting network services =="
systemctl daemon-reload
systemctl restart wpa_supplicant@wlan1
systemctl restart wpa_supplicant@wlan0
systemctl restart dhcpcd

# Wait a moment for services to stabilize
sleep 5

log "== 11. Verifying configuration =="

# Check if interfaces are detected
if ip link show wlan1 >/dev/null 2>&1; then
    log "✓ wlan1 interface detected"
else
    warn "✗ wlan1 interface not detected - driver may not be working"
fi

if ip link show wlan0 >/dev/null 2>&1; then
    log "✓ wlan0 interface detected"
else
    warn "✗ wlan0 interface not detected"
fi

# Check service status
if systemctl is-active --quiet wpa_supplicant@wlan1; then
    log "✓ wpa_supplicant@wlan1 service is running"
else
    warn "✗ wpa_supplicant@wlan1 service is not running"
fi

if systemctl is-active --quiet wpa_supplicant@wlan0; then
    log "✓ wpa_supplicant@wlan0 service is running"
else
    warn "✗ wpa_supplicant@wlan0 service is not running"
fi

log "== 12. WiFi setup completed successfully! =="
log "Configuration summary:"
log "• Primary WiFi: $PRIMARY_SSID (wlan1, priority 10, metric 100)"
log "• Backup WiFi: $BACKUP_SSID (wlan0, priority 5, metric 200)"
log "• Country code: $COUNTRY_CODE"
echo
log "IMPORTANT: A system reboot is required to fully activate the new WiFi configuration."
log "The system will reboot automatically, or you can cancel and reboot manually later."
echo

# Create a status script for debugging
cat > /home/pi/wifi-status.sh <<'EOF'
#!/bin/bash
echo "=== WiFi Status Debug Script ==="
echo
echo "1. Network Interfaces:"
ip link show | grep -E "(wlan0|wlan1)"
echo
echo "2. WiFi Connection Status:"
for iface in wlan0 wlan1; do
    if ip link show $iface >/dev/null 2>&1; then
        echo "$iface:"
        iw $iface link 2>/dev/null || echo "  Not connected or not available"
        ip addr show $iface | grep -E "inet " || echo "  No IP address"
        echo
    fi
done
echo "3. Service Status:"
systemctl status wpa_supplicant@wlan0 --no-pager -l
systemctl status wpa_supplicant@wlan1 --no-pager -l
echo
echo "4. Recent logs:"
journalctl -u wpa_supplicant@wlan1 -n 10 --no-pager
echo
echo "Run this script after reboot to check WiFi status: ./wifi-status.sh"
EOF
chmod +x /home/pi/wifi-status.sh
chown pi:pi /home/pi/wifi-status.sh

log "Created debug script: /home/pi/wifi-status.sh"
log "Run it after reboot to check WiFi connection status."

echo
read -p "Reboot now to activate WiFi configuration? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    log "Reboot cancelled. Please reboot manually when ready."
    log "After reboot, check WiFi status with: ./wifi-status.sh"
else
    log "Rebooting system in 3 seconds..."
    sleep 3
    reboot
fi