
-- Customize Mason

---@type LazySpec
return {
  -- use mason-tool-installer for automatically installing Mason packages
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    -- overrides `require("mason-tool-installer").setup(...)`
    opts = {
      -- Make sure to use the names found in `:Mason`
      ensure_installed = {
        -- install debuggers
        "debugpy",

        -- install any other package
      },
      -- Skip tools that fail to install due to platform incompatibility
      auto_update = false,
      -- Don't raise errors for tools that can't be installed
      run_on_start = true,
      start_delay = 3000,
    },
  },
}
