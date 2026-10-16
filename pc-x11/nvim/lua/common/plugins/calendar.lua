local v = require("personal.variables")

local ext = {}

function ext.get(year, month)
  local marks = {}
  local journal_dir = v.vaultdir .. "/journal"
  local handle = vim.loop.fs_scandir(journal_dir)
  if not handle then
    return marks
  end
  while true do
    local name = vim.loop.fs_scandir_next(handle)
    if not name then break end
    local y, m, d = name:match("^(%d%d%d%d)-(%d%d)-(%d%d)%.md$")
    if y and tonumber(y) == year and tonumber(m) == month then
      table.insert(marks, { year = tonumber(y), month = tonumber(m), day = tonumber(d) })
    end
  end
  return marks
end

ext.actions = {
  open_note = function(year, month, day)
    local date_str = string.format("%04d-%02d-%02d", year, month, day)
    vim.cmd("edit " .. v.vaultdir .. "/journal/" .. date_str .. ".md")
  end,
}

return {
  "wsdjeg/calendar.nvim",
  opts = {
    mark_icon = "•",
  },
  config = function(_, opts)
    require("calendar").setup(opts)
    require("calendar.extensions").register("journal", ext)
  end,
}
