-- lib/wikilink.lua
-- Alt-s: collect all [[wikilink]] paths in current buffer, resolve targets via LSP upfront.
-- Alt-Right/Left: instantly cycle through them (no LSP round-trip per hop).

local M = {}

-- resolved: array of { filename, lnum, col } — populated by collect()
local resolved  = {}
local idx       = 0    -- 1-based; 0 = not yet navigated
local _prev_buf = nil  -- buffer from last hop, closed on next hop

-- Parse a wikilink token: return the bare file path (vault-relative, no anchor, no alias).
local function token_to_name(token)
  local body = token:match("^([^|]+)") or token
  local name = body:match("^([^#]+)") or body
  return name:match("^%s*(.-)%s*$")
end

-- Resolve a wikilink name to an absolute path.
local function resolve_name(name, cwd, file_dir)
  local candidates = {
    cwd .. "/" .. name .. ".md",
    file_dir .. "/" .. name .. ".md",
  }
  for _, abs in ipairs(candidates) do
    if vim.fn.filereadable(abs) == 1 then return abs end
  end
  local hits = vim.fn.glob(cwd .. "/**/" .. name .. ".md", false, true)
  if hits and #hits > 0 then return hits[1] end
  return nil
end

-- Collect all [[wikilinks]], fire all LSP definition requests in one go from the
-- source buffer, store resolved targets. Navigation becomes instant afterwards.
function M.collect()
  local cwd      = vim.fn.getcwd()
  local file_dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h")
  local src_buf  = vim.api.nvim_get_current_buf()
  local src_win  = vim.api.nvim_get_current_win()
  local lines    = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Build list of { abs, row, col } for each unique resolvable wikilink.
  local seen    = {}
  local pending = {}
  for lnum, line in ipairs(lines) do
    local search_from = 1
    while true do
      local ts, te, token = line:find("%[%[(.-)%]%]", search_from)
      if not ts then break end
      local name = token_to_name(token)
      if name and name ~= "" and not seen[token] then
        seen[token] = true
        local abs = resolve_name(name, cwd, file_dir)
        if abs then
          table.insert(pending, { abs = abs, row = lnum, col = ts - 1 })
        end
      end
      search_from = te + 1
    end
  end

  if #pending == 0 then
    vim.notify("Wikilink: no resolvable [[wikilinks]] found in buffer", vim.log.levels.WARN)
    return
  end

  -- Reset state.
  resolved  = {}
  idx       = 0
  _prev_buf = nil

  -- Fire one LSP definition request per entry from the source buffer.
  -- Each callback stores the resolved target; when all are done notify the user.
  local done    = 0
  local total   = #pending
  local saved_cursor = vim.api.nvim_win_get_cursor(src_win)

  for i, entry in ipairs(pending) do
    -- Move cursor to inside the [[token]] for this entry.
    vim.api.nvim_win_set_cursor(src_win, { entry.row, entry.col + 2 })

    vim.lsp.buf.definition({
      on_list = function(result)
        done = done + 1
        if result and result.items and #result.items > 0 then
          local item = result.items[1]
          -- Insert in order (not arrival order) by keeping slot i.
          resolved[i] = { filename = item.filename, lnum = item.lnum, col = math.max(0, item.col - 1) }
        end
        if done == total then
          -- Restore cursor and compact resolved (remove gaps from failed lookups).
          vim.api.nvim_win_set_cursor(src_win, saved_cursor)
          local compact = {}
          for _, r in ipairs(resolved) do
            if r then table.insert(compact, r) end
          end
          resolved = compact
          if #resolved == 0 then
            vim.notify("Wikilink: LSP could not resolve any links", vim.log.levels.WARN)
          else
            vim.notify(string.format("Wikilink: ready, %d/%d links resolved (Alt-Right/Left to navigate)", #resolved, total), vim.log.levels.INFO)
          end
        end
      end,
    })
  end
end

local function open_current()
  local r = resolved[idx]

  vim.cmd("edit " .. vim.fn.fnameescape(r.filename))
  local new_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_cursor(0, { r.lnum, r.col })
  vim.cmd("normal! zz")

  -- Delete the buffer that was displaced by this edit, provided it is:
  -- not the one we just opened, not already gone, not visible anywhere,
  -- not the source buffer, and listed (i.e. a real file buffer).
  if _prev_buf
    and _prev_buf ~= new_buf
    and vim.api.nvim_buf_is_valid(_prev_buf)
    and #vim.fn.win_findbuf(_prev_buf) == 0
    and vim.bo[_prev_buf].buflisted
  then
    vim.cmd("bdelete " .. _prev_buf)
  end

  _prev_buf = new_buf
end

function M.next()
  if #resolved == 0 then
    vim.notify("Wikilink: press Alt-s first", vim.log.levels.WARN)
    return
  end
  idx = (idx % #resolved) + 1
  open_current()
end

function M.prev()
  if #resolved == 0 then
    vim.notify("Wikilink: press Alt-s first", vim.log.levels.WARN)
    return
  end
  idx = ((idx - 2) % #resolved) + 1
  open_current()
end

function M.pick()
  if #resolved == 0 then
    vim.notify("Wikilink: press Alt-s first", vim.log.levels.WARN)
    return
  end

  local items = {}
  for i, r in ipairs(resolved) do
    table.insert(items, {
      text = vim.fn.fnamemodify(r.filename, ":t:r"),
      file = r.filename,
      _idx = i,
    })
  end

  require("snacks").picker({
    title   = "Wikilinks",
    items   = items,
    format  = function(item) return { { item.text } } end,
    preview = "file",
    confirm = function(picker, item)
      picker:close()
      if not item then return end
      idx = item._idx
      open_current()
    end,
  })
end

return M
