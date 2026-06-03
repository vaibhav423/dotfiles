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
    -- ["<Esc>"] = {
    --   function()
    --     local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
    --     if escape_excluded() or vim.bo.readonly or not vim.bo.modifiable then
    --       vim.api.nvim_feedkeys(esc, "n", true)
    --       return
    --     end
    --     vim.api.nvim_feedkeys(esc, "n", true)
    --     save_if_modified()
    --   end,
    --   desc = "Exit insert and save",
    -- },
  },

  -- Terminal mode -------------------------------------------------------------
  t = {
    -- Exit terminal mode and save if modified
    -- ["<Esc>"] = {
    --   function()
    --     local seq = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
    --     vim.api.nvim_feedkeys(seq, "n", true)
    --     save_if_modified()
    --   end,
    --   desc = "Exit terminal mode and save",
    -- },
  },

  -- Normal mode ---------------------------------------------------------------
  n = {
    -- Wikilink navigation
    ["<M-s>"]     = { function() require("common.personal.wikilink").collect() end,  desc = "Save all [[wikilinks]] in buffer" },
    ["<M-Right>"] = { function() require("common.personal.wikilink").next() end,     desc = "Next saved wikilink" },
    ["<M-Left>"]  = { function() require("common.personal.wikilink").prev() end,     desc = "Previous saved wikilink" },
    ["<M-f>"]     = { function() require("common.personal.wikilink").pick() end,     desc = "Fuzzy find saved wikilinks" },

    --neo-tree
    ["<Leader>e"]      = { "<Cmd>Neotree toggle dir=./<CR>" ,  desc = "Next buffer" },

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
    ["<Leader>ff"] = { function() require("snacks").picker.files({ hidden = vim.tbl_get((vim.uv or vim.loop).fs_stat ".git" or {}, "type") == "directory", follow = true }) end, desc = "Find Files" },
    ["<Leader>fa"] = { function() require("snacks").picker.files({ dirs = { vim.fn.stdpath("config") }, follow = true }) end, desc = "Find AstroNvim config files" },




    -- LSP
    ["<Leader>rl"] = { "<cmd>lsp restart<CR>", desc = "Restart LSP" },


    -- Copilot
    ["<Leader>tc"] = {
      "<cmd>Copilot! toggle<CR>",
      desc = "Toggle Copilot auto-trigger",
    },

    -- Jeerem reminder
    ["<Leader>jr"] = { "<cmd>Jeerem<CR>", desc = "Insert reminder on first line" },

    -- depreceated-vault-mappings
    ["<Leader>ji"] = { function() require("common.personal.vault_jee").init_template() end, desc = "Vault: init topic template" },
    ["<Leader>jp"] = { function() require("common.personal.vault_jee").set_pinned() end,    desc = "Vault: pick pinned directory" },
    ["<Leader>jo"] = { function() require("common.personal.vault_jee").open_pinned() end,   desc = "Vault: open pinned topic files" },
    ["<Leader>jR"] = { function() require("common.personal.vault_jee").set_moxide_root() end, desc = "Vault: set moxide root to vault" },
    ["<Leader>vp"] = { function() require("common.personal.vault").pick_pinned() end, desc = "Vault: pin current file" },
    ["<Leader>vo"] = { function() require("common.personal.vault").open_pinned() end, desc = "Vault: open pinned file" },


    -- YouTube frame capture (normal: auto-detect URL on current line)
    ["<Leader>yf"] = { function() require("common.personal.ytframe").capture_normal() end, desc = "Capture YouTube frame (current line URL)" },

    -- File finder (documents)
    ["<Leader>fd"] = {
      function()
        require("snacks").picker.files({ dirs = { "~/Water/ques" } })
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
    -- ["<Leader>fb"] = {false},
    ["\\"] = {false},
    ["te"] = { function() require("snacks").picker.buffers() end, desc = "Find buffers" },


    -- Delete image file under cursor and the current line
    ["<Leader>dd"] = {
      function()
        local cwd = vim.fn.getcwd()
        -- Extract path from markdown image link or fallback to <cfile>
        local line = vim.api.nvim_get_current_line()
        local rel_or_abs = line:match("!%[.-%]%((.-)%)") or vim.fn.expand("<cfile>")
        if rel_or_abs == "" then rel_or_abs = nil end
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

    -- toggle key maps (guarded: fold_toggle may be disabled)
    ["z1"] = { function() local ok, m = pcall(require, "common.personal.fold_toggle"); if ok and m.toggle then m.toggle(1) end end, desc = "Toggle fold level 1" },
    ["z2"] = { function() local ok, m = pcall(require, "common.personal.fold_toggle"); if ok and m.toggle then m.toggle(2) end end, desc = "Toggle fold level 2" },
    ["z3"] = { function() local ok, m = pcall(require, "common.personal.fold_toggle"); if ok and m.toggle then m.toggle(3) end end, desc = "Toggle fold level 3" },
    ["z4"] = { function() local ok, m = pcall(require, "common.personal.fold_toggle"); if ok and m.toggle then m.toggle(4) end end, desc = "Toggle fold level 4" },

    -- Fold level toggles (all windows in tabpage, guarded)
    ["<Leader>z1"] = { function() local ok, m = pcall(require, "common.personal.fold_toggle"); if ok and m.toggle_all then m.toggle_all(1) end end, desc = "Toggle fold level 1 (all windows)" },
    ["<Leader>z2"] = { function() local ok, m = pcall(require, "common.personal.fold_toggle"); if ok and m.toggle_all then m.toggle_all(2) end end, desc = "Toggle fold level 2 (all windows)" },
    ["<Leader>z3"] = { function() local ok, m = pcall(require, "common.personal.fold_toggle"); if ok and m.toggle_all then m.toggle_all(3) end end, desc = "Toggle fold level 3 (all windows)" },
    ["<Leader>z4"] = { function() local ok, m = pcall(require, "common.personal.fold_toggle"); if ok and m.toggle_all then m.toggle_all(4) end end, desc = "Toggle fold level 4 (all windows)" },
  },
    -- Visual mode ---------------------------------------------------------------
  v = {
    -- Substitute only within the visual selection
    ["<C-r>"] = { [[:s/\%V\%V//g<Left><Left><Left><Left><Left><Left>]], desc = "Substitute inside selection" },


    -- YouTube frame capture: visually select lines containing URLs, press <Leader>yf
    ["<Leader>yf"] = {
      ":<C-u>lua require('common.personal.ytframe').capture_visual()<CR>",
      desc = "Capture YouTube frames from all URLs in selection",
    },

    -- Selection encryption
    ["<Leader>xe"] = { ":<C-u>lua require('common.personal.encryption').encrypt_selection()<CR>", desc = "Encrypt selection" },
    ["<Leader>xd"] = { ":<C-u>lua require('common.personal.encryption').decrypt_selection()<CR>", desc = "Decrypt selection" },
  },

}
