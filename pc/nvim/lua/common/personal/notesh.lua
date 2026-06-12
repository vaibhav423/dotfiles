local M = {}

function M.create_note()
  local content = vim.fn.getline(1, "$")
  local text = table.concat(content, "\n")
  local escaped = text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
  local data = '["' .. escaped .. '"]'

  local cmd = {
    "curl", "-s",
    "https://notesh.ink/#create-note",
    "-X", "POST",
    "-H", "next-action: 6095a3eb80905147d76f6895a6634cf69788f0e021",
    "-H", "Content-Type: text/plain;charset=UTF-8",
    "--data-raw", data,
  }

  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("notesh: curl failed", vim.log.levels.ERROR)
    return
  end

  local slug = result:match('"slug":"([^"]+)"')
  if not slug then
    vim.notify("notesh: could not find slug in response", vim.log.levels.ERROR)
    return
  end

  local url = "https://notesh.ink/sh/" .. slug
  vim.fn.setreg("+", url)
  vim.notify("Copied: " .. url)
end

return M
