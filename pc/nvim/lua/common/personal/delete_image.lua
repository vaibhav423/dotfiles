local M = {}
function  M.delete()
  local cwd = vim.fn.getcwd()
  -- Extract path from markdown image link or fallback to <cfile>
  local line = vim.api.nvim_get_current_line()
  local rel_or_abs = line:match("!%[.-%]%((.-)%)") or vim.fn.expand("<cfile>")
  if rel_or_abs == "" then rel_or_abs = nil end
  if not rel_or_abs or rel_or_abs == "" then
    vim.notify("DeletePhoto: no path found under cursor", vim.log.levels.WARN)
    return
  end

  local abs_path
  if rel_or_abs:sub(1, 1) == "/" then
    abs_path = rel_or_abs
  else
    abs_path = cwd .. "/" .. rel_or_abs
  end

  if vim.fn.filereadable(abs_path) == 0 then
    vim.notify("DeletePhoto: file not found:\n" .. abs_path, vim.log.levels.WARN)
  else
    vim.fn.delete(abs_path)
  end

  -- Delete the current line
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, {})

  vim.schedule(function()
    vim.notify("Deleted: " .. rel_or_abs, vim.log.levels.INFO)
  end)
end

return M
