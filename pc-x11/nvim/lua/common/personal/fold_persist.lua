-- Fold persistence: save and restore fold state across sessions.
-- Works correctly with treesitter foldexpr by retrying until folds are computed.

local M = {}

local cache_dir = vim.fn.stdpath("state") .. "/folds"

local function cache_file(fname)
  return cache_dir .. "/" .. vim.fn.sha256(fname)
end

function M.save(buf)
  if vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_get_name(buf) == "" then return end
  local fname = vim.api.nvim_buf_get_name(buf)
  local closed = {}
  local lcount = vim.api.nvim_buf_line_count(buf)
  local i = 1
  while i <= lcount do
    local fc = vim.fn.foldclosed(i)
    if fc == i then
      table.insert(closed, i)
      i = vim.fn.foldclosedend(i) + 1
    else
      i = i + 1
    end
  end
  vim.fn.mkdir(cache_dir, "p")
  local f = io.open(cache_file(fname), "w")
  if f then f:write(table.concat(closed, "\n")); f:close() end
  vim.b[buf].folds_restored = nil
end

function M.restore(buf)
  if vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_get_name(buf) == "" then return end
  if vim.b[buf].folds_restored then return end
  local fname = vim.api.nvim_buf_get_name(buf)
  local f = io.open(cache_file(fname), "r")
  if not f then return end
  local content = f:read("*a"); f:close()
  if content == "" then return end

  local to_close = {}
  for line in content:gmatch("[^\n]+") do
    local lnum = tonumber(line)
    if lnum then table.insert(to_close, lnum) end
  end
  if #to_close == 0 then return end

  -- retry up to ~2s to wait for treesitter foldexpr to finish computing
  local attempts = 0
  local function try_restore()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    if vim.b[buf].folds_restored then return end
    local win = vim.fn.bufwinid(buf)
    if win == -1 then
      if attempts < 40 then
        attempts = attempts + 1
        vim.defer_fn(try_restore, 50)
      end
      return
    end
    -- wait until treesitter has computed foldlevels
    local ready = false
    for _, lnum in ipairs(to_close) do
      if vim.fn.foldlevel(lnum) > 0 then ready = true; break end
    end
    if not ready and attempts < 40 then
      attempts = attempts + 1
      vim.defer_fn(try_restore, 50)
      return
    end
    vim.b[buf].folds_restored = true
    for _, lnum in ipairs(to_close) do
      if vim.fn.foldlevel(lnum) > 0 and vim.fn.foldclosed(lnum) == -1 then
        vim.api.nvim_win_call(win, function()
          vim.api.nvim_win_set_cursor(0, { lnum, 0 })
          pcall(vim.cmd, "silent! normal! zc")
        end)
      end
    end
  end
  vim.schedule(try_restore)
end

return M
