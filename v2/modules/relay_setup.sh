#!/bin/bash

# Relay Setup Module
# Installs relay web interface

set -e

log() {
    echo "[$(date '+%H:%M:%S')] RELAY: $1"
}

APP_DIR="/home/pi"
VENV_DIR="$APP_DIR/relay_env"
APP_FILE="$APP_DIR/relay_web.py"
SERVICE_FILE="/etc/systemd/system/relay_web.service"

log "Creating Python virtual environment..."
python3 -m venv "$VENV_DIR"

log "Installing Flask in virtual environment..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install flask
deactivate

log "Installing relay web application..."
if [ ! -f "./relay_web.py" ]; then
    log "ERROR: relay_web.py not found in current directory!"
    exit 1
fi
cp ./relay_web.py "$APP_FILE"
chmod 644 "$APP_FILE"

log "Creating systemd service..."
sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=Relay Web Flask Application
After=network.target

[Service]
User=pi
WorkingDirectory=$APP_DIR
ExecStart=$VENV_DIR/bin/python $APP_FILE
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

log "Enabling and starting relay service..."
sudo systemctl daemon-reload
sudo systemctl enable relay_web.service
sudo systemctl start relay_web.service

# Check service status
if sudo systemctl is-active --quiet relay_web.service; then
    log "Relay service is running successfully"
else
    log "WARNING: Relay service may have issues starting"
fi

log "Relay setup completed successfully"
log "Web interface available at: http://$(hostname -I | awk '{print $1}'):8080"