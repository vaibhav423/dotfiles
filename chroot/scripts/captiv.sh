proxy_port=8080
dnsmasq_user=dns_tether
#interface=wlan1
interface=wlan1
dns_port=1053
http_port=80

sudo lsof -t -i :"$proxy_port" | xargs -r sudo kill -9
sudo pkill -u "$dnsmasq_user" dnsmasq
sudo iptables -t nat -I PREROUTING -i "$interface" -p tcp --dport 53 -j REDIRECT --to-port "$dns_port"
sudo iptables -t nat  -I PREROUTING -i "$interface" -p udp --dport 53 -j REDIRECT --to-port "$dns_port"
sudo iptables -t nat -I PREROUTING -i "$interface" -p tcp --dport "$http_port" -j REDIRECT --to-port "$proxy_port"
sudo dnsmasq --no-resolv --port="$dns_port" --interface="$interface" \
  --address=/#/$(sudo ip -4 -o addr show dev "$interface" | awk '{print $4}' | cut -d/ -f1) \
  --pid-file=/sdcard/dnsmasq-ap0.pid
