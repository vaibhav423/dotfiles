#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import re
import shlex
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Config:
    interface: str = os.environ.get("CAPTIV_INTERFACE", "wlan2")
    proxy_port: int = int(os.environ.get("CAPTIV_PROXY_PORT", "8080"))
    dns_port: int = int(os.environ.get("CAPTIV_DNS_PORT", "1053"))
    http_port: int = int(os.environ.get("CAPTIV_HTTP_PORT", "80"))
    https_port: int = int(os.environ.get("CAPTIV_HTTPS_PORT", "443"))
    kick_clients: bool = os.environ.get("CAPTIV_KICK_CLIENTS", "0") == "1"
    rst_helper: bool = os.environ.get("CAPTIV_RST_HELPER", "1") == "1"
    chroot_root: Path = Path(os.environ.get("ASU_CHROOT_ROOT", "/data/local/tmp/archl"))
    pid_file: Path = Path(os.environ.get("CAPTIV_PID_FILE", "/data/local/tmp/captiv-dnsmasq.pid"))
    log_file: Path = Path(os.environ.get("CAPTIV_LOG_FILE", "/data/local/tmp/captiv-dnsmasq.log"))
    debug_log_file: Path = Path(os.environ.get("CAPTIV_DEBUG_LOG_FILE", "/data/local/tmp/captiv-debug.log"))
    rst_pid_file: Path = Path(os.environ.get("CAPTIV_RST_PID_FILE", "/data/local/tmp/captiv-rst.pid"))
    rst_log_file: Path = Path(os.environ.get("CAPTIV_RST_LOG_FILE", "/data/local/tmp/captiv-rst.log"))
    offload_state_file: Path = Path(
        os.environ.get("CAPTIV_OFFLOAD_STATE_FILE", "/data/local/tmp/captiv-tether-offload.prev")
    )
    tcp_loose_state_file: Path = Path(
        os.environ.get("CAPTIV_TCP_LOOSE_STATE_FILE", "/data/local/tmp/captiv-nf_conntrack_tcp_loose.prev")
    )
    python_bin: str = os.environ.get("CAPTIV_PYTHON_BIN", "/usr/bin/python3.14")


SCRIPT_PATH = Path(__file__).resolve()
SCRIPT_DIR = SCRIPT_PATH.parent
RST_HELPER_PATH = (SCRIPT_DIR / "captiv-rst.py").resolve()
CONFIG = Config()


def run(
    cmd: list[str], *, check: bool = True, capture: bool = False, quiet: bool = False
) -> subprocess.CompletedProcess[str]:
    stdout = subprocess.PIPE if capture else (subprocess.DEVNULL if quiet else None)
    stderr = subprocess.PIPE if capture else (subprocess.DEVNULL if quiet else None)
    return subprocess.run(
        cmd,
        check=check,
        text=True,
        stdout=stdout,
        stderr=stderr,
    )


def run_sudo(
    cmd: list[str], *, check: bool = True, capture: bool = False, quiet: bool = False
) -> subprocess.CompletedProcess[str]:
    return run(["sudo", *cmd], check=check, capture=capture, quiet=quiet)


def run_asu(
    script: str, *, check: bool = True, capture: bool = False, quiet: bool = False
) -> subprocess.CompletedProcess[str]:
    return run(["asu", "-c", script], check=check, capture=capture, quiet=quiet)


def shell_quote(value: str) -> str:
    return shlex.quote(value)


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


