-- lib/ytframe.lua
-- Capture a video frame from a YouTube URL and replace it with:
--   ![<chapter>](path) [link](url)
-- Chapter name is looked up from yt-dlp chapter metadata using the ?t= timestamp.
-- If no chapter is found the alt is left empty and cursor lands inside [] (normal mode).
-- ffmpeg runs in the background after the line is already written.
--
-- Two entry points:
--
--   M.capture_normal()  — normal mode: auto-detects the first URL on the current
--                         line, replaces it, cursor inside [] if no chapter found.
--
--   M.capture_visual()  — visual mode: replaces every URL found in the selected
--                         line range, no cursor repositioning.
--
-- URL pattern matched: anything starting with http:// or https://
-- Timestamp parsed from ?t= param: 7m28s | 1h7m28s | 7m | 28s | 448 (raw secs)

local M = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Scan buffer for `path:` under a given heading (same as takephoto.lua).
local function find_section_path(heading_pattern)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local in_section = false
  for _, line in ipairs(lines) do
    if line:lower():match("^#%s+" .. heading_pattern .. "%s*$") then
      in_section = true
    elseif in_section then
      if line:match("^#%s+") then break end
      local p = line:match("^%s*path:%s*(.+)%s*$")
      if p then return p end
    end
  end
  return nil
end

--- Parse a ?t= value → total seconds (number).
local function t_param_to_secs(t_str)
  if not t_str or t_str == "" then return nil end
  local h = tonumber(t_str:match("(%d+)h") or "0") or 0
  local m = tonumber(t_str:match("(%d+)m") or "0") or 0
  local s = tonumber(t_str:match("(%d+)s") or "0") or 0
  if t_str:match("[hms]") then
    return h * 3600 + m * 60 + s
  end
  return tonumber(t_str)
end

--- Convert total seconds → ffmpeg -ss string.
local function secs_to_ffmpeg(secs)
  if not secs then return nil end
  local hh = math.floor(secs / 3600)
  local mm = math.floor((secs % 3600) / 60)
  local ss = secs % 60
  return hh > 0 and string.format("%02d:%02d:%02d", hh, mm, ss)
                 or string.format("%02d:%02d", mm, ss)
end

--- Strip ?t= / &t= so yt-dlp gets a clean URL.
local function strip_timestamp(url)
  url = url:gsub("#.*$", "")
  url = url:gsub("[?&]t=[^&]*", "")
  url = url:gsub("[?&]$", "")
  return url
end

--- Extract the ?t= value string from a URL.
local function extract_t_param(url)
  return url:match("[?&]t=([^&#]+)")
end

--- Find the first http(s) URL in a string.
--- Returns: url, byte_start (1-indexed), byte_end (1-indexed, inclusive)
local function find_url_in_line(line)
  local s, e = line:find("https?://[^%s]+")
  if not s then return nil end
  local url = line:sub(s, e):gsub("[.,;:!?)\"']+$", "")
  e = s + #url - 1
  return url, s, e
end

--- Parse the Python-repr chapters output from yt-dlp --print "chapters".
--- Returns a list of { start_time, end_time, title }.
local function parse_chapters(raw)
  local chapters = {}
  -- Each dict: {'start_time': N, 'title': '...', 'end_time': N}
  -- Use repeated pattern matching to extract each entry.
  for entry in raw:gmatch("{(.-)%s*}") do
    local start_time = tonumber(entry:match("'start_time'%s*:%s*([%d%.]+)"))
    local end_time   = tonumber(entry:match("'end_time'%s*:%s*([%d%.]+)"))
    -- Title may contain single quotes (e.g. "It's alive").
    -- Greedy-match up to the LAST ', 'end_time' so embedded apostrophes are kept.
    local title = entry:match("'title'%s*:%s*'(.+)'%s*,?%s*'end_time'")
    if start_time and title then
      table.insert(chapters, { start_time = start_time, end_time = end_time, title = title })
    end
  end
  return chapters
end

