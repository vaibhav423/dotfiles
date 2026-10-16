# pc-x11 — Artix Linux / chadwm on X11

Third machine profile in this dotfiles repo, alongside `pc/` (Hyprland) and
`chroot/` (Arch ARM chroot on Android).

| | |
|---|---|
| Host | HP 246 Notebook PC (`dire`) |
| OS | Artix Linux, runit init |
| WM | **chadwm** (X11) |
| Terminal | **alacritty** |
| Display server | Xorg, `modesetting` driver (Intel) |
| Init | runit (not systemd) |

## What differs from `pc/` (Hyprland)

| Concern | `pc/` | `pc-x11/` |
|---|---|---|
| Terminal in yazi | `foot` / `kitty` | `alacritty` |
| yazi PDF opener | `zathura` | *removed* (not installed) |
| Drag-and-drop | `dragon-drop` | *removed* (no X11 dnd here) |
| Shell aliases | ml4w / quickshell | chadwm, runit `sv`, alacritty, yazi |
| `~/.secrets` | sourced unconditionally | sourced only if present |
| tmux | — | not auto-launched (see below) |

## Layout convention

Shared files are **symlinks**; only machine-specific files are real copies —
same rule as `chroot/`.

```
pc-x11/nvim/init.lua    -> ../../pc/nvim/init.lua
pc-x11/nvim/lua/common  -> ../../../pc/nvim/lua/common
pc-x11/yazi/init.lua    -> ../../pc/yazi/init.lua
pc-x11/zshrc/26-my-aliases -> ../../pc/zshrc/26-my-aliases
```

Real (non-symlinked) files and why:

| File | Reason |
|---|---|
| `yazi/yazi.toml`, `yazi/keymap.toml` | alacritty, no zathura/dragon-drop |
| `nvim/lua/core/unq-*`, `nvim/lua/lsp/unq-*` | per-machine keys |
| `nvim/lua/personal/*`, `nvim/lua/plugins/*` | machine-specific |
| `zshrc/25-aliases-x11` | replaces ml4w/hypr aliases |
| `zshrc/999-endscript.zsh` | optional `~/.secrets`, no tmux |
| `zshrc/zshrc-x11` | the assembler (becomes `~/.zshrc`) |

## Setup

```sh
git clone <this repo> ~/dotfiles
bash ~/dotfiles/pc-x11/scripts/setup.sh
exec zsh
```

Packages installed: `neovim yazi ripgrep fd bat lazygit`.

## tmux — do not auto-launch

An unconditional `tmux` line in `~/.zshrc` fired in **every** interactive
shell, including the ones `startx` spawns. Effect on this machine:

```
tty1 -> zsh -> tmux -> Ctrl-D -> startx -> X -> zsh child -> tmux -> Ctrl-D -> desktop
```

Three stages instead of one. If you want tmux back, guard it:

```sh
if [ -z "$DISPLAY" ] && [ -t 0 ] && [ -z "$TMUX" ]; then
    exec tmux
fi
```

## Console switching

`Ctrl+Alt+F1` … `F6`. tty1 runs autologin + X; tty2 is an independent shell.

## Docs

See `~/doc/` on the machine for chadwm keybinds, appearance, and boot notes.
