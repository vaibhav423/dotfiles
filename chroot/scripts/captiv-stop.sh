#!/bin/sh

proxy_port=8080
interface=wlan2
dns_port=1053
http_port=80
pid_file=${CAPTIV_PID_FILE:-/data/local/tmp/captiv-dnsmasq.pid}

# Kill dnsmasq
kill $(cat "$pid_file" 2>/dev/null) 2>/dev/null
rm "$pid_file" 2>/dev/null
netstat -tlnp 2>/dev/null | grep ":$dns_port " | awk '{print $7}' | cut -d/ -f1 | xargs -r kill -9 2>/dev/null

# Kill proxy process
netstat -tlnp 2>/dev/null | grep ":$proxy_port " | awk '{print $7}' | cut -d/ -f1 | xargs -r kill -9 2>/dev/null

# Remove iptables rules
iptables -t nat -D PREROUTING -i "$interface" -p tcp --dport 53 -j REDIRECT --to-port "$dns_port" 2>/dev/null
iptables -t nat -D PREROUTING -i "$interface" -p udp --dport 53 -j REDIRECT --to-port "$dns_port" 2>/dev/null
iptables -t nat -D PREROUTING -i "$interface" -p tcp --dport "$http_port" -j REDIRECT --to-port "$proxy_port" 2>/dev/null
iptables -t filter -D FORWARD -i "$interface" -j DROP

echo "Captive portal stopped and iptables rules reverted."
