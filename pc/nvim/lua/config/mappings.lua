-- config/mappings.lua: all global keymaps for astrocore.
-- Add new mappings here. astrocore.lua merges this into opts.mappings.

-- ---------------------------------------------------------------------------
-- Helpers (save-on-escape)
-- ---------------------------------------------------------------------------

-- Filetypes / buftypes that should never trigger save-on-escape
local ESCAPE_EXCLUDED_FT = {
  "TelescopePrompt", "TelescopeResults", "lazy", "NvimTree",
  "neo-tree", "fzf", "alpha", "packer", "Trouble",
}

local function escape_excluded()
  if vim.bo.buftype ~= "" then return true end
  for _, ft in ipairs(ESCAPE_EXCLUDED_FT) do
    if vim.bo.filetype == ft then return true end
  end
  return false
end

local function save_if_modified()
  if not escape_excluded() and not vim.bo.readonly and vim.bo.modifiable and vim.bo.modified then
    vim.schedule(function() vim.cmd("silent! update") end)
  end
end

-- ---------------------------------------------------------------------------
-- Mappings table (returned for use in astrocore opts.mappings)
-- ---------------------------------------------------------------------------

return {

  -- Insert mode ---------------------------------------------------------------
  i = {
    -- Exit insert mode and save if modified
    ["<Esc>"] = {
      function()
        local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
        if escape_excluded() or vim.bo.readonly or not vim.bo.modifiable then
          vim.api.nvim_feedkeys(esc, "n", true)
          return
        end
        vim.api.nvim_feedkeys(esc, "n", true)
        save_if_modified()
      end,
      desc = "Exit insert and save",
    },
  },

  -- Terminal mode -------------------------------------------------------------
  t = {
    -- Exit terminal mode and save if modified
    ["<Esc>"] = {
      function()
        local seq = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
        vim.api.nvim_feedkeys(seq, "n", true)
        save_if_modified()
      end,
      desc = "Exit terminal mode and save",
    },
  },

  -- Normal mode ---------------------------------------------------------------
  n = {
    -- Wikilink navigation
    ["<M-s>"]     = { function() require("lib.wikilink").collect() end,  desc = "Save all [[wikilinks]] in buffer" },
    ["<M-Right>"] = { function() require("lib.wikilink").next() end,     desc = "Next saved wikilink" },
    ["<M-Left>"]  = { function() require("lib.wikilink").prev() end,     desc = "Previous saved wikilink" },
    ["<M-f>"]     = { function() require("lib.wikilink").pick() end,     desc = "Fuzzy find saved wikilinks" },

    -- Buffers
    ["<Tab>"]      = { function() require("astrocore.buffer").nav(vim.v.count1) end,  desc = "Next buffer" },
    -- t is nvim inbuilt key for till  , this new map blocks tt which should make cursour movie behind next t 
    ["<S-TAB>"]    = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },
    ["<Leader>bd"] = {
      function()
        require("astroui.status.heirline").buffer_picker(
          function(bufnr) require("astrocore.buffer").close(bufnr) end
        )
      end,
      desc = "Close buffer from tabline",
    },
    -- exchange mappings between grep_wprd and commands
    ["<Leader>fC"] =  { function() require("snacks").picker.grep_word() end, desc = "Find word under cursor" },

    ["<Leader>fc"] = { function() require("snacks").picker.commands() end, desc = "Find commands" },


    -- LSP
    ["<Leader>rl"] = { "<cmd>LspRestart<CR>", desc = "Restart LSP" },

    -- Code runner
    -- ["<Leader>rt"]  = { ":w<CR>:RunCode<CR>",              desc = "Run code (float)" },
    ["<Leader>rb"]  = { ":w<CR>:RunFile better_term<CR>",  desc = "Run file in terminal" },
    ["<Leader>rf"]  = { ":RunFile<CR>",                    desc = "Run file" },
    ["<Leader>rft"] = { ":RunFile tab<CR>",                desc = "Run file (tab)" },
    ["<Leader>rp"]  = { ":RunProject<CR>",                 desc = "Run project" },

    -- tasker
    ["<Leader>rt"] = { 
      ":silent !am broadcast -a net.dinglisch.android.tasker.ACTION_TASK -e task_name youtube_img_url_mode_toggle<CR><CR>", desc = "Run Tasker task" 
    },
    -- Copilot
    ["<Leader>tc"] = {
      function()
        local ok, suggestion = pcall(require, "copilot.suggestion")
        if not ok then
          vim.notify("Copilot plugin not loaded", vim.log.levels.WARN)
          return
        end
        suggestion.toggle_auto_trigger()
      end,
      desc = "Toggle Copilot auto-trigger",
    },

    -- Jeerem reminder
    ["<Leader>jr"] = { "<cmd>Jeerem<CR>", desc = "Insert reminder on first line" },

    -- Vault
    ["<Leader>vi"] = { function() require("lib.vault").init_template() end, desc = "Vault: init topic template" },
    ["<Leader>vp"] = { function() require("lib.vault").set_pinned() end,    desc = "Vault: pick pinned directory" },
    ["<Leader>vo"] = { function() require("lib.vault").open_pinned() end,   desc = "Vault: open pinned topic files" },

    -- YouTube frame capture (normal: auto-detect URL on current line)
    ["<Leader>yf"] = { function() require("lib.ytframe").capture_normal() end, desc = "Capture YouTube frame (current line URL)" },

    -- File finder (documents)
    ["<Leader>fd"] = {
      function()
        require("snacks").picker.files({ dirs = { "/sdcard/Documents" } })
      end,
      desc = "Find documents files",
    },

    -- File finder (nvim-docs)
    ["<Leader>fn"] = {
      function()
        require("snacks").picker.files({ dirs = { "~/.local/share/nvim/" } })
      end,
      desc = "Find nvim docs",
    },
    -- change default notifications mapping from fn to fN
    ["<Leader>fN"] = { function() require("snacks").picker.notifications() end, desc = "Find notifications" },

    -- Copy file path
    ["<Leader>fp"] = {
      function()
        local filepath = vim.fn.expand("%:p")
        vim.fn.setreg("+", filepath)
        vim.notify("Copied: " .. filepath)
      end,
      desc = "Copy current file path",
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

    -- Delete image file under cursor and the current line
    ["<Leader>dd"] = {
      function()
        local cwd = vim.fn.getcwd()
        local urls = require("vim.ui")._get_urls()
        local rel_or_abs = urls and urls[1]
        if not rel_or_abs or rel_or_abs == "" then
          vim.notify("DeletePhoto: no path found under cursor", vim.log.levels.WARN)
          return
        end

        local abs_path
        if rel_or_abs:sub(1, 1) == "/" then
          abs_path = rel_or_abs
        else
          abs_path = cwd .. "/" .. rel_or_abs
        end

        if vim.fn.filereadable(abs_path) == 0 then
          vim.notify("DeletePhoto: file not found:\n" .. abs_path, vim.log.levels.WARN)
        else
          vim.fn.delete(abs_path)
        end

        -- Delete the current line
        local row = vim.api.nvim_win_get_cursor(0)[1]
        vim.api.nvim_buf_set_lines(0, row - 1, row, false, {})

        vim.schedule(function()
          vim.notify("Deleted: " .. rel_or_abs, vim.log.levels.INFO)
        end)
      end,
      desc = "Delete image file under cursor and current line",
    },

    -- toggle key maps  
    ["z1"] = { function() require("lib.fold_toggle").toggle(1) end, desc = "Toggle fold level 1" },
    ["z2"] = { function() require("lib.fold_toggle").toggle(2) end, desc = "Toggle fold level 2" },
    ["z3"] = { function() require("lib.fold_toggle").toggle(3) end, desc = "Toggle fold level 3" },
    ["z4"] = { function() require("lib.fold_toggle").toggle(4) end, desc = "Toggle fold level 4" },

    -- Fold level toggles (all windows in tabpage)
    ["<Leader>z1"] = { function() require("lib.fold_toggle").toggle_all(1) end, desc = "Toggle fold level 1 (all windows)" },
    ["<Leader>z2"] = { function() require("lib.fold_toggle").toggle_all(2) end, desc = "Toggle fold level 2 (all windows)" },
    ["<Leader>z3"] = { function() require("lib.fold_toggle").toggle_all(3) end, desc = "Toggle fold level 3 (all windows)" },
    ["<Leader>z4"] = { function() require("lib.fold_toggle").toggle_all(4) end, desc = "Toggle fold level 4 (all windows)" },
  },
    -- Visual mode ---------------------------------------------------------------
  v = {
    -- Substitute only within the visual selection
    ["<C-r>"] = { [[:s/\%V\%V//g<Left><Left><Left><Left><Left><Left>]], desc = "Substitute inside selection" },

    -- Copy images from visually selected lines to a temp dir and open in MixPlorer
    ["<Leader>gg"] = {
      ":<C-u>'<,'>OpenImages<CR>",
      desc = "Copy selected images to tmp dir and open in MixPlorer",
    },

    -- YouTube frame capture: visually select lines containing URLs, press <Leader>yf
    ["<Leader>yf"] = {
      ":<C-u>lua require('lib.ytframe').capture_visual()<CR>",
      desc = "Capture YouTube frames from all URLs in selection",
    },
  },

}
