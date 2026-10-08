#!/bin/bash
# Open a foot window that shows the output of a command, then closes itself.
# Matched by the "noti" window rule in hypr/custom.lua.

# Check if a command was provided
if [ -z "$1" ]; then
  echo "Usage: notify.sh <command_to_run>"
  exit 1
fi

# Construct the full command to execute
command_to_run="$*"

# Use 'foot' to open a new terminal window:
# 1. '--app-id noti' sets the app id, which hyprland matches as the window class.
# 2. '--title "Output: ..."' sets the window title.
# 3. 'bash -c "..."' runs the following commands in a subshell.
# 4. '($command_to_run) 2>&1' executes the input command and redirects
#    standard error (2) to standard output (1).
# 5. 'cat' reads the output from the pipe/previous command.
# 6. 'sleep 5' keeps the window open so the output can be read.
foot --app-id noti --title "Output: $command_to_run" bash -c "
  ($command_to_run) 2>&1 | cat
  sleep 5
"