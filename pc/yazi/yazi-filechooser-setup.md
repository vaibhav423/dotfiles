# Yazi as System-Wide File Picker (Hyprland + Foot)

Guide to set up **Yazi** as the default GUI file picker (via `xdg-desktop-portal-termfilechooser`) on Hyprland using **Foot** terminal.

---

## 1. Install Required Packages

Install Yazi, Foot, and the termfilechooser backend from AUR:

```bash
# Core packages
sudo pacman -S yazi foot xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland

# Terminal File Chooser backend (AUR)
yay -S xdg-desktop-portal-termfilechooser-hunkyburrito-git
```

---

## 2. Configure Portal Routes (`~/.config/xdg-desktop-portal/portals.conf`)

Create/edit `~/.config/xdg-desktop-portal/portals.conf`:

```ini
[preferred]
default=hyprland;gtk;
org.freedesktop.impl.portal.FileChooser=termfilechooser
```

---

## 3. Configure Termfilechooser (`~/.config/xdg-desktop-portal-termfilechooser/config`)

Create `~/.config/xdg-desktop-portal-termfilechooser/config`:

```ini
[filechooser]
cmd=/usr/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
default_dir=$HOME
env=TERMCMD=foot --app-id=file_chooser --title='file_chooser'
open_mode=suggested
save_mode=suggested
```

---

## 4. Add Hyprland Window Rule (`~/.config/hypr/custom.lua`)

To ensure the file picker opens floating and centered instead of tiling:

```lua
hl.window_rule({
    name = "file-chooser",
    match = { class = "(file_chooser)" },
    float = true,
    center = true,
    size = { "monitor_w * 0.7", "monitor_h * 0.7" },
    stay_focused = true
})
```

*(If using standard `hyprland.conf`, use this line instead:)*
```ini
windowrulev2 = float, class:^(file_chooser)$
windowrulev2 = center, class:^(file_chooser)$
windowrulev2 = size 70% 70%, class:^(file_chooser)$
```

---

## 5. Enable & Restart Portals

Ensure services are unmasked and restarted:

```bash
systemctl --user unmask xdg-desktop-portal-termfilechooser xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
systemctl --user restart xdg-desktop-portal-termfilechooser xdg-desktop-portal-gtk xdg-desktop-portal-hyprland xdg-desktop-portal
```

---

## 6. How to Use

When pressing `Ctrl+O` or clicking **Open/Save** in any application:
1. A **Foot** terminal window running **Yazi** will open.
2. Navigate to your desired file/folder.
3. Press `Enter` to select it and return the file path to the GUI application.

---

## 7. How to Revert Back to Standard GTK File Picker

To switch back to the standard GTK file chooser dialog:

1. **Update `~/.config/xdg-desktop-portal/portals.conf`:**
   Change `org.freedesktop.impl.portal.FileChooser` to `gtk` (or remove the line to fall back to `default`):
   ```ini
   [preferred]
   default=hyprland;gtk;
   org.freedesktop.impl.portal.FileChooser=gtk
   ```

2. **Restart the portal services:**
   ```bash
   systemctl --user restart xdg-desktop-portal-gtk xdg-desktop-portal-hyprland xdg-desktop-portal
   ```

3. *(Optional)* **Uninstall the termfilechooser package:**
   ```bash
   yay -R xdg-desktop-portal-termfilechooser-hunkyburrito-git
   ```
