# chmod +x setup-picam.sh
# ./setup-picam.sh

#!/bin/bash
set -e

echo "🔧 Instalace potřebných balíčků..."
sudo apt update
sudo apt install -y ffmpeg v4l2loopback-utils

echo "🧩 Konfigurace modulu v4l2loopback..."
# Zajistí, že modul bude načten při startu
if ! grep -q "v4l2loopback" /etc/modules; then
  echo "v4l2loopback" | sudo tee -a /etc/modules
fi

# Konfigurační soubor pro modul
cat <<EOF | sudo tee /etc/modprobe.d/v4l2loopback.conf
options v4l2loopback devices=1 video_nr=10 card_label="PiCam" exclusive_caps=1
EOF

# Načtení modulu
sudo modprobe v4l2loopback devices=1 video_nr=10 card_label="PiCam" exclusive_caps=1

echo "📷 Vytváření systemd služby..."

sudo tee /etc/systemd/system/picam-stream.service > /dev/null <<'EOF'
[Unit]
Description=PiCam streamer to v4l2loopback (/dev/video10)
After=multi-user.target

[Service]
ExecStart=/bin/bash -c 'libcamera-vid -t 0 --width 640 --height 480 --framerate 25 --codec yuv420 --nopreview -o - | ffmpeg -f rawvideo -pix_fmt yuv420p -s 640x480 -r 25 -i - -f v4l2 -pix_fmt yuyv422 /dev/video10'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "🚀 Aktivace služby..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable picam-stream.service
sudo systemctl start picam-stream.service

echo "✅ Hotovo! Kamera streamuje do /dev/video10"
echo "📦 Nezapomeň připojit /dev/video10 do Docker kontejneru jako /dev/video0:"
echo '    devices:'
echo '      - /dev/video10:/dev/video0'