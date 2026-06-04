local M = {}

local function get_gallery_path()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local in_gallery = false
  local in_code = false
  local target_path = nil

  for _, line in ipairs(lines) do
    if line:match("^#%s*gallery") then
      in_gallery = true
    elseif in_gallery and line:match("^```img%-gallery") then
      in_code = true
    elseif in_code then
      local p = line:match("^path:%s*(.+)")
      if p then
        target_path = vim.trim(p)
        break
      elseif line:match("^```") then
        in_code = false
        in_gallery = false
      end
    end
  end
  return target_path
end

M.open_gallery = function()
  local target_path = get_gallery_path()

  if target_path then
    vim.fn.jobstart({ "nsxiv", target_path }, { detach = true })
    print("Opening nsxiv for: " .. target_path)
  else
    vim.notify("Gallery path not found", vim.log.levels.WARN)
  end
end

M.paste_image = function()
  local dir = get_gallery_path() or "Assets"
  
  -- Create directory if it doesn't exist
  vim.fn.mkdir(dir, "p")
  
  local timestamp = os.time()
  local filename = timestamp .. ".png"
  local filepath = dir .. "/" .. filename
  
  local is_wayland = os.getenv("WAYLAND_DISPLAY") ~= nil
  local cmd
  if is_wayland then
    cmd = string.format("wl-paste --type image/png > %s", vim.fn.shellescape(filepath))
  else
    cmd = string.format("xclip -selection clipboard -t image/png -o > %s", vim.fn.shellescape(filepath))
  end
  
  local result = os.execute(cmd)
  
  -- In Neovim 0.10+, os.execute returns the exit code directly or true/false, in 0.9 it returns status, exitcode, exitstatus
  -- We can just check if the file was created and is not empty to be completely safe
  local f = io.open(filepath, "r")
  if not f then
    vim.notify("Failed to paste image or clipboard does not contain an image", vim.log.levels.ERROR)
    return
  end
  local size = f:seek("end")
  f:close()
  
  if size == 0 then
    vim.fn.delete(filepath)
    vim.notify("Failed to paste image or clipboard does not contain an image", vim.log.levels.ERROR)
    return
  end
  
  local insert_text = string.format("![](%s)", filepath)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local current_line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
  
  local new_line = string.sub(current_line, 1, col) .. insert_text .. string.sub(current_line, col + 1)
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, {new_line})
  
  vim.api.nvim_win_set_cursor(0, {row, col + #insert_text})
end

return M
