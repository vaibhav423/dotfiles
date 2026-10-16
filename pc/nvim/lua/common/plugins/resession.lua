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

      -- Loading a session inside tmux would nuke the layout of the window we are
      -- running in, so spawn a new tmux window instead. Outside tmux there is
      -- nothing to protect, so just load it as usual.
      local function in_tmux()
        return vim.fn.executable("tmux") == 1 and not not vim.env.TMUX
      end

      ---@param opts? { dir?: string }
      local function load_session(opts)
        opts = opts or {}
        if not in_tmux() then
          return require("resession").load(opts.session, { dir = opts.dir })
        end

        local sessions = require("resession").list({ dir = opts.dir })
        if vim.tbl_isempty(sessions) then
          vim.notify("No saved sessions", vim.log.levels.WARN)
          return
        end

        vim.ui.select(sessions, { kind = "resession_load", prompt = "Load session in new tmux window" }, function(selected)
          if not selected then return end

          local shellescape = vim.fn.shellescape
          local shell_cmd = table.concat({
            "env",
            "RESESSION_SESSION=" .. shellescape(selected),
            "RESESSION_DIR=" .. shellescape(opts.dir or ""),
            "nvim",
            "-S",
            shellescape(vim.fn.stdpath("config") .. "/lua/personal/resession_open.lua"),
          }, " ")

          local job = vim.fn.jobstart({ "tmux", "new-window", "-n", selected, shell_cmd }, { detach = true })
          if job <= 0 then
            vim.notify("Could not open tmux window", vim.log.levels.ERROR)
          end
        end)
      end
      
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
      maps.n["<Leader>sf"] = { function() load_session() end, desc = "Load a session" }
      maps.n["<Leader>sF"] = {
        function() load_session({ dir = "dirsession" }) end,
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
