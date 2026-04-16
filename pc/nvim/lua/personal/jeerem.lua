-- Jeerem: insert a date-countdown reminder on the first line of the current buffer.
-- Target date: April 2, 2026

local M = {}

local smileys = {
  "😊", "🫠", "🫨", "😄", "🙂", "😁", "😃", "😅", "😎",
  "😉", "😂", "😍", "🥰", "🤩", "😘", "😋", "😜", "🤗", "😏", "😇",
}

function M.insert()
  if vim.bo.readonly or not vim.bo.modifiable then
    vim.notify("Buffer is not writable; cannot insert reminder", vim.log.levels.WARN)
    return
  end

  local now = os.time()
  local today_tm = os.date("*t", now)
  today_tm.hour = 0; today_tm.min = 0; today_tm.sec = 0
  local today_mid = os.time(today_tm)

  local target_time = os.time({ year = 2026, month = 5, day = 17, hour = 0, min = 0, sec = 0 })
  local diff = target_time - today_mid
  local days = math.floor(math.abs(diff) / 86400)

  math.randomseed(os.time())
  local s = smileys[math.random(#smileys)]

  local text
  if diff > 0 then
    text = string.format("%s %d days left", s, days)
  elseif diff < 0 then
    text = string.format("%s %d days since", s, days)
  else
    text = string.format("%s 0 days left", s)
  end

  vim.api.nvim_buf_set_lines(0, 0, 1, false, { text })
end

return M