def read_text(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8").strip()
    except FileNotFoundError:
        return None


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def debug_log(message: str) -> None:
    ensure_parent(CONFIG.debug_log_file)
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    with CONFIG.debug_log_file.open("a", encoding="utf-8") as handle:
        handle.write(f"[{timestamp}] {message}\n")


def debug_run_asu(label: str, script: str) -> None:
    result = run_asu(script, capture=True, check=False)
    debug_log(f"{label}: rc={result.returncode}")
    if result.stdout.strip():
        debug_log(f"{label} stdout:\n{result.stdout.rstrip()}")
    if result.stderr.strip():
        debug_log(f"{label} stderr:\n{result.stderr.rstrip()}")


def wait_for_pid_file(path: Path, timeout: float = 5.0) -> str | None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        pid = read_text(path)
        if pid:
            return pid
        time.sleep(0.2)
    return None


def find_dnsmasq_pid() -> str | None:
    result = run_asu(
        (
            "ps -A -o pid,args 2>/dev/null | "
            f"grep '[d]nsmasq --no-resolv --local-ttl=5 --neg-ttl=5 --port={CONFIG.dns_port} ' | "
            f"grep -- '--interface={CONFIG.interface} ' | awk '{{print $1}}' | head -n 1"
        ),
        capture=True,
        check=False,
    )
    pid = result.stdout.strip()
    return pid or None


def get_gateway_ip_and_prefix() -> tuple[str, int]:
    result = run_asu(
        f"ip -4 -o addr show dev {shell_quote(CONFIG.interface)} | head -n 1",
        capture=True,
    )
    line = result.stdout.strip()
    if not line:
        raise RuntimeError(f"Could not find IPv4 address for {CONFIG.interface}")

    parts = line.split()
    if len(parts) < 4 or "/" not in parts[3]:
        raise RuntimeError(f"Unexpected ip output for {CONFIG.interface}: {line}")
    address, prefix_len = parts[3].split("/", 1)
    return address, int(prefix_len)


def get_client_ips() -> list[str]:
    result = run_asu(f"ip neigh show dev {shell_quote(CONFIG.interface)}", capture=True)
    clients: list[str] = []
    for line in result.stdout.splitlines():
        parts = line.split()
        if parts and re.match(r"^\d+\.\d+\.\d+\.\d+$", parts[0]):
            clients.append(parts[0])
    return sorted(set(clients))


def get_client_macs() -> list[str]:
    result = run_asu("dumpsys tethering 2>/dev/null | sed -n '/Client Information:/,/IPv4 Upstream Indices:/p'", capture=True)
    macs = re.findall(r"client:\s*/\d+\.\d+\.\d+\.\d+\s*\(([0-9a-f:]{17})\)", result.stdout, flags=re.IGNORECASE)
    return sorted(set(macs))


def save_offload_state() -> None:
    if CONFIG.offload_state_file.exists():
        return
    result = run_asu("settings get global tether_offload_disabled", capture=True)
    value = result.stdout.strip() or "null"
    ensure_parent(CONFIG.offload_state_file)
    write_text(CONFIG.offload_state_file, value + "\n")


def restore_offload_state() -> None:
    previous = read_text(CONFIG.offload_state_file)
    if previous is None:
        return
    CONFIG.offload_state_file.unlink(missing_ok=True)
    if previous in ("", "null"):
        run_asu("settings delete global tether_offload_disabled >/dev/null 2>&1 || true")
    else:
        run_asu(f"settings put global tether_offload_disabled {shell_quote(previous)} >/dev/null 2>&1 || true")


def save_tcp_loose_state() -> None:
    if CONFIG.tcp_loose_state_file.exists():
        return
    result = run_asu("cat /proc/sys/net/netfilter/nf_conntrack_tcp_loose", capture=True)
    value = result.stdout.strip() or "1"
    ensure_parent(CONFIG.tcp_loose_state_file)
    write_text(CONFIG.tcp_loose_state_file, value + "\n")


def restore_tcp_loose_state() -> None:
    previous = read_text(CONFIG.tcp_loose_state_file)
    if previous is None:
        return
    CONFIG.tcp_loose_state_file.unlink(missing_ok=True)
    if previous in {"0", "1"}:
        run_asu(f"echo {previous} >/proc/sys/net/netfilter/nf_conntrack_tcp_loose 2>/dev/null || true")


def stop_dnsmasq() -> None:
    pid = read_text(CONFIG.pid_file)
    if pid:
        run_asu(f"kill {shell_quote(pid)} 2>/dev/null || true")
    CONFIG.pid_file.unlink(missing_ok=True)
    stale = find_dnsmasq_pid()
    if stale:
        run_asu(f"kill {shell_quote(stale)} 2>/dev/null || true")
    run_asu(
        (
            f"netstat -tlnp 2>/dev/null | grep ':{CONFIG.dns_port} ' | "
            "awk '{print $7}' | cut -d/ -f1 | xargs -r kill -9 2>/dev/null || true"
        )
    )


def stop_proxy() -> None:
    run_asu(
        (
            f"netstat -tlnp 2>/dev/null | grep ':{CONFIG.proxy_port} ' | "
            "awk '{print $7}' | cut -d/ -f1 | xargs -r kill -9 2>/dev/null || true"
        )
    )


def stop_rst_helper() -> None:
    pid = read_text(CONFIG.rst_pid_file)
    if pid:
        try:
            run_sudo(["kill", pid], check=False, quiet=True)
        finally:
            CONFIG.rst_pid_file.unlink(missing_ok=True)

    stale = run_sudo(["pgrep", "-f", str(RST_HELPER_PATH)], check=False, capture=True)
    for line in stale.stdout.splitlines():
        line = line.strip()
        if line:
            run_sudo(["kill", line], check=False, quiet=True)


def iptables_delete_commands() -> list[str]:
    return [
        f"iptables -w 5 -t nat -D PREROUTING -i {CONFIG.interface} -p tcp --dport 53 -j REDIRECT --to-port {CONFIG.dns_port} 2>/dev/null || true",
        f"iptables -w 5 -t nat -D PREROUTING -i {CONFIG.interface} -p udp --dport 53 -j REDIRECT --to-port {CONFIG.dns_port} 2>/dev/null || true",
        f"iptables -w 5 -t nat -D PREROUTING -i {CONFIG.interface} -p tcp --dport {CONFIG.http_port} -j REDIRECT --to-port {CONFIG.proxy_port} 2>/dev/null || true",
        (
            f"iptables -w 5 -t filter -D FORWARD -i {CONFIG.interface} -p udp --dport {CONFIG.https_port} "
            "-j REJECT --reject-with icmp-port-unreachable 2>/dev/null || true"
        ),
        (
            f"iptables -w 5 -t filter -D FORWARD -i {CONFIG.interface} -p tcp --dport {CONFIG.https_port} "
            "-j REJECT --reject-with tcp-reset 2>/dev/null || true"
        ),
        f"iptables -w 5 -t filter -D FORWARD -i {CONFIG.interface} -j DROP 2>/dev/null || true",
        f"iptables -w 5 -t filter -D FORWARD -o {CONFIG.interface} -j DROP 2>/dev/null || true",
        f"ip6tables -w 5 -t filter -D FORWARD -i {CONFIG.interface} -j REJECT 2>/dev/null || true",
        f"ip6tables -w 5 -t filter -D FORWARD -o {CONFIG.interface} -j REJECT 2>/dev/null || true",
    ]


def iptables_add_commands() -> list[str]:
    return [
        f"iptables -w 5 -t nat -I PREROUTING -i {CONFIG.interface} -p tcp --dport 53 -j REDIRECT --to-port {CONFIG.dns_port}",
        f"iptables -w 5 -t nat -I PREROUTING -i {CONFIG.interface} -p udp --dport 53 -j REDIRECT --to-port {CONFIG.dns_port}",
        f"iptables -w 5 -t nat -I PREROUTING -i {CONFIG.interface} -p tcp --dport {CONFIG.http_port} -j REDIRECT --to-port {CONFIG.proxy_port}",
        f"iptables -w 5 -t filter -I FORWARD -o {CONFIG.interface} -j DROP",
        f"iptables -w 5 -t filter -I FORWARD -i {CONFIG.interface} -j DROP",
        (
            f"iptables -w 5 -t filter -I FORWARD -i {CONFIG.interface} -p udp --dport {CONFIG.https_port} "
            "-j REJECT --reject-with icmp-port-unreachable"
        ),
        (
            f"iptables -w 5 -t filter -I FORWARD -i {CONFIG.interface} -p tcp --dport {CONFIG.https_port} "
            "-j REJECT --reject-with tcp-reset"
        ),
        f"ip6tables -w 5 -t filter -I FORWARD -i {CONFIG.interface} -j REJECT",
        f"ip6tables -w 5 -t filter -I FORWARD -o {CONFIG.interface} -j REJECT",
    ]


def apply_rules() -> None:
    run_asu("; ".join([*iptables_delete_commands(), *iptables_add_commands()]))


def remove_rules() -> None:
    run_asu("; ".join(iptables_delete_commands()))


def kick_clients() -> None:
    if not CONFIG.kick_clients:
        debug_log("client kick disabled")
        return
    debug_log("kicking connected clients from wlan2")
    for mac in get_client_macs():
        run_asu(f"iw dev {shell_quote(CONFIG.interface)} station del {shell_quote(mac)} >/dev/null 2>&1 || true")


def clear_conntrack() -> None:
    for client_ip in get_client_ips():
        result = run_sudo(["conntrack", "-L", "-o", "extended"], capture=True)
        for line in result.stdout.splitlines():
            if f"src={client_ip} " not in line:
                continue

            proto_match = re.search(r"\b(tcp|udp)\b", line)
            if not proto_match:
                continue
            proto = proto_match.group(1)

            fields = dict(re.findall(r"(src|dst|sport|dport)=([^\s]+)", line))
            if fields.get("src") != client_ip:
                continue
            if fields.get("dport") not in {"53", "80", "443"}:
                continue

            cmd = [
                "conntrack",
                "-D",
                "-p",
                proto,
                "--orig-src",
                fields["src"],
                "--orig-dst",
                fields["dst"],
                "--sport",
                fields["sport"],
                "--dport",
                fields["dport"],
            ]
            run_sudo(cmd, check=False, quiet=True)

        run_sudo(["conntrack", "-D", "-s", client_ip], check=False, quiet=True)


def start_rst_helper(gateway_ip: str, prefix_len: int) -> None:
    if not CONFIG.rst_helper:
        return
    if not RST_HELPER_PATH.exists():
        return

    stop_rst_helper()
    ensure_parent(CONFIG.rst_log_file)
    with CONFIG.rst_log_file.open("w", encoding="utf-8") as log_handle:
        process = subprocess.Popen(
            [
                "sudo",
                "chroot",
                str(CONFIG.chroot_root),
                CONFIG.python_bin,
                str(RST_HELPER_PATH),
                CONFIG.interface,
                gateway_ip,
                str(prefix_len),
            ],
            stdin=subprocess.DEVNULL,
            stdout=log_handle,
            stderr=subprocess.STDOUT,
            start_new_session=True,
            text=True,
        )

    ensure_parent(CONFIG.rst_pid_file)
    write_text(CONFIG.rst_pid_file, f"{process.pid}\n")
    deadline = time.monotonic() + 5.0
    while time.monotonic() < deadline:
        if process.poll() is not None:
            break
        check = run_sudo(["kill", "-0", str(process.pid)], check=False, quiet=True)
        if check.returncode == 0:
            return
        time.sleep(0.2)
    if process.poll() is not None:
        raise RuntimeError(f"RST helper failed to start. See {CONFIG.rst_log_file}")
    raise RuntimeError(f"RST helper did not stay reachable. See {CONFIG.rst_log_file}")


def start_dnsmasq(gateway_ip: str) -> None:
    ensure_parent(CONFIG.log_file)
    command = (
        f"rm -f {shell_quote(str(CONFIG.log_file))}; "
        f"setsid dnsmasq --no-resolv --local-ttl=5 --neg-ttl=5 --port={CONFIG.dns_port} "
        f"--interface={CONFIG.interface} --address=/#/{gateway_ip} --pid-file={shell_quote(str(CONFIG.pid_file))} "
        f">{shell_quote(str(CONFIG.log_file))} 2>&1 < /dev/null & "
        "sleep 1"
    )
    debug_log(f"dnsmasq launch command: {command}")
    result = run_asu(command, capture=True, check=False)
    debug_log(f"dnsmasq launch rc={result.returncode}")
    if result.stdout.strip():
        debug_log(f"dnsmasq launch stdout:\n{result.stdout.rstrip()}")
    if result.stderr.strip():
        debug_log(f"dnsmasq launch stderr:\n{result.stderr.rstrip()}")
    if result.returncode != 0:
        raise RuntimeError(
            f"dnsmasq launch command failed. See {CONFIG.log_file} and {CONFIG.debug_log_file}"
        )

    pid = wait_for_pid_file(CONFIG.pid_file)
    debug_log(f"dnsmasq pid file result: {pid or '<missing>'}")
    if not pid:
        pid = find_dnsmasq_pid()
        debug_log(f"dnsmasq process search result: {pid or '<missing>'}")
        if pid:
            ensure_parent(CONFIG.pid_file)
            write_text(CONFIG.pid_file, f"{pid}\n")
    if not pid:
        debug_run_asu(
            "dnsmasq startup diagnostics",
            (
                f"ls -l {shell_quote(str(CONFIG.pid_file))} {shell_quote(str(CONFIG.log_file))} 2>&1; "
                "ps -A -o pid,user,args 2>/dev/null | grep '[d]nsmasq'; "
                f"netstat -tlnp 2>/dev/null | grep ':{CONFIG.dns_port} ' || true; "
                f"sed -n '1,40p' {shell_quote(str(CONFIG.log_file))} 2>/dev/null || true"
            ),
        )
        raise RuntimeError(
            f"dnsmasq failed to start. See {CONFIG.log_file} and {CONFIG.debug_log_file}"
        )

    deadline = time.monotonic() + 5.0
    while time.monotonic() < deadline:
        check = run_asu(f"kill -0 {shell_quote(pid)} >/dev/null 2>&1", check=False)
        debug_log(f"dnsmasq kill -0 check for pid {pid}: rc={check.returncode}")
        if check.returncode == 0:
            return
        time.sleep(0.2)

    debug_run_asu(
        "dnsmasq liveness diagnostics",
        (
            f"ls -l {shell_quote(str(CONFIG.pid_file))} {shell_quote(str(CONFIG.log_file))} 2>&1; "
            "ps -A -o pid,user,args 2>/dev/null | grep '[d]nsmasq'; "
            f"netstat -tlnp 2>/dev/null | grep ':{CONFIG.dns_port} ' || true; "
            f"sed -n '1,40p' {shell_quote(str(CONFIG.log_file))} 2>/dev/null || true"
        ),
    )
    if check.returncode != 0:
        raise RuntimeError(
            f"dnsmasq failed to start. See {CONFIG.log_file} and {CONFIG.debug_log_file}"
        )


def start() -> int:
    ensure_parent(CONFIG.debug_log_file)
    with CONFIG.debug_log_file.open("w", encoding="utf-8") as handle:
        handle.write("")
    debug_log(f"start requested from cwd={Path.cwd()}")
    stop_dnsmasq()
    stop_proxy()
    stop_rst_helper()
    save_offload_state()
    save_tcp_loose_state()
    run_asu("settings put global tether_offload_disabled 1 >/dev/null 2>&1 || true")
    run_asu("echo 0 >/proc/sys/net/netfilter/nf_conntrack_tcp_loose 2>/dev/null || true")
    apply_rules()
    clear_conntrack()
    gateway_ip, prefix_len = get_gateway_ip_and_prefix()
    debug_log(f"gateway={gateway_ip}/{prefix_len} interface={CONFIG.interface}")
    kick_clients()
    start_rst_helper(gateway_ip, prefix_len)
    print(f"Starting dnsmasq to resolve all domains to {gateway_ip}")
    start_dnsmasq(gateway_ip)
    return 0


def stop() -> int:
    stop_dnsmasq()
    stop_proxy()
    remove_rules()
    stop_rst_helper()
    restore_offload_state()
    restore_tcp_loose_state()
    print("Captive portal stopped and iptables rules reverted.")
    return 0


def status() -> int:
    dns_pid = read_text(CONFIG.pid_file) or "<none>"
    rst_pid = read_text(CONFIG.rst_pid_file) or "<none>"
    print(f"dnsmasq pid: {dns_pid}")
    print(f"rst helper pid: {rst_pid}")
    run_asu("iptables -w 5 -L FORWARD -n -v | sed -n '1,12p'")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Captive portal controller")
    parser.add_argument("command", choices=["start", "stop", "status"])
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.command == "start":
        return start()
    if args.command == "stop":
        return stop()
    return status()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        raise SystemExit(exc.returncode)
    except ProcessLookupError:
        raise SystemExit(1)
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)
