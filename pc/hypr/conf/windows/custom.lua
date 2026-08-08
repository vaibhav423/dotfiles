hl.config({
    general = {
        -- originals:
        -- gaps_in  = 5,
        -- gaps_out = 10,
        -- border_size = 2,
        gaps_in  = 0,
        gaps_out = 0,
        border_size = 1,
        col = {
            active_border   = { colors = {primary, on_primary}, angle = 90 },
            inactive_border = on_primary,
        },
        resize_on_border = true,
        layout = "dwindle",
    }
})
