-- lib/takephoto.lua
-- Inserts a markdown image link immediately, then launches the camera.
-- Camera saves to /sdcard/Documents/Fire/Assets/ (world-writable sdcard).
-- Boot script binds /sdcard/Documents/Fire -> Water/Fire so file appears in chroot.

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

  -- The camera runs in Android's rootfs where /home/fire/... doesn't exist.
  -- Translate the chroot path to its Android-visible sdcard equivalent so the
  -- camera can actually write to the pre-computed location.
  local android_path = abs_path:gsub("^/home/fire/Water/Fire", "/sdcard/Documents/Fire")

  -- Launch camera with the output URI pointing to our pre-computed path
  vim.fn.system(string.format(
    'am start -a android.media.action.IMAGE_CAPTURE --eu output "file://%s" com.motorola.camera3',
    android_path
  ))
end

local PICSART_DIR = "/sdcard/Pictures/Picsart"
local POLL_INTERVAL_MS = 2000
local POLL_MAX_TICKS   = 150  -- ~5 minutes

local CLIPIMG_JAVA = "/home/fire/Water/crap/scripts/clipimg.java"
local CLIPIMG_TMP = "/sdcard/tmp/clippaste"

-- Paste image from Android clipboard into the note's gallery dir.
-- droid runs Java on Android side to resolve the clipboard image URI and dump
-- bytes to /sdcard/tmp/clippaste.<ext>. We then move it into Assets/ and link it.
function M.pasteImage()
  local cwd = vim.fn.getcwd()
  local bufnr = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  -- Resolve destination directory (same as M.take)
  local rel_dir = find_section_path("gallery")
  if not rel_dir then
    rel_dir = "Assets"
  end
  local abs_dir = cwd .. "/" .. rel_dir
  vim.fn.mkdir(abs_dir, "p")

  -- Clean stale tmp files, then pull clipboard image via droid
  vim.fn.system(string.format("rm -f %s.*", vim.fn.shellescape(CLIPIMG_TMP)))
  local out = vim.fn.system(string.format("droid -f %s", vim.fn.shellescape(CLIPIMG_JAVA)))
  if vim.v.shell_error ~= 0 then
    vim.notify("PasteImage: droid failed\n" .. out, vim.log.levels.ERROR)
    return
  end

  local clipfile = out:match("FILE:(%S+)")
  if not clipfile then
    -- URI: fallback — droid can't open content:// streams as shell UID, but
    -- app FileProvider URIs map to real files root can read directly.
    local uri = out:match("URI:(%S+)")
    if uri then
      local fetch = vim.fn.system(string.format("clipimg-fetch %s",
        vim.fn.shellescape(uri)))
      if vim.v.shell_error == 0 then
        clipfile = fetch:match("FILE:(%S+)")
      else
        vim.notify("PasteImage: URI fetch failed\n" .. fetch, vim.log.levels.ERROR)
        return
      end
    end
  end
  if not clipfile then
    -- URL: fallback — browser copies carry <img src>, downloadable via curl
    local url = out:match("URL:(%S+)")
    if url then
      local url_ext = url:match("%.([^.?]+)%?") or url:match("%.([^.?]+)$") or "png"
      url_ext = url_ext:lower()
      if url_ext ~= "png" and url_ext ~= "jpg" and url_ext ~= "jpeg" and url_ext ~= "webp" and url_ext ~= "gif" then
        url_ext = "png"
      end
      local filename = tostring(os.time()) .. "." .. url_ext
      local abs_path = abs_dir .. "/" .. filename
      local dl = vim.fn.system(string.format("curl -sL --max-time 60 -o %s %s",
        vim.fn.shellescape(abs_path), vim.fn.shellescape(url)))
      if vim.v.shell_error ~= 0 or vim.fn.filereadable(abs_path) == 0 then
        vim.notify("PasteImage: download failed\n" .. dl, vim.log.levels.ERROR)
        return
      end
      vim.fn.system(string.format("chmod 644 %s", vim.fn.shellescape(abs_path)))
      local md_path = rel_dir .. "/" .. filename
      local alt = filename:gsub("%." .. url_ext .. "$", "")
      local link = "![" .. alt .. "](" .. md_path .. ")"
      local cur_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
      vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { cur_line .. link })
      vim.notify("PasteImage: downloaded → " .. md_path, vim.log.levels.INFO)
      return
    end
    if out:match("TEXT:") then
      vim.notify("PasteImage: clipboard holds text, not an image", vim.log.levels.WARN)
    else
      vim.notify("PasteImage: no image in clipboard\n" .. out, vim.log.levels.WARN)
    end
    return
  end

  -- Move into gallery dir with timestamp name (keep detected extension)
  local ext = clipfile:match("%.([^.]+)$") or "png"
  local filename = tostring(os.time()) .. "." .. ext
  local abs_path = abs_dir .. "/" .. filename
  local mv = vim.fn.system(string.format("mv -f %s %s",
    vim.fn.shellescape(clipfile), vim.fn.shellescape(abs_path)))
  if vim.v.shell_error ~= 0 then
    vim.notify("PasteImage: move failed\n" .. mv, vim.log.levels.ERROR)
    return
  end

  -- Clipboard images may arrive without other-read; fix like M.edit does
  vim.fn.system(string.format("chmod 644 %s", vim.fn.shellescape(abs_path)))

  -- Insert markdown link on current line
  local md_path = rel_dir .. "/" .. filename
  local alt = filename:gsub("%." .. ext .. "$", "")
  local link = "![" .. alt .. "](" .. md_path .. ")"
  local cur_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { cur_line .. link })
  vim.notify("PasteImage: pasted → " .. md_path, vim.log.levels.INFO)
