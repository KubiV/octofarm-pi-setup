#!/bin/bash

# chmod +x startup.sh
# sudo crontab -e

# sudo crontab -e
# @reboot /home/pi/startup.sh >> /home/pi/startup.log 2>&1

# možný upgrade přes - systemd služba

#!/bin/bash
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