--- Find the chapter title for a given timestamp in seconds.
--- Returns the title string or nil.
local function chapter_at(chapters, secs)
  if not secs or #chapters == 0 then return nil end
  for _, ch in ipairs(chapters) do
    local finish = ch.end_time or math.huge
    if secs >= ch.start_time and secs < finish then
      return ch.title
    end
  end
  -- Fallback: last chapter (video end timestamp)
  return chapters[#chapters].title
end

--- Resolve output dir, return (abs_path, md_path).
--- _seq avoids filename collisions within the same call.
local _seq = 0
local function new_output_path(cwd)
  _seq = _seq + 1
  local rel_dir = find_section_path("gallery") or "Assets"
  local abs_dir = cwd .. "/" .. rel_dir
  vim.fn.mkdir(abs_dir, "p")
  local filename = tostring(os.time()) .. (_seq > 1 and ("_" .. _seq) or "") .. ".jpg"
  return abs_dir .. "/" .. filename, rel_dir .. "/" .. filename
end

--- Fire yt-dlp (stream URL) → ffmpeg for one URL/path pair.
local function run_ffmpeg_pipeline(url, abs_path, md_path)
  local t_param   = extract_t_param(url)
  local ts        = secs_to_ffmpeg(t_param_to_secs(t_param))
  local clean_url = strip_timestamp(url)

  vim.system({ "yt-dlp", "-f", "bestvideo", "-g", clean_url }, { text = true }, function(yt)
    vim.schedule(function()
      if yt.code ~= 0 then
        vim.notify("YtFrame: yt-dlp failed\n" .. (yt.stderr or ""), vim.log.levels.ERROR)
        return
      end
      local stream = yt.stdout:match("^%s*(.-)%s*$")
      if not stream or stream == "" then
        vim.notify("YtFrame: yt-dlp returned empty stream URL", vim.log.levels.ERROR)
        return
      end
      local cmd = ts
        and { "ffmpeg", "-ss", ts, "-i", stream, "-frames:v", "1", "-q:v", "2", "-y", abs_path }
        or  { "ffmpeg", "-i", stream, "-frames:v", "1", "-q:v", "2", "-y", abs_path }
      vim.notify("YtFrame: capturing" .. (ts and (" at " .. ts) or "") .. " → " .. md_path, vim.log.levels.INFO)
      vim.system(cmd, { text = true }, function(ff)
        vim.schedule(function()
          if ff.code ~= 0 then
            vim.notify("YtFrame: ffmpeg failed\n" .. (ff.stderr or ""), vim.log.levels.ERROR)
            return
          end
          if vim.fn.filereadable(abs_path) == 0 then
            vim.notify("YtFrame: output not found: " .. abs_path, vim.log.levels.ERROR)
            return
          end
          vim.notify("YtFrame: saved → " .. md_path, vim.log.levels.INFO)
        end)
      end)
    end)
  end)
end

--- Core: fetch chapter name for url, then call on_done(chapter_title_or_nil).
--- chapter_title is nil if the video has no chapters or ?t= is missing.
local function fetch_chapter(url, on_done)
  local t_param = extract_t_param(url)
  local secs    = t_param_to_secs(t_param)
  local clean_url = strip_timestamp(url)

  if not secs then
    on_done(nil)
    return
  end

  vim.system(
    { "yt-dlp", "--print", "chapters", clean_url },
    { text = true },
    function(res)
      vim.schedule(function()
        if res.code ~= 0 or not res.stdout or res.stdout:match("^%s*$") then
          on_done(nil)
          return
        end
        local chapters = parse_chapters(res.stdout)
        on_done(chapter_at(chapters, secs))
      end)
    end
  )
end

-- ---------------------------------------------------------------------------
-- M.capture_normal  — detect URL on current line, replace, cursor in []
-- ---------------------------------------------------------------------------

function M.capture_normal()
  _seq = 0
  local cwd   = vim.fn.getcwd()
  local bufnr = vim.api.nvim_get_current_buf()
  local row   = vim.api.nvim_win_get_cursor(0)[1] - 1
  local line  = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]

  local url, s, e = find_url_in_line(line)
  if not url then
    vim.notify("YtFrame: no URL found on current line", vim.log.levels.WARN)
    return
  end

  local abs_path, md_path = new_output_path(cwd)

  vim.notify("YtFrame: fetching chapter info…", vim.log.levels.INFO)

  fetch_chapter(url, function(chapter)
    -- Reread line in case buffer changed while we were waiting
    local cur_line   = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    local alt        = chapter or ""
    local replacement = "![" .. alt .. "](" .. md_path .. ") [link](" .. url .. ")"
    local new_line   = cur_line:sub(1, s - 1) .. replacement .. cur_line:sub(e + 1)
    vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })

    if chapter then
      -- Chapter found — leave in normal mode, cursor after the closing )
      local after_col = s - 1 + #replacement  -- 0-indexed col right after replacement
      vim.api.nvim_win_set_cursor(0, { row + 1, after_col })
    else
      -- No chapter — cursor inside ![|], enter insert mode
      vim.api.nvim_win_set_cursor(0, { row + 1, s - 1 + 2 })
      vim.cmd("startinsert")
    end

    run_ffmpeg_pipeline(url, abs_path, md_path)
  end)
