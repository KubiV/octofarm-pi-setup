#!/bin/bash

set -e

echo "🔧 Aktualizace systému..."
sudo apt update && sudo apt full-upgrade -y

echo "📦 Instalace základních balíčků..."
sudo apt install -y \
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
    fswebcam

# === Obsah původního docker.sh ===
set -e

echo "🐳 Instalace Dockeru..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

echo "🔧 Přidávání uživatele '$USER' do skupiny docker..."
sudo usermod -aG docker "$USER"

echo "🌀 Povolení a spuštění služby docker..."
sudo systemctl enable docker
sudo systemctl start docker

echo "📦 Instalace Docker Compose pluginu..."

# Zjisti architekturu
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
    PLATFORM="aarch64"
elif [ "$ARCH" = "armv7l" ]; then
    PLATFORM="armv7"
else
    echo "❌ Nepodporovaná architektura: $ARCH"
    exit 1
fi

# Instalace pluginu
mkdir -p ~/.docker/cli-plugins/
curl -SL "https://github.com/docker/compose/releases/download/v2.24.7/docker-compose-linux-$PLATFORM" \
    -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose

# Přidání do PATH, pokud není
if ! echo "$PATH" | grep -q "$HOME/.docker/cli-plugins"; then
    echo 'export PATH="$HOME/.docker/cli-plugins:$PATH"' >> ~/.bashrc
    export PATH="$HOME/.docker/cli-plugins:$PATH"
    echo "✅ Přidán Docker Compose plugin do PATH."
fi

# Ověření
echo
echo "✅ Verze Dockeru:"
docker --version

echo
echo "✅ Verze Docker Compose pluginu:"
docker compose version || echo "❌ 'docker compose' není dostupné – restartuj shell nebo se znovu přihlas."

echo
echo "📝 Instalace dokončena. Pokud jsi právě přidal uživatele do skupiny docker,"
echo "   odhlaš se a znovu přihlas nebo spusť: exec su -l $USER"

# === Obsah původního setup-picam.sh ===
echo "📷 Nastavení kamery (Picam)..."
sudo modprobe bcm2835-v4l2

cat <<EOF | sudo tee /etc/modules-load.d/camera.conf
bcm2835-v4l2
EOF

# === Obsah původního setup-samba.sh ===
echo "📁 Instalace a konfigurace Samba..."
sudo apt install -y samba samba-common-bin

sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

cat <<EOF | sudo tee -a /etc/samba/smb.conf

[pi-share]
   path = /home/pi/share
   writeable = yes
   create mask = 0775
   directory mask = 0775
   public = no
EOF

sudo mkdir -p /home/pi/share
sudo chown -R pi:pi /home/pi/share
sudo smbpasswd -a pi
sudo systemctl restart smbd

# === Volitelná instalace Tailscale ===
read -p "❓ Chceš nainstalovat Tailscale? (y/N): " install_tailscale

if [[ "$install_tailscale" =~ ^[Yy]$ ]]; then
    echo "🌐 Instalace Tailscale..."
    sudo apt-get install -y apt-transport-https

    curl -fsSL https://pkgs.tailscale.com/stable/raspbian/bullseye.noarmor.gpg | \
        sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null

    curl -fsSL https://pkgs.tailscale.com/stable/raspbian/bullseye.tailscale-keyring.list | \
        sudo tee /etc/apt/sources.list.d/tailscale.list > /dev/null

    sudo apt update
    sudo apt install -y tailscale

    echo "🚀 Spuštění Tailscale..."
    sudo tailscale up
else
    echo "⏭️ Instalace Tailscale byla přeskočena."
fi

echo "✅ Hotovo. Možná bude potřeba restart pro správné načtení všech změn."