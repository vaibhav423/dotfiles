# Place this at the very bottom of the config
export TERM=xterm-256color

# zoxide (nicer cd)
eval "$(zoxide init zsh)"

# ~/.local/bin and cargo on PATH (mirrors pc/zshrc/00-init)
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# ~/.secrets is optional on this machine - only source if present.
# pc/zshrc/999-endscript.zsh sources it unconditionally, which errors here.
[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"

# NOTE: no tmux auto-attach here.
# An unconditional tmux launch in ~/.zshrc previously broke the tty1 -> X login
# chain (it fired inside startx child shells). Start tmux manually: exec tmux
