# octofarm-pi-setup


## Troubleshooting

Open Docker to LAN
```sh
sudo iptables -I DOCKER -j ACCEPT
```

which ports are available:
```sh
sudo ss -tulnp | grep LISTEN
```

verify firewall
```sh
sudo ufw status
sudo iptables -L
```

restrat docker
```sh
sudo systemctl restart dockersudo iptables
```

ssh if not working on a main device
```sh
ssh-keygen -R 192.168.0.XX
```