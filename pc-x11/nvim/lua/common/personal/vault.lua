local M = {}

local vars = require("personal.variables")

-- Helper to normalize paths (handles double slashes and cross-platform backslashes)
local function normalize_path(path)
  return vim.fs.normalize(path)
end

local vault_dir = normalize_path(vars.vaultdir)
local PINNED_FILE = vault_dir .. "/pinned_file"

-- Centralized notification wrapper to keep code clean and prefix consistent
local function notify(msg, level)
  vim.notify("vault: " .. msg, level or vim.log.levels.INFO)
end

local function read_file(path)
  local file, err = io.open(path, "r")
  if not file then return nil, err end

  local content = file:read("*a")
  file:close()

  return vim.trim(content)
end

local function write_file(path, text)
  local file, err = io.open(path, "w")
  if not file then return nil, err end

  file:write(text .. "\n")
  file:close()

  return true
end

function M.pick_pinned()
  local current_path = normalize_path(vim.api.nvim_buf_get_name(0))

  if current_path == "" then
    return notify("current buffer has no file path", vim.log.levels.WARN)
  end

  -- Verify file is inside the vaultdir
  if not vim.startswith(current_path, vault_dir) then
    return notify("current file is not inside vaultdir", vim.log.levels.WARN)
  end

  -- Extract relative path securely and drop the leading slash
  local relative_path = current_path:sub(#vault_dir + 1):gsub("^/", "")

  local ok, err = write_file(PINNED_FILE, relative_path)
  if not ok then
    return notify("could not write pinned file: " .. (err or "unknown"), vim.log.levels.ERROR)
  end

  notify("pinned file -> " .. relative_path)
end

function M.open_pinned()
  local relative_path, err = read_file(PINNED_FILE)

  if not relative_path or relative_path == "" then
    return notify("could not read pinned file: " .. (err or "empty"), vim.log.levels.ERROR)
  end

  -- Reconstruct the absolute path and normalize it to clear any trailing/leading slash issues
  local absolute_path = normalize_path(vault_dir .. "/" .. relative_path)

  if vim.fn.filereadable(absolute_path) == 0 then
    return notify("pinned file not found: " .. absolute_path, vim.log.levels.ERROR)
  end

  vim.cmd("edit " .. vim.fn.fnameescape(absolute_path))
end

return M
