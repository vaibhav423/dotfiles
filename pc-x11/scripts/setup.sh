#!/usr/bin/env bash
# Setup for pc-x11 (Artix Linux, chadwm on X11, HP 246).
# Run AFTER the dotfiles repo is cloned to ~/dotfiles.
#
# Usage:  bash ~/dotfiles/pc-x11/scripts/setup.sh
set -euo pipefail

REPO="${REPO:-$HOME/dotfiles}"
X11="$REPO/pc-x11"

say() { printf '\n== %s ==\n' "$1"; }

[ -d "$X11" ] || { echo "ERROR: $X11 not found. Clone the dotfiles repo to ~/dotfiles first."; exit 1; }

say "Packages"
sudo pacman -S --needed --noconfirm neovim yazi ripgrep fd bat lazygit

say "Personal config"
mkdir -p "$HOME/.config/personal"
cp -n "$X11/personal/config.json" "$HOME/.config/personal/config.json" 2>/dev/null || true

say "Vault directories"
mkdir -p "$HOME/Water/Fire" "$HOME/Water/crap" "$HOME/doc"

say "Symlink live configs to the repo"
ln -sfn "$X11/nvim" "$HOME/.config/nvim"
ln -sfn "$X11/yazi" "$HOME/.config/yazi"

say "Shell config"
cp -n "$REPO/pc-x11/zshrc/zshrc-x11" "$HOME/.zshrc" 2>/dev/null || true
# ~/.zprofile stays as-is: it only sources ~/.zshrc and execs startx.

say "Git identity"
git config --global user.name  "vaibhav423"
git config --global user.email "20vaibhav2007@gmail.com"

say "First-run plugin fetch (nvim)"
# Populates ~/.local/share/nvim/lazy; safe to re-run.
nvim --headless '+Lazy! sync' +qa 2>/dev/null || echo "  (nvim sync skipped/failed - run manually: nvim +Lazy! sync)"

say "Done"
cat <<EOF
Next steps:
  - Open a NEW terminal (or: exec zsh) to pick up ~/.zshrc
  - Run: nvim          and: yazi
  - Your keybinds:     nvim then :Keymaps   (AstroNvim help: <Leader>?)
  - Desktop restart:  MODKEY + Shift + r
EOF
