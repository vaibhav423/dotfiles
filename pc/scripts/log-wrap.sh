#!/bin/bash
# Wrapper to run commands live in Kitty, log them, and wait 5 seconds.

LOG_FILE="/home/ixdire/Water/crap/scripts/git.log"

if [ -z "$1" ]; then
  echo "Usage: $0 <command>"
  exit 1
fi

# Join all arguments into a single command string
COMMAND="$@"

# Launch kitty:
# 1. --class "noti" for your window rules.
# 2. stdbuf -oL ensures line-buffering so you see output instantly.
# 3. tee overwrites the log (standard behavior of your original command).
kitty --class "noti" --title "Task: $COMMAND" bash -c "
  echo \"--- Starting: $COMMAND ---\"
  (eval \"$COMMAND\") 2>&1 | stdbuf -oL tee \"$LOG_FILE\"
  echo -e \"\n--- Finished. Closing in 5 seconds ---\"
  sleep 5
"
