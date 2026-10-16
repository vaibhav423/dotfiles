# Dependencies — pc/ (Hyprland)
#
# Referenced by pc/zshrc/*, pc/nvim/*, pc/yazi/*.
# Installed with:  bash pc/scripts/deps.sh
#
# !! This manifest did not exist before. pc/zshrc assumed all of these were
# !! present, which is why a fresh machine (pc-x11) came up with a broken
# !! prompt and "command not found" on every interactive shell.

# --- pacman (official repos) -------------------------------------------
# shell
fzf                  # Ctrl+R history, Ctrl+T files, Alt+C cwd  (16 uses)
zoxide               # zoxide init zsh  (21-my-customization)
fastfetch            # 30-autostart, on pts only
bat                  # aliased to cat in 25-aliases

# --- oh-my-zsh ---------------------------------------------------------
# Bundled with oh-my-zsh (no action needed):
#   git sudo web-search archlinux copyfile copybuffer dirhistory
# Custom plugins, must be cloned into ~/.oh-my-zsh/custom/plugins/:
zsh-autosuggestions      # zsh-users/zsh-autosuggestions
zsh-syntax-highlighting  # zsh-users/zsh-syntax-highlighting
fast-syntax-highlighting # zdharma-continuum/fast-syntax-highlighting
ollama                   # Katrovsky/zsh-ollama-completion (NOT hdonnay/ollama)

# --- oh-my-posh --------------------------------------------------------
# Not a pacman package on this machine; installed as a static binary.
# pc/zshrc/20-customization calls:
#   eval "$(oh-my-posh init zsh --config $HOME/.config/ohmyposh/zen.toml)"
# so BOTH the binary AND the config must exist:
#   binary: ~/.local/bin/oh-my-posh
#   config: ~/.config/ohmyposh/zen.toml   (+ colors.json)
# NOTE: those config files live OUTSIDE this repo and are not tracked.

# --- nvim / yazi -------------------------------------------------------
neovim                # editor
yazi                  # file manager
ripgrep fd bat lazygit # search tools used by nvim + yazi plugins
git

# --- yazi plugins (installed by yazi on first run via package.toml) ---
#   h-hg/yamb      bookmarks
#   lpnh/fr        find
