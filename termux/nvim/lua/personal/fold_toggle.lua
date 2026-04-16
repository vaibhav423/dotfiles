-- Smart fold toggles with markdown heading awareness.
-- z1-z4: toggle fold level N in current window
-- <leader>z1-z4: same across all windows in current tabpage

local M = {}

local win_state = {}

local md_query = nil
local function get_md_query()
  if md_query then return md_query end
  local ok, q = pcall(vim.treesitter.query.parse, "markdown", "((atx_heading) @h) ((setext_heading) @h)")
  if ok and q then md_query = q end
  return md_query
end

local heads_cache = {}

local function ensure_fold_enabled(win)
  pcall(function()
    if not vim.api.nvim_get_option_value("foldenable", { win = win or 0 }) then
      vim.api.nvim_set_option_value("foldenable", true, { win = win or 0 })
    end
  end)
end

local function md_heading_level(line)
  if not line then return nil end
  local hashes = line:match("^%s*(#+)%s+")
  if hashes then return #hashes end
  return nil
end

local function collect_markdown_headings(buf)
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local cached = heads_cache[buf]
  if cached and cached.tick == tick then return cached.heads end

  local last = vim.api.nvim_buf_line_count(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local heads = {}

  local ok_par, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if ok_par and parser then
    local success, trees = pcall(function() return parser:parse() end)
    if success and trees and trees[1] then
      local root = trees[1]:root()
      local query = get_md_query()
      if query then
        for id, node in query:iter_captures(root, buf, 0, -1) do
          local name = query.captures[id]
          if name == "h" then
            local srow = node:start()
            table.insert(heads, { start = srow + 1 })
          end
        end
      end
    end
  end

  if #heads == 0 then
    for i, line in ipairs(lines) do
      if md_heading_level(line) then table.insert(heads, { start = i }) end
    end
  end

  if #heads == 0 then return {} end

  for idx = 1, #heads do
    local start = heads[idx].start
    local next_start = (heads[idx + 1] and heads[idx + 1].start) or (last + 1)
    heads[idx].finish = next_start - 1
    local line = lines[start]
    heads[idx].level = md_heading_level(line) or 1
  end

  for idx = 1, #heads do
    local has_child = false
    for j = idx + 1, #heads do
      if heads[j].level <= heads[idx].level then break end
      has_child = true
      break
    end
    heads[idx].has_child = has_child

    local has_body = false
    for l = heads[idx].start + 1, heads[idx].finish do
      local ln = lines[l]
      if ln and ln:match("%S") and not md_heading_level(ln) then
        has_body = true
        break
      end
    end
    heads[idx].has_body = has_body
  end

  heads_cache[buf] = { tick = tick, heads = heads }
  return heads
end

local function close_fold_level(win, n)
  ensure_fold_enabled(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local heads = collect_markdown_headings(buf)
  if #heads == 0 then return end

  local ok, orig_cursor = pcall(vim.api.nvim_win_get_cursor, win)
  vim.api.nvim_win_call(win, function()
    for _, h in ipairs(heads) do
      if h.level == n and vim.fn.foldclosed(h.start) == -1 then
        vim.api.nvim_win_set_cursor(0, { h.start, 0 })
        pcall(vim.cmd, "silent! normal! zc")
      end
    end
  end)
  if ok and orig_cursor then pcall(vim.api.nvim_win_set_cursor, win, orig_cursor) end
end

local function apply_fold_level(win, n)
  ensure_fold_enabled(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype

  if ft == "markdown" then
    local heads = collect_markdown_headings(buf)
    if #heads == 0 then return end

    local ok, orig_cursor = pcall(vim.api.nvim_win_get_cursor, win)
    vim.api.nvim_win_call(win, function()
      for _, h in ipairs(heads) do
        local should_open = (h.level == n) or ((h.level < n) and h.has_child)
        local is_closed = vim.fn.foldclosed(h.start) ~= -1
        if should_open and is_closed then
          vim.api.nvim_win_set_cursor(0, { h.start, 0 })
          pcall(vim.cmd, "silent! normal! zo")
        elseif (not should_open) and (not is_closed) then
          vim.api.nvim_win_set_cursor(0, { h.start, 0 })
          pcall(vim.cmd, "silent! normal! zc")
        end
      end
    end)
    if ok and orig_cursor then pcall(vim.api.nvim_win_set_cursor, win, orig_cursor) end
  else
    local last = vim.api.nvim_buf_line_count(buf)
    if last == 0 then return end
    local fl = {}
    for i = 1, last do fl[i] = vim.fn.foldlevel(i) end
    local ok, orig_cursor = pcall(vim.api.nvim_win_get_cursor, win)

    vim.api.nvim_win_call(win, function()
      local i = 1
      while i <= last do
        local level = fl[i]
        local prev = (i > 1) and fl[i - 1] or 0
        if level > prev then
          local j = i + 1
          while j <= last and fl[j] >= level do j = j + 1 end
          local end_line = j - 1
          local has_nested = false
          for k = i + 1, end_line do
            if fl[k] > level then has_nested = true; break end
          end
          local should_open = (level <= n) and has_nested
          local is_closed = vim.fn.foldclosed(i) ~= -1
          if should_open and is_closed then
            vim.api.nvim_win_set_cursor(0, { i, 0 })
            pcall(vim.cmd, "silent! normal! zo")
          elseif (not should_open) and (not is_closed) then
            vim.api.nvim_win_set_cursor(0, { i, 0 })
            pcall(vim.cmd, "silent! normal! zc")
          end
          i = end_line + 1
        else
          i = i + 1
        end
      end
    end)
    if ok and orig_cursor then pcall(vim.api.nvim_win_set_cursor, win, orig_cursor) end
  end
end

local function close_all_folds(win)
  vim.api.nvim_win_call(win, function() pcall(vim.cmd, "silent! normal! zM") end)
end

function M.toggle(n)
  local win = vim.api.nvim_get_current_win()
  local last = win_state[win]
  if last == n then
    if n > 1 then
      close_fold_level(win, n)
      win_state[win] = n - 1
    else
      close_all_folds(win)
      win_state[win] = nil
    end
  else
    apply_fold_level(win, n)
    win_state[win] = n
  end
end

function M.toggle_all(n)
  local any_active = false
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win_state[w] == n then any_active = true; break end
  end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if any_active then
      if n > 1 then
        close_fold_level(w, n)
        win_state[w] = n - 1
      else
        close_all_folds(w)
        win_state[w] = nil
      end
    else
      apply_fold_level(w, n)
      win_state[w] = n
    end
  end
end

function M.clear_cache(buf)
  heads_cache[buf] = nil
end

return M
