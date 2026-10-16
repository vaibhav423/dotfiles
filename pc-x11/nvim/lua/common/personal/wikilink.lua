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

-- Optimization: Build a file map of the vault once to avoid repeated recursive globs.
local function get_file_map(cwd)
  local map = {}
  local files = {}
  -- On Android/Termux, shell commands might be slower or limited.
  -- We try fd, then rg, then fallback to glob.
  if vim.fn.executable("fd") == 1 then
    files = vim.fn.systemlist("fd -e md . " .. vim.fn.shellescape(cwd))
  elseif vim.fn.executable("rg") == 1 then
    files = vim.fn.systemlist("rg --files -g '*.md' " .. vim.fn.shellescape(cwd))
  else
    files = vim.fn.glob(cwd .. "/**/*.md", false, true)
  end

  for _, f in ipairs(files) do
    local name = vim.fn.fnamemodify(f, ":t:r")
    if not map[name] then map[name] = f end
  end
  return map
end

-- Resolve a wikilink name to an absolute path using the pre-built file map.
local function resolve_name(name, cwd, file_dir, file_map)
  -- 1. Try local/relative
  local candidates = {
    cwd .. "/" .. name .. ".md",
    file_dir .. "/" .. name .. ".md",
  }
  for _, abs in ipairs(candidates) do
    if vim.fn.filereadable(abs) == 1 then return abs end
  end
  -- 2. Try map (fast global lookup)
  return file_map[name]
end

-- Collect all [[wikilinks]], fire all LSP definition requests in one go.
function M.collect()
  local cwd      = vim.fn.getcwd()
  local src_buf  = vim.api.nvim_get_current_buf()
  local file_name = vim.api.nvim_buf_get_name(src_buf)
  local file_dir = vim.fn.fnamemodify(file_name, ":p:h")
  local lines    = vim.api.nvim_buf_get_lines(src_buf, 0, -1, false)

  -- 1. Build file map once for the entire buffer.
  local file_map = get_file_map(cwd)

  -- 2. Build list of { abs, row, col } for each unique resolvable wikilink.
  local seen    = {}
  local pending = {}
  for lnum, line in ipairs(lines) do
    local search_from = 1
    while true do
      local ts, te, token = line:find("%[%[(.-)%]%]", search_from)
      if not ts then break end
      if not seen[token] then
        seen[token] = true
        local name = token_to_name(token)
        if name and name ~= "" then
          local abs = resolve_name(name, cwd, file_dir, file_map)
          if abs then
            table.insert(pending, { abs = abs, row = lnum, col = ts - 1, token = token })
          end
        end
      end
      search_from = te + 1
    end
  end

  if #pending == 0 then
    vim.notify("Wikilink: no resolvable [[wikilinks]] found", vim.log.levels.WARN)
    return
  end

  -- Reset state.
  resolved  = {}
  idx       = 0
  _prev_buf = nil

  -- 3. Fire LSP definition requests for each entry.
  -- We use client.request directly to avoid non-standard behavior of buf_request.
  local total_links = #pending
  local clients = vim.lsp.get_clients({ bufnr = src_buf, method = "textDocument/definition" })
  local total_requests = #clients * total_links
  local received_responses = 0

  local function finalize()
    local compact = {}
    for i = 1, total_links do
      if resolved[i] then table.insert(compact, resolved[i]) end
    end
    resolved = compact
    if #resolved == 0 then
      vim.notify("Wikilink: LSP could not resolve any links", vim.log.levels.WARN)
    else
      vim.notify(string.format("Wikilink: ready, %d/%d links resolved", #resolved, total_links), vim.log.levels.INFO)
    end
  end

  if total_requests == 0 then
    -- No LSP attached, use fast resolution results.
    for i, entry in ipairs(pending) do
      resolved[i] = { filename = entry.abs, lnum = 1, col = 0 }
    end
    finalize()
    return
  end

  for i, entry in ipairs(pending) do
    -- Set fallback from our fast resolution.
    resolved[i] = { filename = entry.abs, lnum = 1, col = 0 }

    local params = {
      textDocument = vim.lsp.util.make_text_document_params(src_buf),
      position = { line = entry.row - 1, character = entry.col + 2 }
    }

    for _, client in ipairs(clients) do
      client.request('textDocument/definition', params, function(err, result)
        received_responses = received_responses + 1
        if result and not err then
          local items = vim.lsp.util.locations_to_items(result, "utf-8")
          if items and #items > 0 then
            local item = items[1]
            resolved[i] = { filename = item.filename, lnum = item.lnum, col = math.max(0, item.col - 1) }
          end
        end
        if received_responses == total_requests then
          finalize()
        end
      end, src_buf)
    end
  end
end

local function open_current()
  local r = resolved[idx]
  if not r then return end

  vim.cmd("edit " .. vim.fn.fnameescape(r.filename))
  local new_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_cursor(0, { r.lnum, r.col })
  vim.cmd("normal! zz")

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
