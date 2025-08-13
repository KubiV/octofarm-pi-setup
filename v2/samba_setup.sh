#!/bin/bash

# Samba Setup Module
# Installs and configures Samba file sharing

set -e

log() {
    echo "[$(date '+%H:%M:%S')] SAMBA: $1"
}

log "Installing Samba packages..."
sudo apt install -y samba samba-common-bin

log "Backing up original Samba configuration..."
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

log "Adding share configuration..."
cat <<EOF | sudo tee -a /etc/samba/smb.conf

[pi-share]
   comment = Raspberry Pi Share
   path = /home/pi/share
   writeable = yes
   create mask = 0775
   directory mask = 0775
   public = no
   valid users = pi
EOF

log "Creating share directory..."
mkdir -p /home/pi/share
sudo chown -R pi:pi /home/pi/share

log "Setting up Samba user..."
echo "Please set a password for Samba user 'pi':"
sudo smbpasswd -a pi

log "Restarting Samba services..."
sudo systemctl enable smbd
sudo systemctl restart smbd

log "Samba setup completed successfully"
log "Share available at: \\\\$(hostname -I | awk '{print $1}')\\pi-share"