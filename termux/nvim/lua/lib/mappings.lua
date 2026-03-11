-- lib/mappings.lua: all global keymaps for astrocore.
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
    ["tt"]    = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },
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
    ["<Leader>rt"]  = { ":w<CR>:RunCode<CR>",              desc = "Run code (float)" },
    ["<Leader>rb"]  = { ":w<CR>:RunFile better_term<CR>",  desc = "Run file in terminal" },
    ["<Leader>rf"]  = { ":RunFile<CR>",                    desc = "Run file" },
    ["<Leader>rft"] = { ":RunFile tab<CR>",                desc = "Run file (tab)" },
    ["<Leader>rp"]  = { ":RunProject<CR>",                 desc = "Run project" },

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

    -- remap Lspsaga
    ["<Leader>lr"] = { "<Cmd>Lspsaga finder<CR>", desc = "LSP Finder" },
    ["<Leader>lR"] = { "<Cmd>Lspsaga rename<CR>", desc = "Rename symbol" },
--     ["<Leader>lr"] = { "<Cmd>Lspsaga finder<CR>", desc = "Search references",
--                         cond = function(client)
--                           return client.supports_method "textDocument/references"
--                             or client.supports_method "textDocument/implementation"
--                         end,
--                         },
--     ["<Leader>lR"] = { 
--   "<Cmd>Lspsaga rename<CR>", 
--   desc = "Rename symbol", 
--   cond = function(client) return client.supports_method "textDocument/rename" end 
-- },


    -- File finder (documents)
    ["<Leader>fd"] = {
      function()
        require("snacks").picker.files({ dirs = { "/storage/emulated/0/Documents" } })
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



    -- find buffer
    ["<Leader>fb"] = {false},
    ["te"] = { function() require("snacks").picker.buffers() end, desc = "Find buffers" },

    -- Open gallery path in MixPlorer via Android intent
    ["<Leader>gg"] = {
      function()
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

        local in_gallery = false
        local rel_path = nil

        for _, line in ipairs(lines) do
          if line:match("^#%s+gallery%s*$") then
            in_gallery = true
          elseif in_gallery then
            if line:match("^#%s+") then break end  -- next heading, stop
            local p = line:match("^%s*path:%s*(.+)%s*$")
            if p then
              rel_path = p
              break
            end
          end
        end

        if not rel_path then
          vim.notify("No path: found under # gallery heading", vim.log.levels.WARN)
          return
        end

        local full_path = vim.fn.getcwd() .. "/" .. rel_path

        local cmd = string.format(
          'am start -a android.intent.action.VIEW -d "file://%s" -t "resource/folder" com.mixplorer',
          full_path
        )
        local result = vim.fn.system(cmd)
        if vim.v.shell_error ~= 0 then
          vim.notify("MixPlorer open failed:\n" .. result, vim.log.levels.ERROR)
        end
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
  },

}
