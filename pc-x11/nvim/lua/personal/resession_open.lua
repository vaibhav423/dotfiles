-- Opens a saved resession inside a fresh nvim process.
-- Used by `tmux new-window` so a session can be loaded without disturbing the
-- current layout. The session to load is passed in through the environment:
--   RESESSION_SESSION  session name (required)
--   RESESSION_DIR      resession sub-directory (optional, e.g. "dirsession")

local session = vim.env.RESESSION_SESSION

if not session or session == "" then
  vim.notify("RESESSION_SESSION is not set", vim.log.levels.ERROR)
  return
end

local dir = vim.env.RESESSION_DIR
if dir == "" then
  dir = nil
end

vim.schedule(function()
  local ok, err = pcall(require("resession").load, session, { dir = dir })
  if not ok then
    vim.notify("Failed to load session: " .. tostring(err), vim.log.levels.ERROR)
  end
end)