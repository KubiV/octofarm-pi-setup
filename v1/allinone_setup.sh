#!/bin/bash

# All-in-One Raspberry Pi Setup Script
# Usage: chmod +x all-in-one-setup.sh && sudo ./all-in-one-setup.sh

# After running this script, you can run the following commands to start the services:
# sudo smbpasswd -a pi
# sudo nano /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
# sudo nano /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
# nano /home/pi/docker-config/docker-compose.yaml
# ls -l /dev/serial/by-id/
# sudo crontab -e
#    @reboot /home/pi/startup.sh >> /home/pi/startup.log 2>&1
# cd /home/pi/docker-config
# docker compose up -d
# sudo tailscale up

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "Tento skript musí být spuštěn jako root (přes sudo)."
fi

echo -e "${BLUE}"
echo "=========================================="
echo "  Raspberry Pi All-in-One Setup Script  "
echo "=========================================="
echo -e "${NC}"

# Interactive prompts for optional components
echo "Vyberte komponenty k instalaci:"
echo

read -p "🌐 Chcete nainstalovat Tailscale? (y/N): " install_tailscale
read -p "📶 Chcete nainstalovat TP-Link WiFi modul (RTL88x2BU)? (y/N): " install_wifi
read -p "🔌 Chcete nainstalovat relay web ovládání? (y/N): " install_relay

echo
echo "Vybrané komponenty:"
echo "- Základní systém: ✅ (vždy)"
echo "- Docker & Docker Compose: ✅ (vždy)"
echo "- Kamera & Samba: ✅ (vždy)"
[[ "$install_tailscale" =~ ^[Yy]$ ]] && echo "- Tailscale: ✅" || echo "- Tailscale: ❌"
[[ "$install_wifi" =~ ^[Yy]$ ]] && echo "- TP-Link WiFi: ✅" || echo "- TP-Link WiFi: ❌"
[[ "$install_relay" =~ ^[Yy]$ ]] && echo "- Relay Web: ✅" || echo "- Relay Web: ❌"
echo

read -p "Pokračovat v instalaci? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Instalace zrušena."
    exit 0
fi

echo
log "🚀 Začíná instalace..."

# ===============================
# 1. ZÁKLADNÍ SYSTÉM
# ===============================
log "🔧 Aktualizace systému..."
apt update && apt full-upgrade -y

log "📦 Instalace základních balíčků..."
apt install -y \
    build-essential \
    libjpeg-dev \
    libjpeg62-turbo-dev \
    imagemagick \
    libv4l-dev \
    cmake \
    git \
    dkms \
    raspberrypi-kernel-headers \
    ffmpeg \
    fswebcam \
    curl \
    python3 \
    python3-pip \
    python3-venv \
    python3-flask

# ===============================
# 2. DOCKER INSTALACE
# ===============================
log "🐳 Instalace Dockeru..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

log "🔧 Přidávání uživatele 'pi' do skupiny docker..."
usermod -aG docker pi

log "🌀 Povolení a spuštění služby docker..."
systemctl enable docker
systemctl start docker

log "📦 Instalace Docker Compose pluginu..."
# Zjisti architekturu
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
    PLATFORM="aarch64"
elif [ "$ARCH" = "armv7l" ]; then
    PLATFORM="armv7"
else
    error "❌ Nepodporovaná architektura: $ARCH"
fi

# Instalace pluginu pro uživatele pi
sudo -u pi mkdir -p /home/pi/.docker/cli-plugins/
curl -SL "https://github.com/docker/compose/releases/download/v2.24.7/docker-compose-linux-$PLATFORM" \
    -o /home/pi/.docker/cli-plugins/docker-compose
chmod +x /home/pi/.docker/cli-plugins/docker-compose
chown pi:pi /home/pi/.docker/cli-plugins/docker-compose

# Přidání do PATH pro uživatele pi
if ! grep -q ".docker/cli-plugins" /home/pi/.bashrc; then
    echo 'export PATH="$HOME/.docker/cli-plugins:$PATH"' >> /home/pi/.bashrc
    log "✅ Přidán Docker Compose plugin do PATH."
fi

# ===============================
# 3. KAMERA NASTAVENÍ
# ===============================
log "📷 Nastavení kamery (Picam)..."
modprobe bcm2835-v4l2

cat <<EOF > /etc/modules-load.d/camera.conf
bcm2835-v4l2
EOF

