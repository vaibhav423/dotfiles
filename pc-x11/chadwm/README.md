# chadwm — pc-x11 (X11 / Artix)

Window manager config for the HP 246 (Artix Linux, Xorg, chadwm/dwm).

This is the machine's own copy. Upstream is <https://github.com/siduck/chadwm>,
but **there is no nested `.git` here** — this tree is tracked by the dotfiles
repo itself, so it stays in sync with the rest of `pc-x11/`.

## Layout

```
chadwm/
  .Xresources          X resources (xrdb merge)
  chadwm/              WM source + config
    config.h           YOUR keybinds and settings  <-- tracked on purpose
    config.def.h       upstream template (do not edit)
    dwm.c drw.c ...    upstream source
    themes/            WM colour themes
    scripts/run.sh     session launcher (called by ~/.xinitrc)
  scripts/
    bar.sh             xsetroot status bar
    bar_themes/        bar colour themes (onedark is active)
```

`rofi -show drun` (bound to `MODKEY + c`) uses rofi's built-in theme. The
upstream `rofi/` directory of unused `.rasi` files was removed — nothing
loaded it, and `~/.config/rofi` does not exist on this machine.

## Why config.h is tracked

Upstream's `.gitignore` excludes `config.h`. Here it is deliberately tracked,
because it holds this machine's real keybinds — notably:

```c
{ MODKEY, XK_Return, spawn, SHCMD("/usr/bin/alacritty") },
{ ClkStatusText, Button2, spawn, SHCMD("/usr/bin/alacritty") },
```

The terminal is **alacritty** (upstream defaults to `st`, which is not
installed here). Letting a checkout wipe this would silently break both
keybinds.

## Build / install

```sh
cd ~/.config/chadwm/chadwm
make            # never use `make clean` — it deletes config.h
sudo make install
```

`make clean` removes `config.h` and regenerates it from `config.def.h`, which
discards all keybinds. To rebuild safely use:

```sh
rm -f *.o && make && sudo make install
```

Then reload without closing windows: `MODKEY + Shift + r`.

## Session wiring

- `~/.xinitrc` → `~/.config/chadwm/chadwm/scripts/run.sh`
- `run.sh` sets xrdb, brightness, keyrepeat, starts picom and the bar, then
  runs `chadwm` in a restart loop.

## Docs

Detailed keybind/appearance notes live in `~/doc/` on the machine
(see `~/doc/Home.md`).