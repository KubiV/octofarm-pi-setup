#!/bin/bash

# relay_web.py ve stejné složce jako tento skript

# chmod +x install_relay_web.sh
# ./install_relay_web.sh

set -e

APP_DIR="/home/pi"
VENV_DIR="$APP_DIR/relay_env"
APP_FILE="$APP_DIR/relay_web.py"
SERVICE_FILE="/etc/systemd/system/relay_web.service"

echo "Instaluji python3, pip a venv..."
sudo apt install -y python3 python3-pip python3-venv

echo "Vytvářím virtuální prostředí..."
python3 -m venv $VENV_DIR

echo "Aktivuji virtuální prostředí a instaluji Flask..."
source $VENV_DIR/bin/activate
pip install --upgrade pip
pip install flask
deactivate

echo "Kopíruji Flask aplikaci..."
if [ ! -f ./relay_web.py ]; then
  echo "Chyba: relay_web.py nenalezen v aktuálním adresáři!"
  exit 1
fi
cp ./relay_web.py $APP_FILE
chmod 644 $APP_FILE

echo "Vytvářím systemd službu..."
sudo tee $SERVICE_FILE > /dev/null << EOF
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

echo "Načítám systemd a povoluji službu..."
sudo systemctl daemon-reload
sudo systemctl enable relay_web.service
sudo systemctl start relay_web.service

echo "Hotovo! Flask aplikace by měla běžet na http://$(hostname -I | awk '{print $1}'):8080"