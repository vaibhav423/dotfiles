#!/usr/bin/env bash
# Blink any LED under /sys/class/leds
# Usage:
#   sudo ./blink_led.sh NAME [count] [total_seconds]
# Example:
#   sudo ./blink_led.sh input2::capslock 10 5
LED="$1"
COUNT="${2:-10}"
TOTAL_SEC="${3:-5}"
SYS="/sys/class/leds/$LED"
ORIG="/tmp/${LED//:/_}_trigger.orig"

die(){ echo "$*" >&2; exit 1; }

[ -n "$LED" ] || die "Usage: $0 LED_NAME [count] [total_seconds]"

if [ ! -d "$SYS" ]; then
  die "LED not found: $SYS"
fi

read_trigger(){ cat "$SYS/trigger" 2>/dev/null || echo ""; }
read_brightness(){ cat "$SYS/brightness" 2>/dev/null || echo "0"; }
read_max(){ cat "$SYS/max_brightness" 2>/dev/null || echo "1"; }

save_orig(){
  if [ ! -f "$ORIG" ]; then
    read_trigger > "$ORIG"
  fi
}

set_none(){
  if read_trigger | grep -q "\[none\]\|none"; then
    printf "none" | sudo tee "$SYS/trigger" >/dev/null || true
  fi
}

restore(){
  if [ -f "$ORIG" ]; then
    orig=$(cat "$ORIG")
    if [ -n "$orig" ]; then
      printf "%s" "$orig" | sudo tee "$SYS/trigger" >/dev/null || true
    fi
  fi
}

set_bright(){
  val="$1"
  printf "%s" "$val" | sudo tee "$SYS/brightness" >/dev/null || true
}

# validation
if ! printf "%s" "$COUNT" | grep -qE '^[0-9]+$' || [ "$COUNT" -le 0 ]; then
  die "count must be positive integer"
fi
if ! printf "%s" "$TOTAL_SEC" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
  die "total_seconds must be numeric"
fi

PER=$(awk "BEGIN{printf \"%.6f\", $TOTAL_SEC/$COUNT}")
ON=$(awk "BEGIN{printf \"%.6f\", $PER/2}")
OFF="$ON"

trap 'restore' EXIT

save_orig
set_none
MAX=$(read_max)
if [ -z "$MAX" ]; then MAX=1; fi

i=0
while [ "$i" -lt "$COUNT" ]; do
  set_bright "$MAX"
  sleep "$ON"
  set_bright 0
  sleep "$OFF"
  i=$((i+1))
done

restore
echo "final brightness: $(read_brightness)"
echo "max_brightness: $(read_max)"
echo "trigger: $(read_trigger)"
