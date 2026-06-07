#!/bin/sh

proxy_port=8080
interface=wlan2
dns_port=1053
http_port=80
pid_file=${CAPTIV_PID_FILE:-/data/local/tmp/captiv-dnsmasq.pid}
log_file=${CAPTIV_LOG_FILE:-/data/local/tmp/captiv-dnsmasq.log}

# Kill old proxy process if any
netstat -tlnp | grep ":$proxy_port " | awk '{print $7}' | cut -d/ -f1 | xargs -r kill -9 2>/dev/null

# Kill our custom dnsmasq instance if it's running
if [ -f "$pid_file" ]; then
    kill $(cat "$pid_file") 2>/dev/null
    rm "$pid_file" 2>/dev/null
fi
# Just in case, kill any dnsmasq listening on our custom port
netstat -tlnp | grep ":$dns_port " | awk '{print $7}' | cut -d/ -f1 | xargs -r kill -9 2>/dev/null

# Setup iptables rules for captive portal
# Flush existing rules to avoid duplicates if script is run multiple times
iptables -t nat -D PREROUTING -i "$interface" -p tcp --dport 53 -j REDIRECT --to-port "$dns_port" 2>/dev/null
iptables -t nat -D PREROUTING -i "$interface" -p udp --dport 53 -j REDIRECT --to-port "$dns_port" 2>/dev/null
iptables -t nat -D PREROUTING -i "$interface" -p tcp --dport "$http_port" -j REDIRECT --to-port "$proxy_port" 2>/dev/null
iptables -t filter -D FORWARD -i "$interface" -j DROP 2>/dev/null

iptables -t nat -I PREROUTING -i "$interface" -p tcp --dport 53 -j REDIRECT --to-port "$dns_port"
iptables -t nat -I PREROUTING -i "$interface" -p udp --dport 53 -j REDIRECT --to-port "$dns_port"
iptables -t nat -I PREROUTING -i "$interface" -p tcp --dport "$http_port" -j REDIRECT --to-port "$proxy_port"
iptables -t filter -A FORWARD -i "$interface" -j DROP

# Start dnsmasq to spoof all DNS requests to the captive portal IPv4 address
IPV4_ADDR=$(ip -4 -o addr show dev "$interface" | head -n 1 | awk '{print $4}' | cut -d/ -f1)

if [ -z "$IPV4_ADDR" ]; then
    echo "Error: Could not find IPv4 address for $interface"
    exit 1
fi

echo "Starting dnsmasq to resolve all domains to $IPV4_ADDR"
rm -f "$log_file"
nohup dnsmasq --no-resolv --port="$dns_port" --interface="$interface" --address=/#/$IPV4_ADDR --pid-file="$pid_file" \
    >"$log_file" 2>&1 < /dev/null &

sleep 1

if [ ! -f "$pid_file" ] || ! kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    echo "Error: dnsmasq failed to start. See $log_file"
    exit 1
fi
