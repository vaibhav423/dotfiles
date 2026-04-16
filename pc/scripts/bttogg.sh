#!/bin/bash

# Get the current power state of the first Bluetooth adapter
# We check 'rfkill' because it's more authoritative than bluetoothctl
IS_BLOCKED=$(rfkill list bluetooth | grep -i "soft blocked: yes")

if [ -n "$IS_BLOCKED" ]; then
    echo "Bluetooth is currently OFF. Powering ON..."
    # 1. Lift the software block
    sudo rfkill unblock bluetooth
    # 2. Give the kernel a moment to initialize the driver
    sleep 1
    # 3. Tell the Bluetooth daemon to power up the radio
    bluetoothctl power on
else
    echo "Bluetooth is currently ON. Powering OFF..."
    # 1. Turn off the radio via the daemon
    bluetoothctl power off
    # 2. Apply a software block to save power/properly reset
    sudo rfkill block bluetooth
fi
