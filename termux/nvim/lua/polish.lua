-- This file is automatically loaded by lazy.nvim after all plugins
-- Use this file for any custom configurations that should run after plugins are loaded

-- Command to insert/overwrite a system reminder on the first line
local function jeerem_insert()
  -- check buffer writable
  if vim.bo.readonly or not vim.bo.modifiable then
    vim.notify("Buffer is not writable; cannot insert reminder", vim.log.levels.WARN)
    return
  end

  -- normalize today's date to midnight
  local now = os.time()
  local today_tm = os.date("*t", now)
  today_tm.hour = 0; today_tm.min = 0; today_tm.sec = 0
  local today_mid = os.time(today_tm)

  -- target date: April 2, 2026
  local target_tm = { year = 2026, month = 4, day = 2, hour = 0, min = 0, sec = 0 }
  local target_time = os.time(target_tm)

  local diff = target_time - today_mid
  local days = math.floor(math.abs(diff) / 86400)
  local rem_text
  -- pick a random smiley to prefix the text
local smileys = { "😊","🫠" ,"🫨" ,"😄", "🙂", "😁", "😃", "😅", "😎", "😉", "😂", "😍", "🥰", "🤩", "😘", "😋", "😜", "🤗", "😏", "😇" }
  math.randomseed(os.time())
  local s = smileys[math.random(#smileys)]
  if diff > 0 then
    rem_text = string.format("%s %d days left", s, days)
  elseif diff < 0 then
    rem_text = string.format("%s %d days since", s, days)
  else
    rem_text = string.format("%s 0 days left", s)
  end

  local insert_text = rem_text

  local bufnr = vim.api.nvim_get_current_buf()
  -- overwrite the first line (line 0..1)
  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { insert_text })
end

-- Create the :Jeerem command (Neovim requires commands to start with uppercase)
vim.api.nvim_create_user_command('Jeerem', function() jeerem_insert() end, { desc = 'Insert/overwrite system reminder on first line' })
-- Provide a command-line abbreviation so typing :jeerem will expand to :Jeerem
vim.cmd("cnoreabbrev jeerem Jeerem")

-- Return nil to keep module benign if required
return nil
