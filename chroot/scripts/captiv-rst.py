#!/usr/bin/env python3

import ipaddress
import signal
import sys

from scapy.all import IP, TCP, conf, send, sniff  # type: ignore


STOP = False
WEB_PORTS = {80, 443}


def handle_stop(signum, frame):
    global STOP
    STOP = True


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: captiv-rst.py <iface> <gateway-ip> <prefix-len>", file=sys.stderr)
        return 2

    iface = sys.argv[1]
    gateway_ip = sys.argv[2]
    prefix_len = sys.argv[3]
    gateway = ipaddress.ip_address(gateway_ip)
    network = ipaddress.ip_network(f"{gateway_ip}/{prefix_len}", strict=False)

    signal.signal(signal.SIGTERM, handle_stop)
    signal.signal(signal.SIGINT, handle_stop)
    conf.verb = 0

    def send_reset_burst(src_ip, dst_ip, sport, dport, seq, ack):
        seq_candidates = [seq, max(seq - 1, 0), seq + 1]
        packets = [TCP(sport=sport, dport=dport, flags="R", seq=value) for value in seq_candidates]
        if ack > 0:
            packets.append(TCP(sport=sport, dport=dport, flags="RA", seq=seq, ack=ack))

        for rst_tcp in packets:
            send(IP(src=src_ip, dst=dst_ip) / rst_tcp, verbose=False)

    def reset_both_directions(ip, tcp, next_seq):
        if tcp.ack > 0:
            send_reset_burst(ip.dst, ip.src, tcp.dport, tcp.sport, tcp.ack, next_seq)
        send_reset_burst(ip.src, ip.dst, tcp.sport, tcp.dport, tcp.seq, tcp.ack)

    def reset_flow(pkt):
        if STOP or IP not in pkt or TCP not in pkt:
            return

        ip = pkt[IP]
        tcp = pkt[TCP]

        try:
            src = ipaddress.ip_address(ip.src)
            dst = ipaddress.ip_address(ip.dst)
        except ValueError:
            return

        if src == gateway or dst == gateway:
            return

        client_to_remote = src in network and dst not in network and tcp.dport in WEB_PORTS
        remote_to_client = dst in network and src not in network and tcp.sport in WEB_PORTS

        if not client_to_remote and not remote_to_client:
            return

        payload_len = len(bytes(tcp.payload))
        next_seq = tcp.seq + payload_len
        if tcp.flags.S:
            next_seq += 1
        if tcp.flags.F:
            next_seq += 1

        reset_both_directions(ip, tcp, next_seq)

    print(f"captiv-rst watching {iface} for {network} via {gateway}", flush=True)
    while not STOP:
        sniff(
            iface=iface,
            prn=reset_flow,
            store=False,
            timeout=1,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
