-- Smart fold toggles (Option B - skip leaves)
-- z1..z4: toggle folds at level N (open those with content, close empty leaves)
-- <leader>z1..4: same for all windows
-- Toggle behavior: first press applies level N, second press closes all

-- track last applied level per window
local win_state = {}

local function ensure_fold_enabled(win)
  pcall(function()
    if not vim.api.nvim_win_get_option(win or 0, 'foldenable') then
      vim.api.nvim_win_set_option(win or 0, 'foldenable', true)
    end
  end)
end

local function md_heading_level(line)
  if not line then return nil end
  local hashes = line:match('^%s*(#+)%s+')
  if hashes then return #hashes end
  return nil
end

local function collect_markdown_headings(buf)
  local last = vim.api.nvim_buf_line_count(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local heads = {}

  -- try treesitter first
  local ok_par, parser = pcall(vim.treesitter.get_parser, buf, 'markdown')
  if ok_par and parser then
    local success, trees = pcall(function() return parser:parse() end)
    if success and trees and trees[1] then
      local root = trees[1]:root()
      local query_ok, query = pcall(vim.treesitter.query.parse, 'markdown', '((atx_heading) @h) ((setext_heading) @h)')
      if query_ok and query then
        for id, node in query:iter_captures(root, buf, 0, -1) do
          local name = query.captures[id]
          if name == 'h' then
            local srow = node:start()
            table.insert(heads, { start = srow + 1 })
          end
        end
      end
    end
  end

  -- fallback: scan lines
  if #heads == 0 then
    for i, line in ipairs(lines) do
      if md_heading_level(line) then
        table.insert(heads, { start = i })
      end
    end
  end

  if #heads == 0 then return {} end

  -- compute metadata for each heading in two passes
  -- Pass 1: compute basic info (finish, level)
  for idx = 1, #heads do
    local start = heads[idx].start
    local next_start = (heads[idx + 1] and heads[idx + 1].start) or (last + 1)
    heads[idx].finish = next_start - 1
    local line = lines[start]
    heads[idx].level = md_heading_level(line) or 1
  end
  
  -- Pass 2: compute relationships (has_child, has_body) now that all levels are known
  for idx = 1, #heads do
    local start = heads[idx].start
    
    -- check for child headings
    -- A child is a heading that comes after this one, before the next heading of same/lower level
    local has_child = false
    for j = idx + 1, #heads do
      -- Stop if we hit a heading at same or lower level (that's a sibling or uncle, not a child)
      if heads[j].level <= heads[idx].level then
        break
      end
      
      -- If we get here, this heading has a higher level number (deeper nesting), so it's a child
      has_child = true
      break
    end
    heads[idx].has_child = has_child
    
    -- check for non-empty body (non-heading, non-blank lines)
    local has_body = false
    for l = start + 1, heads[idx].finish do
      local ln = lines[l]
      if ln and ln:match('%S') and not md_heading_level(ln) then
        has_body = true
        break
      end
    end
    heads[idx].has_body = has_body
  end

  return heads
end

local function close_fold_level(win, n)
  ensure_fold_enabled(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local heads = collect_markdown_headings(buf)
  if #heads == 0 then return end

  local ok, orig_cursor = pcall(vim.api.nvim_win_get_cursor, win)

  for _, h in ipairs(heads) do
    if h.level == n then
      local is_closed = vim.fn.foldclosed(h.start) ~= -1
      if not is_closed then
        vim.api.nvim_win_call(win, function()
          vim.api.nvim_win_set_cursor(0, { h.start, 0 })
          pcall(vim.cmd, 'silent! normal! zc')
        end)
      end
    end
  end

  if ok and orig_cursor then pcall(vim.api.nvim_win_set_cursor, win, orig_cursor) end
end

local function apply_fold_level(win, n)
  ensure_fold_enabled(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.api.nvim_buf_get_option(buf, 'filetype')

  if ft == 'markdown' then
    -- IMPORTANT: collect heading metadata BEFORE any fold operations
    -- (so we can see the full structure even when folds are closed)
    local heads = collect_markdown_headings(buf)
    if #heads == 0 then return end

    local ok, orig_cursor = pcall(vim.api.nvim_win_get_cursor, win)

    -- Now apply fold operations based on pre-computed metadata
    for _, h in ipairs(heads) do
      local i = h.start
      local level = h.level
      -- Open if: (level == n) OR (level < n AND has_child)
      -- This means: always open headings at the requested level N,
      -- but for parent levels (< N), only open if they have children
      local should_open = (level == n) or ((level < n) and h.has_child)
      local is_closed = vim.fn.foldclosed(i) ~= -1

      if should_open and is_closed then
        vim.api.nvim_win_call(win, function()
          vim.api.nvim_win_set_cursor(0, { i, 0 })
          pcall(vim.cmd, 'silent! normal! zo')
        end)
      elseif (not should_open) and (not is_closed) then
        vim.api.nvim_win_call(win, function()
          vim.api.nvim_win_set_cursor(0, { i, 0 })
          pcall(vim.cmd, 'silent! normal! zc')
        end)
      end
    end

    if ok and orig_cursor then pcall(vim.api.nvim_win_set_cursor, win, orig_cursor) end
  else
    -- fallback for non-markdown
    local last = vim.api.nvim_buf_line_count(buf)
    if last == 0 then return end
    local fl = {}
    for i = 1, last do fl[i] = vim.fn.foldlevel(i) end
    local ok, orig_cursor = pcall(vim.api.nvim_win_get_cursor, win)
    
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
          if fl[k] > level then
            has_nested = true
            break
          end
        end
        local should_open = (level <= n) and has_nested
        local is_closed = vim.fn.foldclosed(i) ~= -1
        if should_open and is_closed then
          vim.api.nvim_win_call(win, function()
            vim.api.nvim_win_set_cursor(0, { i, 0 })
            pcall(vim.cmd, 'silent! normal! zo')
          end)
        elseif (not should_open) and (not is_closed) then
          vim.api.nvim_win_call(win, function()
            vim.api.nvim_win_set_cursor(0, { i, 0 })
            pcall(vim.cmd, 'silent! normal! zc')
          end)
        end
        i = end_line + 1
      else
        i = i + 1
      end
    end
    
    if ok and orig_cursor then pcall(vim.api.nvim_win_set_cursor, win, orig_cursor) end
  end
end

local function close_all_folds(win)
  vim.api.nvim_win_call(win, function()
    pcall(vim.cmd, 'silent! normal! zM')
  end)
end

local function toggle_fold(n)
  local win = vim.api.nvim_get_current_win()
  local last = win_state[win]
  
  if last == n then
    -- toggle off: just close folds at exactly level n, leave everything else untouched
    if n > 1 then
      close_fold_level(win, n)
      win_state[win] = n - 1
    else
      close_all_folds(win)
      win_state[win] = nil
    end
  else
    -- apply level n
    apply_fold_level(win, n)
    win_state[win] = n
  end
end

local function toggle_fold_all(n)
  -- check if any window has this level active
  local any_active = false
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win_state[w] == n then
      any_active = true
      break
    end
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

local function map_local(lhs, fn, desc)
  vim.keymap.set('n', lhs, fn, { noremap = true, silent = true, desc = desc })
end

map_local('z1', function() toggle_fold(1) end, 'Toggle fold level 1')
map_local('z2', function() toggle_fold(2) end, 'Toggle fold level 2')
map_local('z3', function() toggle_fold(3) end, 'Toggle fold level 3')
map_local('z4', function() toggle_fold(4) end, 'Toggle fold level 4')

map_local('<leader>z1', function() toggle_fold_all(1) end, 'Toggle fold level 1 (all)')
map_local('<leader>z2', function() toggle_fold_all(2) end, 'Toggle fold level 2 (all)')
map_local('<leader>z3', function() toggle_fold_all(3) end, 'Toggle fold level 3 (all)')
map_local('<leader>z4', function() toggle_fold_all(4) end, 'Toggle fold level 4 (all)')
