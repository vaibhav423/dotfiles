return {
  {
    "stevearc/resession.nvim",
    init = function()
      -- Inject the 'cwd' extension directly into memory so we don't need extra folders
      package.loaded["resession.extensions.cwd"] = {
        on_save = function(opts)
          if opts and opts.tabpage then
            local ok, num = pcall(vim.api.nvim_tabpage_get_number, opts.tabpage)
            if ok then
              return { cwd = vim.fn.getcwd(-1, num), is_tab = true }
            end
          end
          return { cwd = vim.fn.getcwd(), is_tab = false }
        end,
        on_post_load = function(data)
          if not data or not data.cwd then return end
          
          if data.is_tab then
            pcall(vim.cmd, "tcd " .. vim.fn.fnameescape(data.cwd))
          else
            pcall(vim.api.nvim_set_current_dir, data.cwd)
          end
        end,
      }
    end,
    opts = function(_, opts)
      opts.extensions = opts.extensions or {}
      opts.extensions.cwd = { enable_in_tab = true }
    end,
  },
  {
    "AstroNvim/astrocore",
    ---@param opts AstroCoreOpts
    opts = function(_, opts)
      local maps = opts.mappings
      
      -- Setup the new section leader
      maps.n["<Leader>s"] = { desc = "󰆓 Session" }
      
      -- Add new mappings with <Leader>s
      maps.n["<Leader>sl"] = { 
        function() 
          local resession = require("resession")
          local current = resession.get_current()
          if current == "Last Session" then
            -- If we are already in "Last Session", toggle back to the temporary one
            resession.load("_toggle_session", { silence_errors = true })
          else
            -- Otherwise, save the current state as a temp session before loading "Last Session"
            resession.save("_toggle_session", { attach = false, notify = false })
            resession.load("Last Session") 
          end
        end, 
        desc = "Toggle last session" 
      }
      maps.n["<Leader>ss"] = { function() require("resession").save() end, desc = "Save this session" }
      maps.n["<Leader>sS"] = {
        function() require("resession").save(vim.fn.getcwd(), { dir = "dirsession" }) end,
        desc = "Save this dirsession",
      }
      maps.n["<Leader>st"] = { function() require("resession").save_tab() end, desc = "Save this tab's session" }
      maps.n["<Leader>sd"] = { function() require("resession").delete() end, desc = "Delete a session" }
      maps.n["<Leader>sD"] = {
        function() require("resession").delete(nil, { dir = "dirsession" }) end,
        desc = "Delete a dirsession",
      }
      maps.n["<Leader>sf"] = { function() require("resession").load() end, desc = "Load a session" }
      maps.n["<Leader>sF"] = {
        function() require("resession").load(nil, { dir = "dirsession" }) end,
        desc = "Load a dirsession",
      }
      maps.n["<Leader>s."] = {
        function() require("resession").load(vim.fn.getcwd(), { dir = "dirsession" }) end,
        desc = "Load current dirsession",
      }

      -- Remove the old <Leader>S mappings
      maps.n["<Leader>S"] = false
      maps.n["<Leader>Sl"] = false
      maps.n["<Leader>Ss"] = false
      maps.n["<Leader>SS"] = false
      maps.n["<Leader>St"] = false
      maps.n["<Leader>Sd"] = false
      maps.n["<Leader>SD"] = false
      maps.n["<Leader>Sf"] = false
      maps.n["<Leader>SF"] = false
      maps.n["<Leader>S."] = false
    end,
  },
}
