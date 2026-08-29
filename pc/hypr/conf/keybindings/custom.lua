-- Configuration
local mainMod = "SUPER" -- Sets "Windows" key as main modifier

local term = "foot" -- Terminal emulator
local tmux = term .. " tmux new-session" -- Open tmux session


-- Applications
-- hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("~/.config/ml4w/settings/terminal.sh"), { description = "Open the terminal" })
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(term .. " tmux"), { description = "Open the terminal" })
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("~/.config/ml4w/settings/browser.sh"), { description = "Open the browser" })
-- hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("~/.config/ml4w/settings/filemanager"), { description = "Open the filemanager" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(term .. " yazi"), { description = "Open the filemanager" })
hl.bind(mainMod .. " + CTRL + E", hl.dsp.exec_cmd("~/.config/ml4w/settings/emojipicker.sh"), { description = "Open the emoji picker" })

-- conflicts with whatsapp
-- hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("~/.config/ml4w/settings/calculator.sh"), { description = "Open the calculator" })

-- fr keyboard layout setup
local is_fr = false
local f = io.open(os.getenv("HOME") .. "/.config/hypr/input.lua", "r")
if f then
    local content = f:read("*all")
    if content:match('kb_layout%s*=%s*"fr"') and not content:match('kb_variant%s*=%s*"us"') then
        is_fr = true
    end
    f:close()
end

local fr_keys = {
    "ampersand", "eacute", "quotedbl", "apostrophe", "parenleft",
    "minus", "egrave", "underscore", "ccedilla", "agrave"
}

-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    if is_fr then
        key = fr_keys[i]
    end
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }), { description = "Focus workspace " .. i })
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), { description = "Move window to workspace " .. i })
end

-- Windows
-- hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("~/.config/hypr/scripts/killactive.sh"), { description = "Kill active window" })
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("~/.config/hypr/scripts/killactive.sh"), { description = "Kill active window" })
-- hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Kill active window" })
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("hyprctl activewindow | grep pid | tr -d 'pid:' | xargs kill"), { description = "Quit active window and all open instances" })
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Toggle Fullscreen" })
hl.bind(mainMod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Toggle Maximize Window" })
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle Floating" })
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-toggle-allfloat"), { description = "Toggle floating for all windows of workspace" })
hl.bind(mainMod .. " + ALT + T", function() hl.dispatch(hl.dsp.window.float({ action = "toggle" })); hl.dispatch(hl.dsp.window.pin()) end, { description = "Toggle floating + pinned" })
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), { description = "Toggle split" })
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }), { description = "Move focus left" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Move focus right" })
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }), { description = "Move focus up" })
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }), { description = "Move focus down" })
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window with the mouse" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window with the mouse" })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), { repeating = true }, { description = "Increase window width with keyboard" })
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true }, { description = "Reduce window width with keyboard" })
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), { repeating = true }, { description = "Increase window height with keyboard" })
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { repeating = true }, { description = "Reduce window height with keyboard" })
hl.bind(mainMod .. " + G", hl.dsp.group.toggle(), { description = "Toggle window group" })
-- hl.bind(mainMod .. " + SHIFT + G", hl.dsp.group.active("f"), { description = "Switch to next group window" })
-- hl.bind(mainMod .. " + K", hl.dsp.layout("swapsplit"), { description = "Swapsplit" })
hl.bind(mainMod .. " + ALT + left", hl.dsp.window.swap({ direction = "l" }), { description = "Swap tiled window left" })
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.swap({ direction = "r" }), { description = "Swap tiled window right" })
hl.bind(mainMod .. " + ALT + up", hl.dsp.window.swap({ direction = "u" }), { description = "Swap tiled window up" })
hl.bind(mainMod .. " + ALT + down", hl.dsp.window.swap({ direction = "d" }), { description = "Swap tiled window down" })

