local prefix = "<Leader>a"
return {
  "yetone/avante.nvim",
  build = vim.fn.has "win32" == 1 and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
    or "make",
  event = "User AstroFile", -- load on file open because Avante manages it's own bindings
  cmd = {
    "AvanteAsk",
    "AvanteBuild",
    "AvanteEdit",
    "AvanteRefresh",
    "AvanteSwitchProvider",
    "AvanteShowRepoMap",
    "AvanteModels",
    "AvanteChat",
    "AvanteToggle",
    "AvanteClear",
    "AvanteFocus",
    "AvanteStop",
  },
  dependencies = {
    { "stevearc/dressing.nvim", optional = true },
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    {
      "AstroNvim/astrocore",
      opts = function(_, opts)
        local maps = opts.mappings.n
        maps[prefix] = { desc = " Avante" }
        maps[prefix .. "N"] = {
          function()
            local config = require "avante.config"
            local saved = config.behaviour.auto_add_current_file
            config.behaviour.auto_add_current_file = false
            vim.cmd "AvanteChatNew"
            config.behaviour.auto_add_current_file = saved
          end,
          desc = "Avante New Chat (No Files)",
        }
      end,
    },
  },
  opts = {
    -- provider = "gemini-cli",
    behaviour = {
      auto_add_current_file = false,
    },
    providers = {
      gemini = {
        endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
        model = "gemini-3-flash-preview",
        timeout = 30000,
        -- extra_request_body = {
        --   temperature = 0.75,
        --   maxOutputTokens = 8192,
        -- },
        is_env_set = function() return true end,
      },
      ["gemini-cli"] = {
        __inherited_from = "gemini",
        model = "gemini-3-flash-preview",
        is_env_set = function() return true end,
      },
    },
    acp_providers = {
      ["gemini-cli"] = {
        command = "gemini",
        args = { "--experimental-acp" },
        env = {
          NODE_NO_WARNINGS = "1",
          HOME = os.getenv("HOME"),
          GEMINI_API_KEY = os.getenv("GEMINI_API_KEY"),
          GEMINI_DEFAULT_AUTH_TYPE = "oauth-personal",
          GEMINI_MODEL = "gemini-3-flash-preview",
        },
        auth_method = "oauth-personal",
      },
    },
        
    selection = { hint_display = "none", },
    windows = {
      width = 60,
    },
    shortcuts = {
      {
        name = "quick",
        description = "One line answer",
        prompt = "Provide a concise answer that fits in a single line.",
      },
    },

    mappings = {
      ask = prefix .. "<CR>",
      edit = prefix .. "e",
      refresh = prefix .. "r",
      new_ask = prefix .. "n",
      focus = prefix .. "f",
      select_model = prefix .. "?",
      stop = prefix .. "S",
      select_history = prefix .. "h",
      toggle = {
        default = prefix .. "t",
        debug = prefix .. "d",
        hint = prefix .. "H",
        suggestion = prefix .. "s",
        repomap = prefix .. "R",
        selection = prefix .. "C",
      },
      zen_mode = prefix .. "Z",
      diff = {
        next = "]c",
        prev = "[c",
      },
      files = {
        add_current = prefix .. ".",
        add_all_buffers = prefix .. "B",
      },
    },
  },
  config = function(_, opts)
    require("avante").setup(opts)

    -- ACP Session/Context Fixes (Monkey-patching)
    -- These patches ensure that ACP sessions are correctly reset when the chat is cleared or a new chat is started.
    local Sidebar = require("avante.sidebar")
    local Llm = require("avante.llm")

    -- 1. Ensure ACP client is killed on Sidebar reset
    local old_reset = Sidebar.reset
    Sidebar.reset = function(self)
      if self.acp_client then
        pcall(function() self.acp_client:stop() end)
        self.acp_client = nil
      end
      return old_reset(self)
    end

    -- 2. Ensure ACP client is killed when starting a New Chat
    local old_new_chat = Sidebar.new_chat
    Sidebar.new_chat = function(self, args, cb)
      if self.acp_client then
        pcall(function() self.acp_client:stop() end)
        self.acp_client = nil
      end
      return old_new_chat(self, args, cb)
    end

    -- 3. Clear ACP session ID on history clear
    local old_clear_history = Sidebar.clear_history
    Sidebar.clear_history = function(self, args, cb)
      if self.chat_history then
        self.chat_history.acp_session_id = nil
      end
      return old_clear_history(self, args, cb)
    end

    -- 4. Prevent UI hang on compaction failure
    local old_summarize_memory = Llm.summarize_memory
    Llm.summarize_memory = function(prev_memory, history_messages, cb)
      old_summarize_memory(prev_memory, history_messages, function(memory)
        if memory == nil then
          -- If summarization failed, we still need to trigger the callback
          -- to reset the sidebar state from "compacting"
          cb(nil)
        else
          cb(memory)
        end
      end)
    end

    -- 5. Persistent Model Fix (Monkey-patching)
    -- This bypasses the ACP guard in apply_model_selection during startup
    local config_mod = require("avante.config")
    local old_setup = config_mod.setup
    config_mod.setup = function(s_opts)
      local real_acp_providers = config_mod.acp_providers
      config_mod.acp_providers = {} -- Momentarily hide to bypass the guard in apply_model_selection
      old_setup(s_opts)
      config_mod.acp_providers = real_acp_providers -- Restore
    end

    -- 6. Dynamic Model Sync Fix (Monkey-patching)
    -- Ensures the GEMINI_MODEL env var matches the selected model in the UI
    local old_stream_acp = Llm._stream_acp
    Llm._stream_acp = function(s_opts)
      local conf = require("avante.config")
      if conf.provider == "gemini-cli" then
        local acp_provider = conf.acp_providers[conf.provider]
        if acp_provider then
          acp_provider.env = acp_provider.env or {}
          acp_provider.env.GEMINI_MODEL = conf.get_provider_config(conf.provider).model
        end
      end
      return old_stream_acp(s_opts)
    end
  end,
  specs = { -- configure optional plugins
    { "AstroNvim/astroui", opts = { icons = { Avante = "" } } },
    {
      "Kaiser-Yang/blink-cmp-avante",
      lazy = true,
      specs = {
        {
          "Saghen/blink.cmp",
          optional = true,
          opts = {
            sources = {
              default = { "avante" },
              providers = {
                avante = { module = "blink-cmp-avante", name = "Avante" },
              },
            },
          },
        },
      },
    },
    { -- if copilot.lua is available, default to copilot provider
      "zbirenbaum/copilot.lua",
      optional = true,
      specs = {
        {
          "yetone/avante.nvim",
          opts = {
            provider = "copilot",
            auto_suggestions_provider = "copilot",
          },
        },
      },
    },
    {
      -- make sure `Avante` is added as a filetype
      "MeanderingProgrammer/render-markdown.nvim",
      optional = true,
      opts = function(_, opts)
        if not opts.file_types then opts.file_types = { "markdown" } end
        opts.file_types = require("astrocore").list_insert_unique(opts.file_types, { "Avante" })
      end,
    },
    {
      -- make sure `Avante` is added as a filetype
      "OXY2DEV/markview.nvim",
      optional = true,
      opts = function(_, opts)
        if not opts.preview then opts.preview = {} end
        if not opts.preview.filetypes then opts.preview.filetypes = { "markdown", "quarto", "rmd" } end
        opts.preview.filetypes = require("astrocore").list_insert_unique(opts.preview.filetypes, { "Avante" })
      end,
    },
    {
      "folke/snacks.nvim",
      optional = true,
      specs = {
        {
          "yetone/avante.nvim",
          opts = {
            selector = {
              provider = "snacks",
            },
          },
        },
      },
    },
    {
      "nvim-neo-tree/neo-tree.nvim",
      optional = true,
      opts = {
        filesystem = {
          commands = {
            avante_add_files = function(state)
              local node = state.tree:get_node()
              local filepath = node:get_id()
              local relative_path = require("avante.utils").relative_path(filepath)

              local sidebar = require("avante").get()

              local open = sidebar:is_open()
              -- ensure avante sidebar is open
              if not open then
                require("avante.api").ask()
                sidebar = require("avante").get()
              end

              sidebar.file_selector:add_selected_file(relative_path)

              -- remove neo tree buffer
              if not open then sidebar.file_selector:remove_selected_file "neo-tree filesystem [1]" end
            end,
          },
          window = {
            mappings = {
              ["oa"] = "avante_add_files",
            },
          },
        },
      },
    },
  },
}
