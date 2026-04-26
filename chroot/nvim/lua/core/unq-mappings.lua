return {
  n = {
    -- tasker
    ["<Leader>rt"] = { 
      ":silent !am broadcast -a net.dinglisch.android.tasker.ACTION_TASK -e task_name youtube_img_url_mode_toggle<CR><CR>", desc = "Run Tasker task" 
    },


    -- find buffer
    ["<Leader>fb"] = {false},
    ["\\"] = {false},
    ["te"] = { function() require("snacks").picker.buffers() end, desc = "Find buffers" },

    -- Open gallery path in MixPlorer via Android intent
    ["<Leader>gg"] = {
      function()
        local gallery_line = vim.fn.search("^#\\+\\s\\+\\cgallery\\s*$", "nw")
        if gallery_line == 0 then
          vim.notify("No # gallery heading found", vim.log.levels.WARN)
          return
        end

        local next_heading = vim.fn.search("^#\\+\\s\\+", "nW", gallery_line + 1)
        local end_line = (next_heading > 0) and (next_heading - 1) or -1
        local lines = vim.api.nvim_buf_get_lines(0, gallery_line, end_line, false)

        local rel_path = nil
        for _, line in ipairs(lines) do
          local p = line:match("^%s*path:%s*(.+)%s*$")
          if p then
            rel_path = p
            break
          end
        end

        if not rel_path then
          vim.notify("No path: found under # gallery heading", vim.log.levels.WARN)
          return
        end

        -- Trim potential \r or trailing spaces
        rel_path = rel_path:gsub("[\r\n%s]+$", "")

        local full_path = vim.fn.getcwd() .. "/" .. rel_path

        local cmd = string.format(
          'am start -a android.intent.action.VIEW -d "file://%s" -t "resource/folder" -f 0x14000000 com.mixplorer',
          full_path
        )
        
        vim.notify("Opening: " .. full_path)
        vim.fn.jobstart(cmd)
      end,
      desc = "Open gallery path in MixPlorer",
    },
  },


  v = {
    -- Copy images from visually selected lines to a temp dir and open in MixPlorer
    ["<Leader>gg"] = {
      ":<C-u>'<,'>OpenImages<CR>",
      desc = "Copy selected images to tmp dir and open in MixPlorer",
    },
  },
}
