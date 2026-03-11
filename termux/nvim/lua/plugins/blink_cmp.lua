return {
  "Saghen/blink.cmp",
  optional = true,
  opts = function(_, opts)
    opts = opts or {}

    -- Helper: is the cursor currently inside an unclosed [[
    local function inside_wikilink()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local line   = vim.api.nvim_buf_get_lines(0, cursor[1] - 1, cursor[1], false)[1] or ""
      return line:sub(1, cursor[2]):match("%[%[[^%]]*$") ~= nil
    end

    -- 1. Suppress snippets/buffer/path inside [[...]].
    local function not_in_wikilink(ctx, _items)
      if not ctx or not ctx.cursor or not ctx.line then return true end
      return ctx.line:sub(1, ctx.cursor[2]):match("%[%[[^%]]*$") == nil
    end

    opts.sources = opts.sources or {}
    opts.sources.providers = opts.sources.providers or {}

    opts.sources.providers.snippets = opts.sources.providers.snippets or {}
    opts.sources.providers.snippets.should_show_items = not_in_wikilink

    opts.sources.providers.buffer = opts.sources.providers.buffer or {}
    opts.sources.providers.buffer.should_show_items = not_in_wikilink

    opts.sources.providers.path = opts.sources.providers.path or {}
    opts.sources.providers.path.should_show_items = not_in_wikilink

    -- 2. Sorting.
    --    Inside [[...]]: markdown-oxide stores its nucleo score in sortText (as a
    --    numeric string). We want higher nucleo score = better rank.
    --    Blink's built-in sort_text does ascending string compare, which breaks for
    --    numbers of different digit lengths ("9" > "10000").
    --    So: use a custom sort function that, inside [[]], compares sortText numerically
    --    (descending = higher score first), and falls back to blink's score sort outside.
    --
    --    Note: item.score is written by blink AFTER transform_items, so we cannot use it
    --    to carry markdown-oxide's rank. sortText is the only safe carrier.
    local function wikilink_sort(a, b)
      if not inside_wikilink() then return nil end -- defer to next sort fn
      local sa = tonumber(a.sortText)
      local sb = tonumber(b.sortText)
      if sa == nil and sb == nil then return nil end
      if sa == nil then return false end
      if sb == nil then return true end
      if sa ~= sb then return sa > sb end  -- higher nucleo score = better
      return nil
    end

    opts.fuzzy = opts.fuzzy or {}
    opts.fuzzy.sorts         = { wikilink_sort, "score", "sort_text" }
    opts.fuzzy.use_proximity = false

    -- Keep snippet score offset for non-wikilink contexts.
    if not opts.snippets then opts.snippets = {} end
    opts.snippets.score_offset = 5
  end,
}
