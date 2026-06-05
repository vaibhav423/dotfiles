sudo lsof -t -i :8080 | xargs -r sudo kill -9
sudo pkill -u dns_tether dnsmasq
sudo iptables -t nat -I PREROUTING -i wlan1 -p tcp --dport 53 -j REDIRECT --to-port 1053
sudo iptables -t nat  -I PREROUTING -i wlan1 -p udp --dport 53 -j REDIRECT --to-port 1053
sudo iptables -t nat -I PREROUTING -i wlan1 -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo dnsmasq --no-resolv --port=1053 --interface=wlan1 \
  --address=/#/$(sudo ip -4 -o addr show dev wlan1 | awk '{print $4}' | cut -d/ -f1) \
  --pid-file=/sdcard/dnsmasq-ap0.pid

