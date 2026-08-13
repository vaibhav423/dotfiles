return {

    We = {
        function(opts)
        local cmd = opts.args
        if cmd == "" then
            vim.notify(":we requires a command", vim.log.levels.WARN)
            return
        end

        local l1, l2 = opts.line1, opts.line2
        local lines = vim.api.nvim_buf_get_lines(0, l1 - 1, l2, false)
        local input = table.concat(lines, "\n")

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
}
