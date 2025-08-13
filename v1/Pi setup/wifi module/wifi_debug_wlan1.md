
# 🛠️ Debug Wi-Fi adaptéru `wlan1` na Raspberry Pi

Tento návod ti pomůže krok za krokem zkontrolovat a odladit připojení Wi-Fi adaptéru `wlan1`, který používá ovladač **RTL88x2BU**.

---

## 🧾 1. Základní informace

- OS: Raspberry Pi OS Lite
- Primární adaptér: `wlan1` (externí)
- Záložní adaptér: `wlan0` (interní)
- Ovladač: `RTL88x2BU`
- Připojení Wi-Fi řešeno pomocí `wpa_supplicant` a `dhcpcd`

---

## 📁 2. Konfigurační soubor

Ulož připojovací údaje do souboru `/etc/wpa_supplicant/wpa_supplicant-wlan1.conf`:

```conf
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=CZ

network={
    ssid="TvojeSSID"
    psk="TvojeHeslo"
    key_mgmt=WPA-PSK
}
```

Zajisti, že soubor má správná oprávnění:

```bash
sudo chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
```

---

## ⚙️ 3. Test připojení ručně

Spusť `wpa_supplicant` pro `wlan1`:

```bash
sudo wpa_supplicant -i wlan1 -c /etc/wpa_supplicant/wpa_supplicant-wlan1.conf -d
```

- `-i wlan1` = použít rozhraní wlan1
- `-c ...` = konfigurační soubor
- `-d` = podrobný ladicí výstup (debug)

❗ **Tento příkaz běží v popředí** a nevypíše zpět shell. Ukonči pomocí `Ctrl + C`.

Alternativa (spuštění na pozadí):

```bash
sudo wpa_supplicant -i wlan1 -c /etc/wpa_supplicant/wpa_supplicant-wlan1.conf -B
```

---

## 🌐 4. Získání IP adresy

Po navázání spojení získej IP adresu:

```bash
sudo dhcpcd wlan1
```

Zkontroluj IP adresu:

```bash
ip addr show wlan1
```

---

## ✅ 5. Stav připojení

Ověř stav Wi-Fi spojení:

```bash
iw wlan1 link
```

Pokud jsi připojen, uvidíš SSID a sílu signálu. Pokud ne: „Not connected.“

---

## 🧹 6. Ukončení a čištění

Pokud `wpa_supplicant` běží stále a blokuje další pokusy, ukonči jej:

```bash
sudo pkill wpa_supplicant
```

Můžeš také použít `htop` a najít ho ručně, nebo znovu spustit s `-B` (na pozadí).

---

## 💡 7. Tipy

- Zkontroluj logy: `dmesg | grep wlan1` nebo `journalctl -u wpa_supplicant`
- Ujisti se, že nejsou konflikty mezi `NetworkManager`, `dhcpcd` a `wpa_supplicant` (používej jen to, co potřebuješ)
- Na trvalé připojení nakonfiguruj systémové jednotky (`systemd`), nebo zapiš do `/etc/network/interfaces` (starší metoda)

---

## 📞 Potřebuji pomoc?

Pokud ani po těchto krocích Wi-Fi nefunguje, dej mi vědět výpisy z:

```bash
iw list
lsusb
dmesg | grep wlan1
```

Rád pomohu dále ladit konkrétní problém.
