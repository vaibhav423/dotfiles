-- config/mappings.lua: all global keymaps for astrocore.
-- Add new mappings here. astrocore.lua merges this into opts.mappings.

local warn_hidden = true
local function toggle_warnings()
  warn_hidden = not warn_hidden
  local sev = vim.diagnostic.severity
  local no_warn = warn_hidden and { sev.ERROR, sev.INFO, sev.HINT }
    or { sev.ERROR, sev.WARN, sev.INFO, sev.HINT }
  vim.diagnostic.config {
    virtual_text = { severity = no_warn },
    underline = { severity = no_warn },
    signs = { severity = no_warn },
  }
  vim.notify("Diagnostic warnings: " .. (warn_hidden and "hidden" or "shown"), vim.log.levels.INFO)
end

return {

  -- Insert mode ---------------------------------------------------------------
  i = {
  },

  -- Terminal mode -------------------------------------------------------------
  t = {
  },

  -- Normal mode ---------------------------------------------------------------
  n = {
    -- Wikilink navigation
    ["<M-s>"]     = { function() require("common.personal.wikilink").collect() end,  desc = "Save all [[wikilinks]] in buffer" },
    ["<M-Right>"] = { function() require("common.personal.wikilink").next() end,     desc = "Next saved wikilink" },
    ["<M-Left>"]  = { function() require("common.personal.wikilink").prev() end,     desc = "Previous saved wikilink" },
    ["<M-f>"]     = { function() require("common.personal.wikilink").pick() end,     desc = "Fuzzy find saved wikilinks" },
    ["<M-g>"]     = {
      function()
        vim.lsp.buf.code_action({
          filter = function(action) return action.title:match("[Cc]reate") end,
          apply = true,
        })
        vim.defer_fn(function()
          vim.cmd("lsp restart")
          vim.defer_fn(function() vim.lsp.buf.definition() end, 400)
        end, 300)
      end,
      desc = "Create wikilink, restart LSP, go to definition",
    },

    --neo-tree
    ["<Leader>e"]      = { "<Cmd>Neotree toggle dir=./<CR>" ,  desc = "Next buffer" },

    ["<Leader>o"] = {false} ,
    ["<Leader>oc"] = { "<Cmd>Calendar<CR>", desc = "open calendar" },
    -- Buffers
    ["<Tab>"]      = { function() require("astrocore.buffer").nav(vim.v.count1) end,  desc = "Next buffer" },
    -- t is nvim inbuilt key for till  , this new map blocks tt which should make cursour movie behind next t 
    ["<S-TAB>"]    = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },
    ["<Leader>bd"] = { function() require("astroui.status.heirline").buffer_picker(function(bufnr) require("astrocore.buffer").close(bufnr) end) end, desc = "Close buffer from tabline",},
    -- exchange mappings between grep_wprd and commands
    ["<Leader>fC"] =  { function() require("snacks").picker.grep_word() end, desc = "Find word under cursor" },

    ["<Leader>fc"] = { function() require("snacks").picker.commands() end, desc = "Find commands" },
    ["<Leader>ff"] = {
      function()
        require("snacks").picker.files({
          hidden = vim.tbl_get((vim.uv or vim.loop).fs_stat ".git" or {}, "type") == "directory",
          exclude = { "*.png", "*.jpg", "*.jpeg" , ".gitignore", ".env" , ".copilot-index" } ,
          -- follow = true
        })
      end,
      desc = "Find Files"
    },
    ["<Leader>fa"] = { function() require("snacks").picker.files({ dirs = { vim.fn.stdpath("config") }, follow = true }) end, desc = "Find AstroNvim config files" },

    -- LSP
    ["<Leader>rl"] = { "<cmd>lsp restart<CR>", desc = "Restart LSP" },

    -- Copilot
    ["<Leader>tc"] = {"<cmd>Copilot! toggle<CR>",desc = "Toggle Copilot auto-trigger"},

    -- Jeerem reminder
    ["<Leader>jr"] = { "<cmd>Jeerem<CR>", desc = "Insert reminder on first line" },

    -- depreceated-vault-mappings
    ["<Leader>ji"] = { function() require("common.personal.vault_jee").init_template() end, desc = "Vault: init topic template" },
    ["<Leader>jp"] = { function() require("common.personal.vault_jee").set_pinned() end,    desc = "Vault: pick pinned directory" },
    ["<Leader>jo"] = { function() require("common.personal.vault_jee").open_pinned() end,   desc = "Vault: open pinned topic files" },
    ["<Leader>jR"] = { function() require("common.personal.vault_jee").set_moxide_root() end, desc = "Vault: set moxide root to vault" },
    --- vault mappings
    ["<Leader>vp"] = { function() require("common.personal.vault").pick_pinned() end, desc = "Vault: pin current file" },
    ["<Leader>vo"] = { function() require("common.personal.vault").open_pinned() end, desc = "Vault: open pinned file" },
    ["<Leader>yf"] = { function() require("common.personal.ytframe").capture_normal() end, desc = "Capture YouTube frame (current line URL)" },
    ["<Leader>fd"] = {function() require("snacks").picker.files({ dirs = { "~/Water/ques" } }) end,desc = "Find documents files",},
    ["<Leader>fn"] = {function() require("snacks").picker.files({ dirs = { "~/.local/share/nvim/" } }) end, desc = "Find nvim docs"},
    -- change default notifications mapping from fn to fN
    ["<Leader>fN"] = { function() require("snacks").picker.notifications() end, desc = "Find notifications" },

    -- Notesh: share buffer content
    ["<Leader>ms"] = { function() require("common.personal.notesh").create_note() end, desc = "Share buffer via notesh.ink" },

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
    ["<Leader>dd"] = {function() require("common.personal.delete_image").delete() end, desc = "Delete image file under cursor and current line",},

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
    -- Code Runner
    ["<Leader>or"] = { function() require("common.personal.code_runner").run() end, desc = "Run code file in buffer" },
    ["<Leader>oi"] = { function() require("common.personal.code_runner").toggle_layout() end, desc = "Toggle Code I/O Layout" },

    -- Toggle diagnostic warnings (hide/show yellow warnings)
    ["<Leader>uw"] = { toggle_warnings, desc = "Toggle hiding diagnostic warnings" },

    -- calendar
      
  },
    -- Visual mode ---------------------------------------------------------------
  v = {
    -- Substitute only within the visual selection
    ["<C-r>"] = { [[:s/\%V\%V//g<Left><Left><Left><Left><Left><Left>]], desc = "Substitute inside selection" },


    -- YouTube frame capture: visually select lines containing URLs, press <Leader>yf
    ["<Leader>yf"] = {
      ":<C-u>lua require('common.personal.ytframe').capture_visual()<CR>", desc = "Capture YouTube frames from all URLs in selection"},

    -- Selection encryption
    ["<Leader>xe"] = { ":<C-u>lua require('common.personal.encryption').encrypt_selection()<CR>", desc = "Encrypt selection" },
    ["<Leader>xd"] = { ":<C-u>lua require('common.personal.encryption').decrypt_selection()<CR>", desc = "Decrypt selection" },
  },

}
