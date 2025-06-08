# nano setup-samba.sh
# chmod +x setup-samba.sh
# ./setup-samba.sh

#!/bin/bash

# Exit on any error
set -e

echo "Aktualizace systému..."
sudo apt update

echo "Instalace Samba..."
sudo apt install samba samba-common-bin -y

echo "Zálohování původního smb.conf..."
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

echo "Vytváření nové konfigurace smb.conf..."
sudo tee /etc/samba/smb.conf > /dev/null <<EOL
[global]
   workgroup = WORKGROUP
   server string = Raspberry Pi Samba Server
   netbios name = raspberrypi
   security = user
   map to guest = bad user
   dns proxy = no

[root]
   path = /
   browseable = yes
   writeable = yes
   create mask = 0777
   directory mask = 0777
   public = no
   valid users = pi

[HomePi]
   path = /home/pi
   browseable = yes
   writeable = yes
   valid users = pi
   create mask = 0644
   directory mask = 0755
   public = no
EOL

echo "Nastavování hesla pro uživatele 'pi' do Samba..."
sudo smbpasswd -a pi

echo "Nastavení práv k adresáři /home/pi..."
sudo chown -R pi:pi /home/pi
sudo chmod -R 775 /home/pi

echo "Restart služby smbd..."
sudo systemctl restart smbd

echo "Hotovo! Samba je nakonfigurována a spuštěna."