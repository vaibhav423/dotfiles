-- ## AUTOSTART ##
-- ai
hl.on("hyprland.start", function ()
    hl.exec_cmd("/usr/bin/firefox --name=ai-browser -P hminimal2 --new-instance gemini.google.com --new-window gemini.google.com --new-window gemini.google.com")
end)

-- ## WINDOW-RULES ##

-- AI Browser
hl.window_rule({
    name = "ai-browser",
    match = { class = "(ai-browser)" },
    workspace = "5 silent"
})

-- Cheat
hl.window_rule({
    name = "cheat",
    match = { class = "(cheat)" },
    float = true,
    move = "(monitor_w-window_w-100) 66",
    pin = true,
    size = "300 400",
    no_initial_focus = true,
    rounding = 0,
    border_size = 0,
    no_shadow = true,
    no_blur = true
})
-- from source ~/Water/crap/scripts/windowrule_cheat.conf
hl.window_rule({
    name = "cheat-source",
    match = { class = "(cheat)" },
    float = true,
    move = "(monitor_w-window_w+50) 66",
    pin = true,
    size = "300 400",
    no_initial_focus = true,
    rounding = 0,
    border_size = 0,
    no_shadow = true,
    no_blur = true,
    opacity = "0.0 override 0.0 override"
})

-- Notifi
hl.window_rule({
    name = "noti",
    match = { class = "(noti)" },
    float = true,
    move = "(monitor_w-window_w-16+600) 66",
    pin = true,
    size = "300 400",
    no_initial_focus = true
})

hl.window_rule({
    name = "file-picker",
    match = { class = "^(xdg-desktop-portal-gtk)$" },
    float = true,
    pin = true,
    stay_focused = true
})

hl.env("LIBVIRT_DEFAULT_URI", "qemu:///system")

-- #oldformat (commented out)
-- AI browser
-- hl.window_rule({ name = "ai-browser", match = { class = "^(ai-browser)$" }, workspace = "5 silent" })
--
-- Cheat
-- hl.window_rule({ name = "cheat", match = { class = "^(cheat)$" }, no_border = true })
-- hl.window_rule({ name = "cheat", match = { class = "^(cheat)$" }, no_shadow = true })
-- hl.window_rule({ name = "cheat", match = { class = "^(cheat)$" }, no_rounding = true })
-- hl.window_rule({ name = "cheat", match = { class = "^(cheat)$" }, no_blur = true })
-- hl.window_rule({ name = "cheat", match = { class = "^(cheat)$" }, opacity = "1.0 override 1.0 override" })
-- hl.window_rule({ name = "cheat", match = { class = "(cheat)" }, float = true })
-- hl.window_rule({ name = "cheat", match = { class = "(cheat)" }, move = "100%-w-100 66" })
-- hl.window_rule({ name = "cheat", match = { class = "(cheat)" }, pin = true })
-- hl.window_rule({ name = "cheat", match = { class = "(cheat)" }, size = "300 400" })
-- hl.window_rule({ name = "cheat", match = { class = "(cheat)" }, no_initial_focus = true })
-- hl.window_rule({ name = "cheat", match = { class = "(cheat)" }, no_focus = true })
-- source ~/Water/crap/scripts/windowrule_cheat.conf
--
--
--
-- Notifi
-- hl.window_rule({ name = "noti", match = { class = "(noti)" }, float = true })
-- hl.window_rule({ name = "noti", match = { class = "(noti)" }, move = "100%-w-16 66" })
-- hl.window_rule({ name = "noti", match = { class = "(noti)" }, pin = true })
-- hl.window_rule({ name = "noti", match = { class = "(noti)" }, size = "300 400" })
-- hl.window_rule({ name = "noti", match = { class = "(noti)" }, no_initial_focus = true })

-- misc {
--    vrr = 1
-- }
-- applying any 'one' is equivalent to fakefullscreen for firefox i.e. it keeps the search bar intact even in full screen
-- about:config browser.fullscreen.autohide false
-- hl.window_rule({ match = { class = "^(firefox)$" }, sync_fullscreen = 0 })
