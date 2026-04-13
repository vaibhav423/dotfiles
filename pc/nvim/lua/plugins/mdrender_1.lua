
return {
  "MeanderingProgrammer/render-markdown.nvim",
  opts = function()
    -- Store converter state in a global that persists
    if vim.g.markdown_latex_converter == nil then
      vim.g.markdown_latex_converter = 'utftex'
    end
    
    return {
      latex = {
        converter = vim.g.markdown_latex_converter,
      },
    }
  end,
  config = function(_, opts)
    local render_markdown = require('render-markdown')
    render_markdown.setup(opts)

    -- Toggle function that reloads plugin and buffers like you manually do
    local function toggle_converter()
      -- Toggle the global state
      local new_converter = (vim.g.markdown_latex_converter == 'latex2text') and 'utftex' or 'latex2text'
      vim.g.markdown_latex_converter = new_converter
      
      -- Collect all markdown buffers and their cursor positions
      local markdown_bufs = {}
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'markdown' then
          local wins = vim.fn.win_findbuf(buf)
          table.insert(markdown_bufs, {
            buf = buf,
            name = vim.api.nvim_buf_get_name(buf),
            wins = wins,
            cursor_pos = {}
          })
          -- Save cursor positions for each window showing this buffer
          for _, win in ipairs(wins) do
            markdown_bufs[#markdown_bufs].cursor_pos[win] = vim.api.nvim_win_get_cursor(win)
          end
        end
      end
      
      -- Reload the plugin via lazy.nvim (mimics :Lazy reload render-markdown.nvim)
      local lazy_ok, lazy = pcall(require, 'lazy')
      if lazy_ok then
        lazy.reload({ plugins = { 'render-markdown.nvim' } })
      end
      
      -- Re-edit all markdown buffers (mimics :e) after a short delay
      vim.schedule(function()
        for _, buf_info in ipairs(markdown_bufs) do
          local buf_name = buf_info.name
          
          if #buf_info.wins > 0 then
            -- Buffer is visible in windows - reload each window
            for _, win in ipairs(buf_info.wins) do
              vim.api.nvim_win_call(win, function()
                -- Force buffer reload
                vim.cmd('edit!')
                -- Restore cursor position
                if buf_info.cursor_pos[win] then
                  pcall(vim.api.nvim_win_set_cursor, win, buf_info.cursor_pos[win])
                end
              end)
            end
          else
            -- Buffer is hidden (not in any window) - unload and let it reload when opened
            if vim.api.nvim_buf_is_valid(buf_info.buf) then
              pcall(vim.api.nvim_buf_delete, buf_info.buf, { force = false, unload = true })
            end
          end
        end
        
        vim.notify('Markdown latex converter: ' .. new_converter .. ' (reload hidden buffers when opened)', vim.log.levels.INFO)
      end)
    end

    -- Keymap to toggle converter
    vim.keymap.set('n', '<leader>mt', toggle_converter, { desc = 'Toggle markdown latex converter', silent = true })
  end,
}
