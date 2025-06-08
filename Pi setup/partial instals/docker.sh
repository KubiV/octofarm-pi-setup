# nano docker.sh
# chmod +x docker.sh
# ./docker.sh

#!/bin/bash

set -e

echo "==> Aktualizace systému..."
sudo apt-get update

echo "==> Instalace Dockeru..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

echo "==> Přidávání uživatele $USER do skupiny docker..."
sudo usermod -aG docker $USER

echo "==> Instalace Python3 pip a Docker Compose..."
sudo apt-get install -y python3-pip
sudo pip3 install docker-compose

echo "==> Verze Dockeru:"
docker --version

echo "==> Verze Docker Compose:"
docker compose version || docker-compose version

echo "==> Hotovo. Možná bude potřeba se odhlásit a znovu přihlásit, aby se změna skupiny projevila."