-- Markdown render helpers: toggle the latex converter used by render-markdown.nvim.
-- The converter state is stored in vim.g.markdown_latex_converter so it persists
-- across plugin reloads within a session.

local M = {}

function M.toggle_converter()
  local new_converter = (vim.g.markdown_latex_converter == "latex2text") and "utftex" or "latex2text"
  vim.g.markdown_latex_converter = new_converter

  -- Collect all markdown buffers and their cursor positions before reloading
  local markdown_bufs = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "markdown" then
      local wins = vim.fn.win_findbuf(buf)
      table.insert(markdown_bufs, {
        buf = buf,
        wins = wins,
        cursor_pos = {},
      })
      for _, win in ipairs(wins) do
        markdown_bufs[#markdown_bufs].cursor_pos[win] = vim.api.nvim_win_get_cursor(win)
      end
    end
  end

  -- Reload the plugin via lazy.nvim (mimics :Lazy reload render-markdown.nvim)
  local lazy_ok, lazy = pcall(require, "lazy")
  if lazy_ok then
    lazy.reload({ plugins = { "render-markdown.nvim" } })
  end

  -- Re-edit all markdown buffers after a short delay to pick up the new converter
  vim.schedule(function()
    for _, buf_info in ipairs(markdown_bufs) do
      if #buf_info.wins > 0 then
        -- Buffer is visible — reload each window and restore cursor
        for _, win in ipairs(buf_info.wins) do
          vim.api.nvim_win_call(win, function()
            vim.cmd("edit!")
            if buf_info.cursor_pos[win] then
              pcall(vim.api.nvim_win_set_cursor, win, buf_info.cursor_pos[win])
            end
          end)
        end
      else
        -- Buffer is hidden — unload so it picks up the new converter when reopened
        if vim.api.nvim_buf_is_valid(buf_info.buf) then
          pcall(vim.api.nvim_buf_delete, buf_info.buf, { force = false, unload = true })
        end
      end
    end

    vim.notify(
      "Markdown latex converter: " .. new_converter .. " (reload hidden buffers when opened)",
      vim.log.levels.INFO
    )
  end)
end

return M
