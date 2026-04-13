#!/usr/bin/env python3
import sys
import time
import argparse
import subprocess
import os

# USB HID Key mappings
KEY_MAP = {
    'a': ['0x04'], 'b': ['0x05'], 'c': ['0x06'], 'd': ['0x07'], 'e': ['0x08'], 'f': ['0x09'],
    'g': ['0x0A'], 'h': ['0x0B'], 'i': ['0x0C'], 'j': ['0x0D'], 'k': ['0x0E'], 'l': ['0x0F'],
    'm': ['0x10'], 'n': ['0x11'], 'o': ['0x12'], 'p': ['0x13'], 'q': ['0x14'], 'r': ['0x15'],
    's': ['0x16'], 't': ['0x17'], 'u': ['0x18'], 'v': ['0x19'], 'w': ['0x1A'], 'x': ['0x1B'],
    'y': ['0x1C'], 'z': ['0x1D'],
    
    'A': ['0xe1', '0x04'], 'B': ['0xe1', '0x05'], 'C': ['0xe1', '0x06'], 'D': ['0xe1', '0x07'],
    'E': ['0xe1', '0x08'], 'F': ['0xe1', '0x09'], 'G': ['0xe1', '0x0A'], 'H': ['0xe1', '0x0B'],
    'I': ['0xe1', '0x0C'], 'J': ['0xe1', '0x0D'], 'K': ['0xe1', '0x0E'], 'L': ['0xe1', '0x0F'],
    'M': ['0xe1', '0x10'], 'N': ['0xe1', '0x11'], 'O': ['0xe1', '0x12'], 'P': ['0xe1', '0x13'],
    'Q': ['0xe1', '0x14'], 'R': ['0xe1', '0x15'], 'S': ['0xe1', '0x16'], 'T': ['0xe1', '0x17'],
    'U': ['0xe1', '0x18'], 'V': ['0xe1', '0x19'], 'W': ['0xe1', '0x1A'], 'X': ['0xe1', '0x1B'],
    'Y': ['0xe1', '0x1C'], 'Z': ['0xe1', '0x1D'],
    
    '1': ['0x1E'], '2': ['0x1F'], '3': ['0x20'], '4': ['0x21'], '5': ['0x22'],
    '6': ['0x23'], '7': ['0x24'], '8': ['0x25'], '9': ['0x26'], '0': ['0x27'],
    
    '!': ['0xe1', '0x1E'], '@': ['0xe1', '0x1F'], '#': ['0xe1', '0x20'], '$': ['0xe1', '0x21'],
    '%': ['0xe1', '0x22'], '^': ['0xe1', '0x23'], '&': ['0xe1', '0x24'], '*': ['0xe1', '0x25'],
    '(': ['0xe1', '0x26'], ')': ['0xe1', '0x27'],
    
    '-': ['0x2D'], '=': ['0x2E'], '[': ['0x2F'], ']': ['0x30'], '\\': ['0x64'],
    ';': ['0x33'], "'": ['0x34'], ',': ['0x36'], '.': ['0x37'], '/': ['0x38'],
    '`': ['0x35'], ' ': ['0x2C'],
    
    '_': ['0xe1', '0x2D'], '+': ['0xe1', '0x2E'], '{': ['0xe1', '0x2F'], '}': ['0xe1', '0x30'],
    '|': ['0xe1', '0x64'], ':': ['0xe1', '0x33'], '"': ['0xe1', '0x34'], '<': ['0xe1', '0x36'],
    '>': ['0xe1', '0x37'], '?': ['0xe1', '0x38'], '~': ['0xe1', '0x35'],
    
    '\n': ['0x28'], # Enter key
    '\t': ['0x2B']  # Tab key
}

def main():
    parser = argparse.ArgumentParser(description="Send keystrokes to a libvirt VM from a file.")
    parser.add_argument("vm_name", help="Name of the target virtual machine")
    parser.add_argument("-f", "--file", default="/home/ixdire/foo.txt", help="Path to the text file (default: /home/ixdire/foo.txt)")
    parser.add_argument("--holdtime", type=int, default=100, help="Hold time for keystrokes in ms (default: 100)")
    parser.add_argument("--pause-ms", type=float, default=10.0, help="Pause time after space in ms (default: 10.0)")
    
    args = parser.parse_args()

    if not os.path.isfile(args.file):
        print(f"Error: File not found: {args.file}", file=sys.stderr)
        sys.exit(1)

    with open(args.file, 'r') as f:
        content = f.read()

    pause_time_sec = args.pause_ms / 1000.0
    
    # Wait for the holdtime plus a tiny buffer to ensure keyup is processed
    key_delay_sec = (args.holdtime / 1000.0) + 0.05
    
    was_shifted = False

    for char in content:
        if char not in KEY_MAP:
            continue
        
        codes = KEY_MAP[char]
        is_shifted = len(codes) > 1 and codes[0] == '0xe1'
        
        # If we are transitioning from a shifted to an unshifted character,
        # add an extra small delay to ensure the OS has fully processed the Shift-Release
        if was_shifted and not is_shifted:
            time.sleep(0.05)
        
        cmd = ["virsh", "send-key", args.vm_name, "--codeset", "usb"] + codes + ["--holdtime", str(args.holdtime)]
        
        # Execute the virsh command (stdout and stderr are suppressed to devnull)
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        # Wait for the virtual key press to fully complete (keydown AND keyup)
        # before sending the next key, otherwise modifier keys like Shift overlap and get stuck.
        time.sleep(key_delay_sec)

        if char == " ":
            time.sleep(pause_time_sec)
            
        was_shifted = is_shifted

if __name__ == "__main__":
    main()
