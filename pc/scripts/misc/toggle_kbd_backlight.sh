#!/usr/bin/env bash
# Toggle or control the platform::kbd_backlight LED safely.
# Usage:
#   sudo ./toggle_kbd_backlight.sh toggle
#   sudo ./toggle_kbd_backlight.sh on [level]
#   sudo ./toggle_kbd_backlight.sh off
#   sudo ./toggle_kbd_backlight.sh restore
#
# The script saves the original trigger to /tmp and by default leaves the
# trigger set to "none" so manual brightness changes persist. Use "restore"
# to restore the original trigger value.

LED="platform::kbd_backlight"
SYS="/sys/class/leds/$LED"
ORIG_TRIGGER_FILE="/tmp/${LED//:/_}_trigger.orig"

die() { echo "$*" >&2; exit 1; }

if [ ! -d "$SYS" ]; then
  die "LED device not found: $SYS"
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
  if read_trigger_raw | grep -q "\[none\]\|none"; then
    echo "trigger already allows manual control"
  else
    echo "Setting trigger to 'none' to allow manual control"
    printf "none" | sudo tee "$SYS/trigger" >/dev/null
  fi
}

restore_trigger() {
  if [ -f "$ORIG_TRIGGER_FILE" ]; then
    orig=$(cat "$ORIG_TRIGGER_FILE")
    if [ -n "$orig" ]; then
      echo "Restoring original trigger"
      printf "%s" "$orig" | sudo tee "$SYS/trigger" >/dev/null
      echo "Restored trigger to: $orig"
      exit 0
    fi
  fi
  echo "No saved original trigger found at $ORIG_TRIGGER_FILE"
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
  printf "%s" "$level" | sudo tee "$SYS/brightness" >/dev/null
  echo "brightness -> $level"
}

toggle() {
  cur=$(read_current)
  max=$(read_max)
  if [ "$cur" -eq 0 ]; then
    set_brightness "$max"
  else
    set_brightness 0
  fi
}

case "$1" in
  toggle|"")
    save_orig_trigger
    set_trigger_none
    toggle
    ;;
  on)
    level="$2"
    if [ -z "$level" ]; then
      level=$(read_max)
    fi
    save_orig_trigger
    set_trigger_none
    set_brightness "$level"
    ;;
  off)
    save_orig_trigger
    set_trigger_none
    set_brightness 0
    ;;
  restore)
    restore_trigger
    ;;
  *)
    echo "Unknown command: $1"
    echo "Usage: $0 [toggle|on [level]|off|restore]"
    exit 2
    ;;
esac

# Show current state
echo "current brightness: $(read_current)"
echo "max_brightness: $(read_max)"
echo "available trigger: $(read_trigger_raw)"
