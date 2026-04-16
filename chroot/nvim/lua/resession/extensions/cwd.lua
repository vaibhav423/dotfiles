local M = {}

M.on_save = function(opts)
  if opts and opts.tabpage then
    local ok, num = pcall(vim.api.nvim_tabpage_get_number, opts.tabpage)
    if ok then
      return { cwd = vim.fn.getcwd(-1, num), is_tab = true }
    end
  end
  return { cwd = vim.fn.getcwd(), is_tab = false }
end

M.on_post_load = function(data)
  if not data or not data.cwd then return end
  
  if data.is_tab then
    pcall(vim.cmd, "tcd " .. vim.fn.fnameescape(data.cwd))
  else
    pcall(vim.api.nvim_set_current_dir, data.cwd)
  end
end

return M