end

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

  local android_abs = orig_abs:gsub("^/home/fire/Water/Fire", "/sdcard/Documents/Fire")
  vim.fn.system(string.format(
    'am start -a android.intent.action.EDIT -t "image/*" -d "file://%s"',
    android_abs
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

        -- Picsart saves as 0660 (no other-read). Fix so Android apps can open it.
        vim.fn.system(string.format("chmod 644 %s", vim.fn.shellescape(new_abs)))

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

function M.OpenImages(args)
  local cwd = vim.fn.getcwd()
  local lines = vim.api.nvim_buf_get_lines(0, args.line1 - 1, args.line2, false)

  local text = table.concat(lines, "\n")
  local seen = {}
  local paths = {}
  for path in text:gmatch("!%[.-%]%((.-)%)") do
    if not seen[path] then
      seen[path] = true
      table.insert(paths, path)
    end
  end

  if #paths == 0 then
    vim.notify("OpenImages: no image paths found in selection", vim.log.levels.WARN)
    return
  end

  local tmp_dir = "/sdcard/tmp"
  local abs_paths = {}
  for _, rel_or_abs in ipairs(paths) do
    local abs = rel_or_abs:sub(1, 1) == "/" and rel_or_abs or (cwd .. "/" .. rel_or_abs)
    if vim.fn.filereadable(abs) == 1 then
      table.insert(abs_paths, vim.fn.shellescape(abs))
    end
  end

  if #abs_paths == 0 then
    vim.notify("OpenImages: no readable files found", vim.log.levels.WARN)
    return
  end

  local cp_cmd = string.format(
    "mkdir -p %s && rm -rf %s/* && cp %s %s/",
    vim.fn.shellescape(tmp_dir),
    vim.fn.shellescape(tmp_dir),
    table.concat(abs_paths, " "),
    vim.fn.shellescape(tmp_dir)
  )
  vim.fn.system(cp_cmd)

  local intent_cmd = string.format(
    'am start -a android.intent.action.VIEW -d "file://%s" -t "resource/folder" com.mixplorer',
    tmp_dir
  )
  vim.fn.jobstart(intent_cmd)
  vim.notify(string.format("OpenImages: copied %d file(s) → %s", #abs_paths, tmp_dir), vim.log.levels.INFO)
end

function M.open_gallery()
  local rel_dir = find_section_path("gallery")
  if not rel_dir then
    vim.notify("No path: found under # gallery heading", vim.log.levels.WARN)
    return
  end

  local full_path = vim.fn.getcwd() .. "/" .. rel_dir:gsub("[\r\n%s]+$", "")

  local cmd = string.format(
    'am start -a android.intent.action.VIEW -d "file://%s" -t "resource/folder" -f 0x14000000 com.mixplorer',
    full_path
  )

  vim.notify("Opening: " .. full_path)
  vim.fn.jobstart(cmd)
end

return M