end

-- ---------------------------------------------------------------------------
-- M.capture_visual  — replace every URL found in the selected line range
-- ---------------------------------------------------------------------------

function M.capture_visual()
  _seq = 0
  local cwd   = vim.fn.getcwd()
  local bufnr = vim.api.nvim_get_current_buf()

  local start_row = vim.api.nvim_buf_get_mark(bufnr, "<")[1] - 1
  local end_row   = vim.api.nvim_buf_get_mark(bufnr, ">")[1] - 1

  -- Collect all (row, url, s, e, abs_path, md_path) upfront before any rewriting.
  local jobs = {}
  for row = start_row, end_row do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    local url, s, e = find_url_in_line(line)
    if url then
      local abs_path, md_path = new_output_path(cwd)
      table.insert(jobs, { row = row, url = url, s = s, e = e,
                            abs_path = abs_path, md_path = md_path })
    end
  end

  if #jobs == 0 then
    vim.notify("YtFrame: no URLs found in selection", vim.log.levels.WARN)
    return
  end

  vim.notify("YtFrame: fetching chapter info for " .. #jobs .. " URL(s)…", vim.log.levels.INFO)

  -- For each job: fetch chapter async, then write line and fire ffmpeg.
  -- Process jobs bottom-to-top in the write step so row indices stay valid.
  -- Since fetches are all concurrent we use a counter to track completion,
  -- then sort and write all at once.
  local results  = {}  -- filled as each fetch completes: { job, chapter }
  local done     = 0

  local function try_write_all()
    done = done + 1
    if done < #jobs then return end
    -- All chapter fetches complete — write bottom-to-top
    table.sort(results, function(a, b) return a.job.row > b.job.row end)
    for _, r in ipairs(results) do
      local j       = r.job
      local alt     = r.chapter or ""
      local cur_line = vim.api.nvim_buf_get_lines(bufnr, j.row, j.row + 1, false)[1]
      local replacement = "![" .. alt .. "](" .. j.md_path .. ") [link](" .. j.url .. ")"
      local new_line    = cur_line:sub(1, j.s - 1) .. replacement .. cur_line:sub(j.e + 1)
      vim.api.nvim_buf_set_lines(bufnr, j.row, j.row + 1, false, { new_line })
      run_ffmpeg_pipeline(j.url, j.abs_path, j.md_path)
    end
    vim.notify("YtFrame: queued " .. #jobs .. " URL(s)", vim.log.levels.INFO)
  end

  for _, job in ipairs(jobs) do
    local j = job  -- capture for closure
    fetch_chapter(j.url, function(chapter)
      table.insert(results, { job = j, chapter = chapter })
      try_write_all()
    end)
  end
end

return M
