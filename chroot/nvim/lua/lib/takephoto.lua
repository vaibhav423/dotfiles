-- lib/takephoto.lua
-- Inserts a markdown image link immediately, then launches the camera.
-- The camera must save to the exact path we pre-computed (via --eu output).

local M = {}

-- Scan buffer for `path:` under a given heading (case-insensitive)
local function find_section_path(heading_pattern)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local in_section = false
  for _, line in ipairs(lines) do
    if line:lower():match("^#+%s+" .. heading_pattern .. "%s*$") then
      in_section = true
    elseif in_section then
      if line:match("^#+%s+") then break end
      local p = line:match("^%s*path:%s*(.+)%s*$")
      if p then return p end
    end
  end
  return nil
end

function M.take()
  local cwd = vim.fn.getcwd()
  local bufnr = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  -- Resolve destination directory
  local rel_dir = find_section_path("gallery")
  if not rel_dir then
    rel_dir = "Assets"
  end
  local abs_dir = cwd .. "/" .. rel_dir
  vim.fn.mkdir(abs_dir, "p")

  -- Pre-compute filename from current timestamp
  local filename = tostring(os.time()) .. ".jpg"
  local abs_path = abs_dir .. "/" .. filename
  local md_path  = rel_dir .. "/" .. filename
  local alt      = filename:gsub("%.jpg$", "")
  local link     = "![" .. alt .. "](" .. md_path .. ")"

  -- Insert the link immediately on the current line
  local cur_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { cur_line .. link })

  -- Launch camera with the output URI pointing to our pre-computed path
  vim.fn.system(string.format(
    'am start -a android.media.action.IMAGE_CAPTURE --eu output "file://%s" com.motorola.camera3',
    abs_path
  ))
end

local PICSART_DIR = "/sdcard/Pictures/Picsart"
local POLL_INTERVAL_MS = 2000
local POLL_MAX_TICKS   = 150  -- ~5 minutes

function M.edit()
  local cwd = vim.fn.getcwd()
  local bufnr = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  -- Use the same URL extraction gx uses
  local urls = require("vim.ui")._get_urls()
  local rel_or_abs = urls and urls[1]
  if not rel_or_abs or rel_or_abs == "" then
    vim.notify("EditPhoto: no path found under cursor", vim.log.levels.WARN)
    return
  end

  -- Resolve to absolute
  local orig_abs
  if rel_or_abs:sub(1, 1) == "/" then
    orig_abs = rel_or_abs
  else
    orig_abs = cwd .. "/" .. rel_or_abs
  end

  if vim.fn.filereadable(orig_abs) == 0 then
    vim.notify("EditPhoto: file not readable:\n" .. orig_abs, vim.log.levels.ERROR)
    return
  end

  -- Destination dir = same dir as the original file
  local abs_dir = vim.fn.fnamemodify(orig_abs, ":h")
  local rel_dir = vim.fn.fnamemodify(rel_or_abs, ":h")  -- for updating the md link

  local launch_time = os.time()

  vim.notify("Opening photo editor…", vim.log.levels.INFO)

  vim.fn.system(string.format(
    'am start -a android.intent.action.EDIT -t "image/*" -d "file://%s"',
    orig_abs
  ))

  -- Poll Picsart dir for a new file with mtime > launch_time
  local ticks = 0
  local timer = vim.uv.new_timer()

  timer:start(POLL_INTERVAL_MS, POLL_INTERVAL_MS, function()
    ticks = ticks + 1

    vim.schedule(function()
      -- Use getftime() to find files newer than launch_time
      local files = vim.fn.glob(PICSART_DIR .. "/*.jpg", false, true)
      vim.list_extend(files, vim.fn.glob(PICSART_DIR .. "/*.png", false, true))
      vim.list_extend(files, vim.fn.glob(PICSART_DIR .. "/*.JPG", false, true))
      vim.list_extend(files, vim.fn.glob(PICSART_DIR .. "/*.PNG", false, true))
      local found = nil
      for _, f in ipairs(files) do
        local mtime = vim.fn.getftime(f)
        if mtime >= launch_time then
          if not found or vim.fn.getftime(f) > vim.fn.getftime(found) then
            found = f
          end
        end
      end

      if found then
        timer:stop()
        timer:close()

        -- Generate a new filename to avoid image viewer caching issues
        -- We append a timestamp so Neovim/markdown viewer sees a text change and reloads
        local old_filename = vim.fn.fnamemodify(orig_abs, ":t")
        local name_noext = vim.fn.fnamemodify(orig_abs, ":t:r")
        local ext = vim.fn.fnamemodify(found, ":e")
        if ext == "" then ext = vim.fn.fnamemodify(orig_abs, ":e") end
        
        -- Strip previous _edit_ suffixes if editing an already edited photo
        name_noext = name_noext:gsub("_edit_%d+$", "")
        local new_filename = name_noext .. "_edit_" .. tostring(os.time()) .. "." .. ext
        local new_abs = abs_dir .. "/" .. new_filename

        -- Move new file to destination
        local mv = vim.fn.system(string.format("mv -f %s %s",
          vim.fn.shellescape(found), vim.fn.shellescape(new_abs)))
        if vim.v.shell_error ~= 0 then
          vim.notify("EditPhoto: move failed\n" .. mv, vim.log.levels.ERROR)
          return
        end

        -- Delete original unedited file
        if orig_abs ~= new_abs and vim.fn.filereadable(orig_abs) == 1 then
          vim.fn.delete(orig_abs)
        end

        -- Update the markdown link safely (user might have added/removed lines)
        if vim.api.nvim_buf_is_valid(bufnr) then
          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
          for i, line in ipairs(lines) do
            if line:find(vim.pesc(old_filename)) then
              local new_line = line:gsub(vim.pesc(old_filename), new_filename, 1)
              vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { new_line })
              break -- Assuming only one occurrence needs to be updated or update all? Usually one per cursor action.
            end
          end
        end

        vim.notify("EditPhoto: updated → " .. rel_dir .. "/" .. new_filename, vim.log.levels.INFO)

      elseif ticks >= POLL_MAX_TICKS then
        timer:stop()
        timer:close()
        vim.notify("EditPhoto: timed out waiting for Picsart output", vim.log.levels.WARN)
      end
    end)
  end)
end

return M
