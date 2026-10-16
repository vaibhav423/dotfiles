#!/usr/bin/env bash
# Install everything pc/zshrc, pc/nvim and pc/yazi assume exists.
# Usage:  bash pc/scripts/deps.sh
set -euo pipefail

ZD="${ZD:-$HOME/.oh-my-zsh/custom/plugins}"

say() { printf '\n== %s ==\n' "$1"; }

say "pacman packages"
sudo pacman -S --needed --noconfirm \
  fzf zoxide fastfetch bat neovim yazi ripgrep fd lazygit git

say "oh-my-zsh custom plugins"
mkdir -p "$ZD"
clone() {  # name url
  if [ -d "$ZD/$1" ]; then
    echo "  $1 already present"
  else
    git clone --depth 1 "$2" "$ZD/$1" >/dev/null 2>&1 \
      && echo "  cloned $1" \
      || echo "  FAILED $1 ($2)"
  fi
}
clone zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions
clone zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
clone fast-syntax-highlighting https://github.com/zdharma-continuum/fast-syntax-highlighting
# NOTE: the ollama plugin is NOT hdonnay/ollama (that URL prompts for auth).
clone ollama                  https://github.com/Katrovsky/zsh-ollama-completion

say "oh-my-posh"
if ! command -v oh-my-posh >/dev/null 2>&1; then
  # Static binary into ~/.local/bin (matches this machine's existing layout).
  # Asset is named posh-linux-amd64 (NOT oh-my-posh-linux-amd64 - that 404s).
  # Resolve "latest" via the API so this keeps working across renames.
  mkdir -p "$HOME/.local/bin"
  url=$(curl -fsSL https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/releases/latest \
        | grep -oE '"browser_download_url": "[^"]*posh-linux-amd64"' \
        | head -1 | cut -d'"' -f4)
  if [ -n "$url" ]; then
    curl -fsSL "$url" -o "$HOME/.local/bin/oh-my-posh"
    chmod +x "$HOME/.local/bin/oh-my-posh"
    echo "  installed $HOME/.local/bin/oh-my-posh"
  else
    echo "  FAILED: could not resolve a download URL"
  fi
else
  echo "  already installed"
fi

say "oh-my-posh config"
# 20-customization references ~/.config/ohmyposh/zen.toml - without it the
# prompt silently falls back.
mkdir -p "$HOME/.config/ohmyposh"
if [ ! -f "$HOME/.config/ohmyposh/zen.toml" ]; then
  cat > "$HOME/.config/ohmyposh/zen.toml" <<'TOML'
[metadata]
name = "zen"

[character]
success_symbol = "[ok] "
error_symbol = "[err] "
truncation_length = 125

[blocks]
format = "$PROMPT$character$path_segments$character$jobs$character$git_branch$character$git_status$character$command_count$character$duration$character$right_arrow"
path_segments = { style = "bold cyan", separator = "arrow" }
command_count = { style = "bold yellow", format = "[$count] " }
duration = { style = "yellow", format = "[%s] " }
right_arrow = { style = "bold green", format = "❯ " }

[git_branch]
format = "on $branch"
style = "bold purple"

[git_status]
format = "$lock$untracked$stashed$unstaged$staged"
style = "bold red"

[time]
disabled = true
TOML
  echo "  wrote ~/.config/ohmyposh/zen.toml"
else
  echo "  already present"
fi

say "Done"
cat <<'EOF'
Verify:
  exec zsh                       # new shell picks up the prompt
  oh-my-posh --version
  ls ~/.config/ohmyposh/
  ls ~/.oh-my-zsh/custom/plugins/
EOF
