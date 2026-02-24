
-- Save-on-Esc (deferred, safe)
-- Placed in after/plugin so it loads last and overrides other mappings

local excluded_filetypes = {
  "TelescopePrompt",
  "TelescopeResults",
  "lazy",
  "NvimTree",
  "neo-tree",
  "fzf",
  "alpha",
  "packer",
  "Trouble",
}

local function contains(tbl, val)
  for _, v in ipairs(tbl) do
    if v == val then
      return true
    end
  end
  return false
end

local function is_excluded_buffer()
  if vim.bo.buftype ~= "" then
    return true
  end
  if vim.bo.filetype and contains(excluded_filetypes, vim.bo.filetype) then
    return true
  end
  return false
end

-- Insert mode: exit insert, then schedule a save if modified
vim.keymap.set('i', '<Esc>', function()
  local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
  if is_excluded_buffer() or vim.bo.readonly or not vim.bo.modifiable then
    vim.api.nvim_feedkeys(esc, 'n', true)
    return
  end
  vim.api.nvim_feedkeys(esc, 'n', true)
  if vim.bo.modified then
    vim.schedule(function() vim.cmd('silent! update') end)
  end
end, { noremap = true, silent = true })

-- Terminal mode: go to normal mode then schedule save for file buffers
vim.keymap.set('t', '<Esc>', function()
  local seq = vim.api.nvim_replace_termcodes('<C-\\><C-n>', true, false, true)
  vim.api.nvim_feedkeys(seq, 'n', true)
  if is_excluded_buffer() or vim.bo.readonly or not vim.bo.modifiable then
    return
  end
  if vim.bo.modified then
    vim.schedule(function() vim.cmd('silent! update') end)
  end
end, { noremap = true, silent = true })
