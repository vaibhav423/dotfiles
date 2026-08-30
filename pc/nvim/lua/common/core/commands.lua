return {

    We = {
        function(opts)
        local cmd = opts.args
        if cmd == "" then
            vim.notify(":we requires a command", vim.log.levels.WARN)
            return
        end

        local l1, l2 = opts.line1, opts.line2
        local c1 = vim.fn.getpos("'<")[3]
        local c2 = vim.fn.getpos("'>")[3]

        local lines = vim.api.nvim_buf_get_lines(0, l1 - 1, l2, false)

        -- c2 == 2147483647 (v:maxcol) means the visual selection extends to end-of-line (linewise)
        local partial = c2 < 2147483647
        local input
        if partial then
            if l1 == l2 then
                input = lines[1]:sub(c1, c2) .. "\n"
            else
                lines[1] = lines[1]:sub(c1)
                lines[#lines] = lines[#lines]:sub(1, c2)
                input = table.concat(lines, "\n") .. "\n"
            end
        else
            input = table.concat(lines, "\n") .. "\n"
        end

        local output = vim.fn.system(cmd, input)
        if vim.v.shell_error ~= 0 then
            vim.notify(":we failed: " .. output, vim.log.levels.ERROR)
            return
        end

        local out_lines = vim.split(output, "\n")
        if out_lines[#out_lines] == "" then
            table.remove(out_lines)
        end
        vim.api.nvim_buf_set_lines(0, l2, l2, false, out_lines)
        end,

        range = "%",
        nargs = "*",
        complete = "shellcmd",
        desc = "pass buffer or selected region as stdin to command"
    },

    VaultInit = {
      function() require("common.personal.vault_jee").init_template() end,
      desc = "Initialise vault topic template and pin directory",
    },

    VaultPin = {
      function() require("common.personal.vault_jee").set_pinned() end,
      desc = "Pick and save a vault directory as pinned",
    },

    VaultOpen = {
      function() require("common.personal.vault_jee").open_pinned() end,
      desc = "Open pinned topic files in splits",
    },

    YtFrame = {
      function() require("common.personal.ytframe").capture() end,
      desc = "Capture a frame from a YouTube URL and insert as markdown image",
    },


    EncryptBuffer = {
      function() require("common.personal.encryption").encrypt_buffer() end,
      desc = "Encrypt current buffer to .enc file",
    },

    DecryptBuffer = {
      function() require("common.personal.encryption").decrypt_buffer() end,
      desc = "Decrypt current .enc file into buffer",
    },

    ClearEncryptionPassword = {
      function() require("common.personal.encryption").clear_password() end,
      desc = "Clear cached encryption password",
    },

    Jeerem = {
      function() require("common.personal.jeerem").insert() end,
      desc = "Insert/overwrite reminder on first line",
    },

    MoveImages = {
      function()
        local filepath = vim.fn.expand('%:p')
        if filepath ~= "" then
            local script_path = vim.fn.stdpath("config") .. "/lua/common/personal/move_to_gallery.py"
            print(script_path)
            local cmd = string.format('python3 "%s" "%s"', script_path, filepath)
            local output = vim.fn.system(cmd)
            print(output)
            vim.cmd('e!')
        else
            print("No file in current buffer")
        end
      end,
      desc = "Move markdown images to gallery path",
    },

    ReorderImages = {
      function()
        local filepath = vim.fn.expand('%:p')
        if filepath ~= "" then
            local script_path = vim.fn.stdpath("config") .. "/lua/common/personal/reorder_photos.py"
            local cmd = string.format('python3 "%s" "%s"', script_path, filepath)
            local output = vim.fn.system(cmd)
            print(output)
            vim.cmd('e!')
        else
            print("No file in current buffer")
        end
      end,
      desc = "Reorder markdown images using python script",
    },

    Mdl = {
      function()
        local line = vim.api.nvim_get_current_line()
        local col = vim.api.nvim_win_get_cursor(0)[2] + 1
        local url_pattern = "https?://[^%s\"'>`]+"
        
        local start_idx = 1
        local match_start, match_end, url
        while true do
          local s, e = line:find(url_pattern, start_idx)
          if not s then break end
          if col >= s and col <= e + 1 then
            match_start = s
            match_end = e
            url = line:sub(s, e)
            break
          end
          start_idx = e + 1
        end

        if not url then
          vim.notify("No URL found at cursor", vim.log.levels.WARN)
          return
        end

        local before = line:sub(1, match_start - 1)
        local after = line:sub(match_end + 1)
        local new_line = before .. "[](" .. url .. ")" .. after
        vim.api.nvim_set_current_line(new_line)
        vim.api.nvim_win_set_cursor(0, {vim.api.nvim_win_get_cursor(0)[1], #before + 1})
        vim.cmd("startinsert")
      end,
      desc = "Create markdown link around URL at cursor",
    },
}