-- Actions
hl.bind(mainMod .. " + CTRL + R", hl.dsp.exec_cmd("hyprctl reload"), { description = "Reload Hyprland configuration" })
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle-animations.sh"), { description = "Toggle animations" })
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh"), { description = "Take a screenshot" })
-- hl.bind(mainMod .. " + ALT + F", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh --instant"), { description = "Take an instant full-screen screenshot" })
-- hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh --instant-area"), { description = "Take an instant area screenshot" })
hl.bind(mainMod .. " + ALT + A", hl.dsp.exec_cmd("~/.config/hypr/scripts/text-extractor.sh"), { description = "Extract text from an area" })
hl.bind(mainMod .. " + CTRL + P", hl.dsp.exec_cmd("qs ipc call power toggle"), { description = "Start Power Menu" })
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-wallpaper-app --random"), { description = "Change the wallpaper" })
hl.bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-wallpaper-app"), { description = "Open wallpaper selector" })
hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-wallpaper-automation"), { description = "Start random wallpaper script" })
-- hl.bind(mainMod .. " + CTRL + RETURN", hl.dsp.exec_cmd("~/.config/hypr/scripts/launcher.sh"), { description = "Open application launcher" })
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("~/.config/hypr/scripts/launcher.sh"), { description = "Open application launcher" })
hl.bind(mainMod .. " + CTRL + K", hl.dsp.exec_cmd("~/.config/hypr/scripts/keybindings.sh"), { description = "Show keybindings" })
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-reload-statusbar"), { description = "Reload Status Bar" })
hl.bind(mainMod .. " + CTRL + B", hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-toggle-statusbar"), { description = "Toggle Status Bar" })
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/loadconfig.sh"), { description = "Reload hyprland config" })
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-cliphist"), { description = "Open clipboard manager" })
hl.bind(mainMod .. " + CTRL + T", hl.dsp.exec_cmd("~/.config/waybar/themeswitcher.sh"), { description = "Open waybar theme switcher" })
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-toggle-theme"), { description = "Toggle between light and dark mode" })
hl.bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd("qs ipc call sidebar toggle"), { description = "Open ML4W Sidebar widget" })
hl.bind(mainMod .. " + CTRL + C", hl.dsp.exec_cmd("qs ipc call calendar toggle"), { description = "Open ML4W Calendar widget" })
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("qs ipc call statusbar focus"), { description = "Expand statusbar and focus it for keyboard navigation" })
hl.bind(mainMod .. " + ALT + G", hl.dsp.exec_cmd("~/.config/hypr/scripts/gamemode.sh"), { description = "Toggle game mode" })
hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-power -l"), { description = "Lock Screen" })
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-toggle-hyprsunset"), { description = "Toggle Hyprsunset" })
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("qs -p ~/.config/quickshell/overview ipc call overview toggle"), { description = "Open Select Window Menu" })
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd("~/.config/ml4w/themes/themes.sh"), { description = "Open Select Window Menu" })

-- Special workspace (scratchpad)
-- conflicts with git sync and stop_sendk
-- hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("scratchpad"), { description = "Toggle special workspace scratchpad" })
-- hl.bind(mainMod .. " + SHIFT + S", function()
--     hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
--     hl.dispatch(hl.dsp.window.move({ workspace = "special:scratchpad" }))
-- end)
-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Switch to next workspace" })
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Switch to previous workspace" })


-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window with the mouse" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window with the mouse" })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Raise volume" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true, description = "Lower volume" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true, description = "Mute audio" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true, description = "Mute microphone" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true, description = "Increase brightness" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true, description = "Decrease brightness" })

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Next track" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Pause audio" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play audio" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Previous track" })

-- # my adds

hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd(term), { description = "Open the terminal" })
hl.bind(mainMod .. " + ALT + R", hl.dsp.exec_cmd("~/Water/crap/scripts/rofi/rofi-menu-from-json.sh ~/Water/crap/scripts/rofi/general.json"), { description = "General rofi" })
hl.bind(mainMod .. " + CTRL + O", hl.dsp.exec_cmd("~/Water/crap/scripts/rofi/rofi-menu-from-json.sh ~/Water/crap/scripts/rofi/opencode.json"), { description = "opencode rofi" })
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(term .. " nchat"), { description = "Whatsapp" })
-- -A option allows u to join existing without it would throw duplicate session error
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(tmux .. " -A -s opencode opencode"), { description = "Opencode" })
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(tmux .. " -c ~/Water/Fire/ nvim -c \"lua vim.defer_fn(function() vim.api.nvim_input('<Space>ff') end, 50)\""), { description = "Open nvim fzf" })
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd(tmux .. " -c ~/Water/Fire/ nvim"), { description = "Open nvim" })
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd(tmux .. " -A -s nvim  -c ~/Water/Fire nvim ~/Water/Fire/notes/scratch.md"), { description = "Notes" })
hl.bind(mainMod .. " + ALT + B", hl.dsp.exec_cmd(tmux .. " nvim '/home/ixdire/.config/hypr/conf/keybindings/custom.lua'"), { description = "Open keybinding file" })
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd(term .. " --app-id dotfiles-floating nvim ~/Water/crap/scripts/git.log"), { description = "Git log" })
hl.bind(mainMod .. " + F2", hl.dsp.exec_cmd("firefox --name=ai-browser -P hminimal2 --new-instance gemini.google.com"), { description = "Notes" })
-- phone: bind = mainMod ALT, P, exec, ~/.config/ml4w/scripts/phone.sh >> ~/log
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("cd ~/Water/Fire && ~/Water/crap/scripts/notify.sh \"~/Water/crap/scripts/git.sh 2>&1 | tee ~/Water/crap/scripts/git.log\""), { description = "Git vault sync" })
hl.bind(mainMod .. " + ALT + F4", hl.dsp.exec_cmd("systemctl poweroff"), { description = "Shutdown" })
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("/home/ixdire/Water/crap/dotfiles/pc/scripts/hidewin.sh"), { description = "Hidewin" })
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd("/home/ixdire/Water/crap/dotfiles/pc/scripts/unhidewin.sh"), { description = "Unhidewin" })
hl.bind(mainMod .. " + SHIFT + ALT + S", hl.dsp.window.move({ workspace = "special" }), { description = "Move window to special workspace" })
hl.bind(mainMod .. " + ALT + C", hl.dsp.workspace.toggle_special(), { description = "Toggle special workspace" })
-- hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("nmcli connection up fire"), { description = "Wifi connect" })
-- hl.bind(mainMod .. " + `", hl.dsp.exec_cmd("nmcli connection up fire"), { description = "Wifi connect" })
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("foot --app-id gemini tmux new-session -A -s gemini-chat ~/.pyenv/bin/gemini-chat"), { description = "Wifi connect" })
hl.bind(mainMod .. " + CTRL + A", hl.dsp.exec_cmd("/home/ixdire/Water/crap/scripts/bttogg.sh"), { description = "Bluetooth toggle" })
hl.bind(mainMod .. " + ALT + F2", hl.dsp.exec_cmd("/home/ixdire/.config/ml4w/settings/aigpt.sh"), { description = "Chatgpt" })
hl.bind(mainMod .. " + ALT + M", hl.dsp.exec_cmd("$SSH sudo input keyevent 85"), { description = "Music toggle" })
-- opacity-off: bind = mainMod ALT, O, exec, ~/Water/crap/scripts/opacity.sh 0.0
-- opacity-on: bind = mainMod SHIFT, O, exec, ~/Water/crap/scripts/opacity.sh 0.2
hl.bind(mainMod .. " + ALT + O", hl.dsp.exec_cmd("sh -c 'c=$(cat /tmp/opacity_val 2>/dev/null || echo 0.0); if [ \"$c\" = \"0.0\" ]; then ~/Water/crap/scripts/opacity.sh 0.2; echo 0.2 > /tmp/opacity_val; else ~/Water/crap/scripts/opacity.sh 0.0; echo 0.0 > /tmp/opacity_val; fi'"), { description = "Opacity toggle" })
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("firefox -P cheat --name cheat https://gemini.google.com/gem/b29be801abe6"), { description = "Cheat" })
-- sendkeys-old: bind = mainMod ALT, S, exec, wl-paste > /home/ixdire/foo.txt && sudo ~/Water/crap/scripts/sendk Arch
hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd("wl-paste > ~/foo.txt && python /home/ixdire/Water/crap/scripts/sendk.py win11-x"), { description = "Sendkeys" })
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("/home/ixdire/Water/crap/scripts/stop_sendk.sh"), { description = "Stopkeys" })
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("/home/ixdire/Water/crap/scripts/pause_sendk.sh"), { description = "Pausekeys" })
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("/home/ixdire/Water/crap/scripts/resume_sendk.sh"), { description = "Pausekeys" })
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("grim ~/grim/$(date +'%Y-%m-%d-%H%M%S.png')"), { description = "Screenshot to grim" })
hl.bind(mainMod .. " + ALT + P", hl.dsp.exec_cmd("grim - | wl-copy"), { description = "Full screenshot to clipboard" })
-- region photo to clipboard: bind = mainMod SHIFT, P, exec, grim -g "$(slurp)" - | wl-copy
-- Alt+Tab to cycle through windows on the current workspace
hl.bind("ALT + Tab", hl.dsp.window.cycle_next({ next = true }), { repeating = true, description = "Next window" })
hl.bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }), { repeating = true, description = "Previous window" })
