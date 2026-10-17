#!/bin/sh

xrdb merge ~/.Xresources

# xbacklight is not installed; set brightness via sysfs instead
BL=/sys/class/backlight/intel_backlight/brightness
MAXB=/sys/class/backlight/intel_backlight/max_brightness
[ -w "$BL" ] && [ -r "$MAXB" ] && echo $(( $(cat "$MAXB") / 10 )) > "$BL" 2>/dev/null

xset r rate 200 50 &
picom &

dash ~/.config/chadwm/scripts/bar.sh &
while type chadwm >/dev/null; do chadwm && continue || break; done
