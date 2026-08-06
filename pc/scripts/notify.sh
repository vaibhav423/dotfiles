#!/bin/bash
  # Check if a command was provided
  if [ -z "$1" ]; then
    echo "Usage: kitty_output <command_to_run>"
    return 1
  fi

  # Construct the full command to execute
  command_to_run="$@"

  # Use 'kitty' to open a new terminal window:
  # 1. '--title "Output: $command_to_run"' sets the window title.
  # 2. 'bash -c "..."' runs the following commands in a subshell.
  # 3. '($command_to_run) 2>&1' executes the input command and redirects 
  #    standard error (2) to standard output (1).
  # 4. 'cat' reads the output from the pipe/previous command.
  # 5. 'echo -e "\n--- Press Enter to exit ---"' adds a clear prompt.
  # 6. 'read -r' waits for the user to press Enter before the subshell exits, 
  #    keeping the window open.
  kitty --class "noti"  --title "Output: $command_to_run" bash -c "
    ($command_to_run) 2>&1 | cat
    sleep 5
  "
