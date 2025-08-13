#!/bin/bash

# chmod +x wifi-setup.sh
# sudo ./wifi-setup.sh

# Umožní spuštění skriptu jako root
if [[ $EUID -ne 0 ]]; then
   echo "Tento skript musí být spuštěn jako root (přes sudo)."
   exit 1
fi

echo "== 1. Aktualizace systému a instalace nástrojů =="
apt update
apt install -y git dkms build-essential raspberrypi-kernel-headers dhcpcd5

echo "== 2. Odstranění systemd-networkd (nahrazeno dhcpcd) =="
systemctl stop systemd-networkd
systemctl disable systemd-networkd
rm -f /etc/systemd/network/*.network

echo "== 3. Aktivace dhcpcd =="
systemctl enable dhcpcd
systemctl start dhcpcd

echo "== 4. Instalace ovladače RTL88x2BU =="
git clone "https://github.com/RinCat/RTL88x2BU-Linux-Driver.git" /usr/src/rtl88x2bu-git
sed -i 's/PACKAGE_VERSION="@PKGVER@"/PACKAGE_VERSION="git"/g' /usr/src/rtl88x2bu-git/dkms.conf
dkms add -m rtl88x2bu -v git
dkms autoinstall
modprobe 88x2bu

echo "== 5. Nastavení metrik rozhraní: wlan1 primární, wlan0 záložní =="
cat >> /etc/dhcpcd.conf <<EOF
interface wlan1
    metric 100

interface wlan0
    metric 200
EOF

echo "== 6. Konfigurace wpa_supplicant pro wlan1 =="
cat > /etc/wpa_supplicant/wpa_supplicant-wlan1.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=CZ

network={
    ssid="MojePrimarniSit"
    psk="MojeHeslo"
    priority=10
    scan_ssid=1
}
EOF
chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan1.conf

echo "== 7. Konfigurace wpa_supplicant pro wlan0 (záložní) =="
cat > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=CZ

network={
    ssid="MojeZalozniSit"
    psk="ZalozniHeslo"
    priority=5
    scan_ssid=1
}
EOF
chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan0.conf

echo "== 8. Aktivace wpa_supplicant služeb pro obě rozhraní =="
systemctl enable wpa_supplicant@wlan1
systemctl enable wpa_supplicant@wlan0

echo "== 9. Úprava systemd služeb pro správné použití konkrétních konfigurací =="
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

echo "== 10. Restart síťových služeb =="
systemctl daemon-reexec
systemctl restart wpa_supplicant@wlan1
systemctl restart wpa_supplicant@wlan0
systemctl restart dhcpcd

echo "== 11. Hotovo. Restart systému =="
reboot