# ===============================
# 4. SAMBA INSTALACE
# ===============================
log "📁 Instalace a konfigurace Samba..."
apt install -y samba samba-common-bin

cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

cat <<EOF >> /etc/samba/smb.conf

[pi-share]
   path = /home/pi/share
   writeable = yes
   create mask = 0775
   directory mask = 0775
   public = no
EOF

mkdir -p /home/pi/share
chown -R pi:pi /home/pi/share
systemctl restart smbd

warn "POZOR: Po dokončení instalace nastavte heslo pro Samba: sudo smbpasswd -a pi"

# ===============================
# 5. TP-LINK WIFI MODUL (volitelné)
# ===============================
if [[ "$install_wifi" =~ ^[Yy]$ ]]; then
    log "📶 Instalace TP-Link WiFi modulu (RTL88x2BU)..."

    apt install -y dhcpcd5

    log "Odstranění systemd-networkd..."
    systemctl stop systemd-networkd
    systemctl disable systemd-networkd
    rm -f /etc/systemd/network/*.network

    log "Aktivace dhcpcd..."
    systemctl enable dhcpcd
    systemctl start dhcpcd

    log "Instalace ovladače RTL88x2BU..."
    git clone "https://github.com/RinCat/RTL88x2BU-Linux-Driver.git" /usr/src/rtl88x2bu-git
    sed -i 's/PACKAGE_VERSION="@PKGVER@"/PACKAGE_VERSION="git"/g' /usr/src/rtl88x2bu-git/dkms.conf
    dkms add -m rtl88x2bu -v git
    dkms autoinstall
    modprobe 88x2bu

    log "Nastavení metrik rozhraní..."
    cat >> /etc/dhcpcd.conf <<EOF
interface wlan1
    metric 100

interface wlan0
    metric 200
EOF

    # Vytvoření template konfigurací
    cat > /etc/wpa_supplicant/wpa_supplicant-wlan1.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=CZ

network={
    ssid="CHANGE_THIS_SSID"
    psk="CHANGE_THIS_PASSWORD"
    priority=10
    scan_ssid=1
}
EOF
    chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan1.conf

    cat > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=CZ

network={
    ssid="CHANGE_THIS_BACKUP_SSID"
    psk="CHANGE_THIS_BACKUP_PASSWORD"
    priority=5
    scan_ssid=1
}
EOF
    chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan0.conf

    systemctl enable wpa_supplicant@wlan1
    systemctl enable wpa_supplicant@wlan0

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

    systemctl daemon-reexec

    warn "POZOR: Upravte WiFi konfigurace v /etc/wpa_supplicant/wpa_supplicant-wlan*.conf"
fi

# ===============================
# 6. RELAY WEB APLIKACE (volitelné)
# ===============================
if [[ "$install_relay" =~ ^[Yy]$ ]]; then
    log "🔌 Instalace Relay Web aplikace..."

    APP_DIR="/home/pi"
    VENV_DIR="$APP_DIR/relay_env"
    APP_FILE="$APP_DIR/relay_web.py"
    SERVICE_FILE="/etc/systemd/system/relay_web.service"

    log "Vytvářím virtuální prostředí..."
    sudo -u pi python3 -m venv $VENV_DIR
    sudo -u pi $VENV_DIR/bin/pip install --upgrade pip
    sudo -u pi $VENV_DIR/bin/pip install flask

    log "Vytvářím Flask aplikaci..."
    cat > $APP_FILE <<'EOF'
# sudo apt install python3-flask
from flask import Flask, render_template_string, request
import sys

app = Flask(__name__)
PORT = "/dev/ttyACM0"
BAUD = 9600

# Mock serial.Serial if not running on the real device
try:
    import serial
    ser = serial.Serial(PORT, BAUD, timeout=1)
except Exception:
    class DummySerial:
        def write(self, data):
            print(f"Mock write: {data.decode().strip()}", file=sys.stderr)
    ser = DummySerial()

html = """
<!DOCTYPE html>
<html>
<head>
  <title>Ovládání Relé</title>
  <style>
    body {
      background: #f7f7f7;
      font-family: Arial, sans-serif;
      text-align: center;
      margin: 0;
      padding: 0;
    }
    h1 {
      background: #2d7cff;
      color: white;
      padding: 30px 0 20px 0;
      margin-bottom: 30px;
      box-shadow: 0 2px 8px #aaa;
    }
    h3 {
      color: #2d7cff;
      margin-top: 30px;
    }
    form {
      display: inline-block;
      margin-bottom: 20px;
    }
    button {
      padding: 10px 30px;
      margin: 10px;
      font-size: 20px;
      border: none;
      border-radius: 8px;
      background: #2d7cff;
      color: white;
      cursor: pointer;
      transition: background 0.2s;
      box-shadow: 0 2px 6px #bbb;
    }
    button:hover {
      background: #1a4fa3;
    }
  </style>
</head>
<body>
  <h1>Ovládání relé</h1>
  {% for r in [1,2,3] %}
    <h3>Relé {{ r }}</h3>
    <form method="post">
      <button name="cmd" value="R{{ r }}:1">Zapnout</button>
      <button name="cmd" value="R{{ r }}:0">Vypnout</button>
    </form>
  {% endfor %}
</body>
</html>
"""

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        cmd = request.form["cmd"]
        ser.write((cmd + "\n").encode())
        # Print relay action to terminal
        relay, state = cmd.split(":")
        action = "ON" if state == "1" else "OFF"
        print(f"Relay {relay[-1]} turned {action}", file=sys.stderr)
    return render_template_string(html)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
EOF
    chmod 644 $APP_FILE
    chown pi:pi $APP_FILE

    log "Vytvářím systemd službu..."
    cat > $SERVICE_FILE <<EOF
[Unit]
Description=Relay Web Flask Application
After=network.target

[Service]
User=pi
WorkingDirectory=$APP_DIR
ExecStart=$VENV_DIR/bin/python $APP_FILE
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable relay_web.service
    systemctl start relay_web.service
fi

# ===============================
# 7. DOCKER COMPOSE SOUBORY
# ===============================
log "📝 Vytváření Docker Compose konfigurace..."
mkdir -p /home/pi/docker-config
cat > /home/pi/docker-config/docker-compose.yaml <<'EOF'
volumes:
  mongodb-data:
  octoprint1-data:
  octoprint2-data:

services:

  mongodb:
    image: arm64v8/mongo:4.2.3-bionic
    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: rootpassword
      MONGO_INITDB_DATABASE: octofarm
    ports:
      - 27017:27017
    volumes:
      - mongodb-data:/data/db
    restart: unless-stopped

  octofarm:
    image: thetinkerdad/octofarm:arm64-1.1.4
    container_name: octofarm
    environment:
      MONGOHOST: mongodb
      MONGOUSER: root
      MONGOPASS: rootpassword
    ports:
      - 4000:4000
    volumes:
      - ./logs/:/root/.npm/_logs/
    restart: unless-stopped

  octoprint1:
    image: octoprint/octoprint:latest
    container_name: octoprint1
    ports:
      - 5001:80
    volumes:
      - octoprint1-data:/octoprint
    restart: unless-stopped
    environment:
      ENABLE_MJPG_STREAMER: "true"
    devices:
      - /dev/serial/by-id/usb-1a86_USB_Serial-if00-port0:/dev/ttyUSB0

  octoprint2:
    image: octoprint/octoprint:latest
    container_name: octoprint2
    ports:
      - 5002:80
    volumes:
      - octoprint2-data:/octoprint
    restart: unless-stopped
    environment:
      ENABLE_MJPG_STREAMER: "true"
    devices:
      - /dev/serial/by-id/usb-STMicroelectronics_MARLIN_STM32G0B1RE_CDC_in_FS_Mode_203E345B4D41-if00:/dev/ttyACM0

  mjpg-streamer:
    image: openhorizon/mjpg-streamer-pi3
    container_name: mjpg-streamer
    restart: unless-stopped
    devices:
      - /dev/video0:/dev/video0
    ports:
      - 8081:8080
    command: >
      ./mjpg_streamer
      -i "input_uvc.so -d /dev/video0 -r 1280x720 -f 30"
      -o "output_http.so -p 8080 -w ./www"
EOF

# ===============================
# 8. STARTUP SKRIPT
# ===============================
log "⚡ Vytváření startup skriptu..."
cat > /home/pi/startup.sh <<'EOF'
#!/bin/bash

# chmod +x startup.sh
# sudo crontab -e a pridej:
# @reboot /home/pi/startup.sh >> /home/pi/startup.log 2>&1

PORT="/dev/ttyACM0"
BAUD=9600
EXPECTED_NEW_DEVICES=2
MAX_RETRIES=2
WAIT_TIME=5

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# Funkce na zapnutí relé
enable_relays() {
    echo "R1:1" > $PORT
    echo "R2:1" > $PORT
    log "Relé R1 a R2 zapnuty"
}

# Funkce na vypnutí relé
disable_relays() {
    echo "R1:0" > $PORT
    echo "R2:0" > $PORT
    log "Relé R1 a R2 vypnuty"
}

# Nastavení sériového portu
stty -F $PORT $BAUD

# Počet USB zařízení před zapnutím
initial_count=$(lsusb | wc -l)

for attempt in $(seq 1 $MAX_RETRIES); do
    enable_relays

    for i in {1..10}; do
        sleep $WAIT_TIME
        current_count=$(lsusb | wc -l)
        if (( current_count >= initial_count + EXPECTED_NEW_DEVICES )); then
            log "Detekována nová USB zařízení (OK)"
            break 2
        fi
        log "Čekám na USB zařízení... ($i/10)"
    done

    log "Zařízení se neobjevila, zkouším znovu ($attempt/$MAX_RETRIES)"
    disable_relays
    sleep 2
done

# Pokud selhalo i po všech pokusech
current_count=$(lsusb | wc -l)
if (( current_count < initial_count + EXPECTED_NEW_DEVICES )); then
    log "CHYBA: Po zapnutí relé se neobjevila USB zařízení!"
    disable_relays
    exit 1
fi

# Restart Dockeru
sudo systemctl restart docker
log "Docker restartován"

# Povolit Docker komunikaci
sudo iptables -I DOCKER -j ACCEPT
log "iptables pravidlo nastaveno"

# Počkat 20 sekund (dokud nenaběhnou všechny kontejnery)
sleep 20

disable_relays
log "Hotovo"
EOF

chmod +x /home/pi/startup.sh
chown pi:pi /home/pi/startup.sh
chown -R pi:pi /home/pi/docker-config

# ===============================
# 9. TAILSCALE INSTALACE (volitelné)
# ===============================
if [[ "$install_tailscale" =~ ^[Yy]$ ]]; then
    log "🌐 Instalace Tailscale..."
    apt-get install -y apt-transport-https

    curl -fsSL https://pkgs.tailscale.com/stable/raspbian/bullseye.noarmor.gpg | \
        tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null

    curl -fsSL https://pkgs.tailscale.com/stable/raspbian/bullseye.tailscale-keyring.list | \
        tee /etc/apt/sources.list.d/tailscale.list > /dev/null

    apt update
    apt install -y tailscale

    warn "Pro spuštění Tailscale použijte: sudo tailscale up"
fi

# ===============================
# 10. DOKONČENÍ
# ===============================
echo
echo -e "${GREEN}=========================================="
echo "  ✅ INSTALACE DOKONČENA"
echo "==========================================${NC}"
echo
echo "📋 Shrnutí nainstalovaných komponent:"
echo "   ✅ Základní systém + balíčky"
echo "   ✅ Docker + Docker Compose"
echo "   ✅ Kamera (bcm2835-v4l2)"
echo "   ✅ Samba file sharing"
echo "   📁 Docker Compose config: /home/pi/docker-config/"
echo "   ⚡ Startup skript: /home/pi/startup.sh"
[[ "$install_tailscale" =~ ^[Yy]$ ]] && echo "   ✅ Tailscale (spusťte: sudo tailscale up)"
[[ "$install_wifi" =~ ^[Yy]$ ]] && echo "   ✅ TP-Link WiFi modul"
[[ "$install_relay" =~ ^[Yy]$ ]] && echo "   ✅ Relay Web (http://IP:8080)"
echo
echo "🔧 Potřebné manuální kroky:"
echo "   1. Nastavte Samba heslo: sudo smbpasswd -a pi"
[[ "$install_wifi" =~ ^[Yy]$ ]] && echo "   2. Upravte WiFi konfigurace v /etc/wpa_supplicant/"
echo "   3. Upravte Docker Compose zařízení v /home/pi/docker-config/"
echo "   4. Pro auto-start při bootu: sudo crontab -e"
echo "      Přidejte: @reboot /home/pi/startup.sh >> /home/pi/startup.log 2>&1"
echo
echo "🚀 Spuštění Docker kontejnerů:"
echo "   cd /home/pi/docker-config && docker compose up -d"
echo
echo "⚠️  RESTART SYSTÉMU DOPORUČEN pro správné načtení všech změn."

log "🎉 Instalace dokončena!"