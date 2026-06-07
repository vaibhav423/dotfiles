#!/bin/sh

display=":0"
pid_file="/tmp/xvnc-$USER.pid"

if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    echo "Killing Xvnc$display and related processes..."
    kill "$(cat "$pid_file")" 2>/dev/null
    pkill -f "Xvnc $display" 2>/dev/null
    pkill -f "xfwm4" 2>/dev/null
    rm -f "$pid_file"
else
    echo "Starting Xvnc$display..."
    Xvnc "$display" -geometry 1920x1080 -rfbauth ~/.config/tigervnc/passwd &
    xvnc_pid=$!
    echo "$xvnc_pid" > "$pid_file"
    sleep 1
    export DISPLAY=:0
    dbus-launch xfwm4 &
fi
