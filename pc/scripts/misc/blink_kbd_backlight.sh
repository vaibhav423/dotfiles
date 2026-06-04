#!/usr/bin/env bash
# Blink platform::kbd_backlight a number of times over a total duration.
# Default: 10 blinks in 5 seconds (0.25s on, 0.25s off)
#
# Usage:
#   sudo ./blink_kbd_backlight.sh
#   sudo ./blink_kbd_backlight.sh <count> <total_seconds>
#
LED="platform::kbd_backlight"
SYS="/sys/class/leds/$LED"
ORIG_TRIGGER_FILE="/tmp/${LED//:/_}_trigger.orig"

die() { echo "$*" >&2; exit 1; }

if [ ! -d "$SYS" ]; then
  die "LED device not found: $SYS"
fi

# Detect whether to prefix tee with sudo (if not running as root)
if [ "$EUID" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

read_current() {
  cat "$SYS/brightness" 2>/dev/null || echo "0"
}
read_max() {
  cat "$SYS/max_brightness" 2>/dev/null || echo "1"
}
read_trigger_raw() {
  cat "$SYS/trigger" 2>/dev/null || echo ""
}

save_orig_trigger() {
  if [ ! -f "$ORIG_TRIGGER_FILE" ]; then
    read_trigger_raw > "$ORIG_TRIGGER_FILE"
  fi
}

set_trigger_none() {
  # if none is already available in trigger listing, write none
  if read_trigger_raw | grep -q "\[none\]\|none"; then
    printf "none" | $SUDO tee "$SYS/trigger" >/dev/null
  else
    echo "warning: 'none' not in available triggers; manual control may not work"
  fi
}

restore_trigger() {
  if [ -f "$ORIG_TRIGGER_FILE" ]; then
    orig=$(cat "$ORIG_TRIGGER_FILE")
    if [ -n "$orig" ]; then
      printf "%s" "$orig" | $SUDO tee "$SYS/trigger" >/dev/null
      echo "Restored trigger to: $orig"
      return 0
    fi
  fi
  echo "No saved original trigger found at $ORIG_TRIGGER_FILE"
}

set_brightness_write() {
  level="$1"
  printf "%s" "$level" | $SUDO tee "$SYS/brightness" >/dev/null
}

set_brightness() {
  level="$1"
  if ! printf "%s" "$level" | grep -qE '^[0-9]+$'; then
    die "brightness must be numeric"
  fi
  max=$(read_max)
  if [ "$level" -gt "$max" ]; then
    die "level $level > max_brightness $max"
  fi
  set_brightness_write "$level"
}

# defaults
COUNT="${1:-10}"
TOTAL_SEC="${2:-5}"

# Compute timings: each blink = on+off, so per-cycle = TOTAL_SEC/COUNT
# We'll split on/off equally.
if ! printf "%s" "$COUNT" | grep -qE '^[0-9]+$' || [ "$COUNT" -le 0 ]; then
  die "count must be a positive integer"
fi
if ! printf "%s" "$TOTAL_SEC" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
  die "total_seconds must be numeric"
fi

PER_CYCLE=$(awk "BEGIN { printf \"%.6f\", $TOTAL_SEC/$COUNT }")
# split equally
ON_TIME=$(awk "BEGIN { printf \"%.6f\", $PER_CYCLE/2 }")
OFF_TIME="$ON_TIME"

trap 'restore_trigger' EXIT

# Prepare
save_orig_trigger
set_trigger_none
max=$(read_max)
if [ -z "$max" ]; then
  max=1
fi

# Blink loop
i=0
while [ "$i" -lt "$COUNT" ]; do
  set_brightness "$max"
  sleep "$ON_TIME"
  set_brightness 0
  sleep "$OFF_TIME"
  i=$((i+1))
done

# Final: restore trigger (also done by trap)
restore_trigger

# show final state
echo "final brightness: $(read_current)"
echo "max_brightness: $(read_max)"
echo "available trigger: $(read_trigger_raw)"
