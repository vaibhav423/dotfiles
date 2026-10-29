#!/usr/bin/env bash
#
# ap.sh - turn the laptop's WiFi card into a 5 GHz access point, or turn it off.
#
#   sudo ap.sh up [ssid] [channel] [width]     start the AP (default: laptop 36 80)
#   sudo ap.sh down                            stop it, rejoin the old network
#   ap.sh status                               show current state (no root needed)
#
# Examples:
#   sudo ap.sh up                    -> SSID "laptop", ch 36, 80 MHz, open
#   sudo ap.sh up fire 149 80        -> SSID "fire",   ch 149, 80 MHz, open
#   sudo AP_PASS=hunter2 ap.sh up    -> same but WPA2 protected
#
# The card (MT7921) can only use one channel at a time, so starting the AP
# disconnects wlan0 from whatever network it was on. "down" puts it back.
#
# Tested on: Arch Linux, NetworkManager 1.58, MediaTek MT7921 (mt7921e).
#
set -euo pipefail

IFACE="${IFACE:-wlan0}"
STATE_FILE="/run/wifi-ap.previous"
DEFAULT_SSID="laptop"
DEFAULT_CHANNEL="36"
DEFAULT_WIDTH="80"

msg()  { printf '>> %s\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
need_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || die "must run as root (use sudo)"; }

# Name of the NetworkManager connection currently active on $IFACE (may be empty)
active_conn() {
    nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null \
        | awk -F: -v d="$IFACE" '$2 == d { print $1; exit }'
}

ap_profile()  { printf 'ap-%s' "${1:-$DEFAULT_SSID}"; }

cmd_up() {
    need_root
    local ssid="${1:-$DEFAULT_SSID}"
    local channel="${2:-$DEFAULT_CHANNEL}"
    local width="${3:-$DEFAULT_WIDTH}"
    local profile; profile="$(ap_profile "$ssid")"
    local prev; prev="$(active_conn)"

    command -v nmcli >/dev/null || die "NetworkManager (nmcli) not found"

    # Remember what we were on so 'down' can go back to it.
    if [[ -n "$prev" ]]; then
        printf '%s\n' "$prev" >"$STATE_FILE"
        msg "current connection '$prev' will be dropped ($IFACE supports one channel only)"
    fi

    msg "removing any previous '$profile' profile"
    nmcli connection delete "$profile" >/dev/null 2>&1 || true

    msg "creating AP profile (ssid='$ssid' 5GHz ch=$channel width=${width}MHz)"
    nmcli connection add type wifi ifname "$IFACE" con-name "$profile" ssid "$ssid" >/dev/null

    nmcli connection modify "$profile" 802-11-wireless.mode ap
    nmcli connection modify "$profile" 802-11-wireless.band a
    nmcli connection modify "$profile" 802-11-wireless.channel "$channel"
    nmcli connection modify "$profile" 802-11-wireless.channel-width "$width"
    nmcli connection modify "$profile" ipv4.method shared
    nmcli connection modify "$profile" ipv6.method ignore
    nmcli connection modify "$profile" connection.autoconnect no

    # Security.
    #
    # IMPORTANT: for an OPEN network you must REMOVE the 802-11-wireless-security
    # setting entirely. Setting 'wifi-sec.key-mgmt none' means *static WEP*, and
    # wpa_supplicant refuses WEP, so activation fails with the confusing
    # "profile is not compatible with device (wpa_supplicant does not support
    # WEP encryption)".
    if [[ -n "${AP_PASS:-}" ]]; then
        msg "security: WPA2-PSK"
        nmcli connection modify "$profile" wifi-sec.key-mgmt wpa-psk
        nmcli connection modify "$profile" wifi-sec.psk "$AP_PASS"
    else
        msg "security: open (no password)"
        nmcli connection modify "$profile" remove 802-11-wireless-security 2>/dev/null || true
    fi

    msg "activating (WiFi link will drop now)"
    if ! nmcli connection up "$profile"; then
        warn "AP failed to start - restoring '$prev'"
        cmd_restore
        die "AP activation failed, rolled back"
    fi

    sleep 2
    echo
    echo "── AP running ──"
    iw dev "$IFACE" info 2>/dev/null | grep -E 'ssid|type|channel|addr' | sed 's/^/   /'
    ip -4 -br addr show "$IFACE" | sed 's/^/   /'
    echo "   SSID : $ssid"
    echo "   open : $( [[ -n "${AP_PASS:-}" ]] && echo no || echo yes )"
    echo "   stop : sudo $0 down"
}

# Bring the previous network back (or let NetworkManager pick one).
cmd_restore() {
    local prev=""
    [[ -f "$STATE_FILE" ]] && prev="$(cat "$STATE_FILE")"

    if [[ -n "$prev" ]] && nmcli connection up "$prev" >/dev/null 2>&1; then
        msg "rejoined '$prev'"
    else
        msg "reconnecting $IFACE to any known network"
        nmcli device connect "$IFACE" >/dev/null 2>&1 || true
    fi
    rm -f "$STATE_FILE"
}

cmd_down() {
    need_root

    local ap; ap="$(nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null \
                        | awk -F: -v d="$IFACE" '$1 ~ /^ap-/ && $2 == d { print $1; exit }')"

    if [[ -n "$ap" ]]; then
        msg "stopping '$ap'"
        nmcli connection down "$ap" >/dev/null 2>&1 || true
    else
        msg "no active AP on $IFACE"
    fi

    cmd_restore
    sleep 1
    ip -4 -br addr show "$IFACE" | sed 's/^/   /'
}

cmd_status() {
    echo "── $IFACE ──"
    local t
    t="$(iw dev "$IFACE" info 2>/dev/null | awk '/type/{print $2; exit}')"
    if [[ "$t" == "AP" ]]; then
        echo "   mode    : AP (access point)"
        iw dev "$IFACE" info 2>/dev/null | grep -E 'ssid|channel' | sed 's/^/   /'
    else
        echo "   mode    : ${t:-unknown} (normal client)"
        iw dev "$IFACE" link 2>/dev/null | grep -E 'SSID|freq|signal' | sed 's/^/   /'
    fi
    ip -4 -br addr show "$IFACE" | sed 's/^/   /'

    echo "── active connections ──"
    nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null \
        | awk -F: -v d="$IFACE" '$2 == d' | sed 's/^/   /'
}

case "${1:-}" in
    up)            shift; cmd_up "$@" ;;
    down|off|stop) cmd_down ;;
    status)        cmd_status ;;
    *)
        cat <<EOF
usage: sudo $0 up [ssid] [channel] [width]
       sudo $0 down
       $0 status

  up      start a 5 GHz open AP (default SSID 'laptop', ch 36, 80 MHz)
  down    stop the AP and rejoin the previous network
  status  show the current WiFi mode

  AP_PASS=secret sudo $0 up    creates a WPA2 AP instead of an open one
EOF
        exit 1 ;;
esac
