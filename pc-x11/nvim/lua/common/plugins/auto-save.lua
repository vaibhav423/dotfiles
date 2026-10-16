return{
  "okuuva/auto-save.nvim",
  version = '*', -- see https://devhints.io/semver, alternatively use '*' to use the latest tagged release
  cmd = "ASToggle", -- optional for lazy loading on command
  event = { "InsertLeave", "TextChanged", "TextChangedI" }, -- optional for lazy loading on trigger events
  opts = {
    trigger_events = {
      defer_save = { "InsertLeave", "TextChanged", "TextChangedI" },
    },
    condition = function(buf)
      local fn = vim.fn
      if fn.getbufvar(buf, "&filetype") == "markdown" then
        return true
      end
      return false
    end,
  },
}
