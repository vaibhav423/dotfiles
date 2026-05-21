-- Transparent encryption/decryption for sensitive notes (.enc files)
-- Uses OpenSSL AES-256-CBC with PBKDF2. Decrypted content stays only in buffer.

local M = {}

-- Session password cache (cleared on nvim exit)
local password_cache = {}

-- Encryption settings (commands built as arrays for vim.system)

-- Prompt for password and cache it
local function prompt_password(bufnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  
  -- Check if password is already cached for this session
  if password_cache[filepath] then
    return password_cache[filepath]
  end
  
  -- Prompt for password (hidden input)
  vim.fn.inputsave()
  local password = vim.fn.inputsecret("Enter encryption password: ")
  vim.fn.inputrestore()
  
  if password == "" then
    vim.notify("Password cannot be empty", vim.log.levels.ERROR)
    return nil
  end
  
  -- Cache password for this session
  password_cache[filepath] = password
  return password
end

-- Clear cached password for current buffer
function M.clear_password()
  local filepath = vim.api.nvim_buf_get_name(0)
  password_cache[filepath] = nil
  vim.notify("Cached password cleared", vim.log.levels.INFO)
end

-- Decrypt buffer content from .enc file
function M.decrypt_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  
  -- Check if file exists
  if vim.fn.filereadable(filepath) == 0 then
    vim.notify("File does not exist: " .. filepath, vim.log.levels.ERROR)
    return false
  end
  
  -- Get password
  local password = prompt_password(bufnr)
  if not password then
    return false
  end
  
  -- Decrypt using OpenSSL (vim.system avoids blocking the event loop)
  local obj = vim.system({
    "openssl", "enc", "-d", "-aes-256-cbc", "-pbkdf2",
    "-iter", "100000", "-pass", "pass:" .. password, "-in", filepath,
  }, { text = true }):wait()

  if obj.code ~= 0 then
    vim.notify("Decryption failed. Wrong password or corrupted file.", vim.log.levels.ERROR)
    -- Clear the cached password since it's wrong
    password_cache[filepath] = nil
    return false
  end

  local result = obj.stdout or ""
  
  -- Load decrypted content into buffer
  local lines = {}
  for line in result:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  
  -- Handle empty files or files with single line
  if #lines == 0 and result ~= "" then
    lines = {result}
  end
  
  -- Set buffer content (this doesn't write to disk)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  
  -- Mark buffer as not modified (since we just loaded it)
  vim.bo[bufnr].modified = false

  vim.notify("File decrypted successfully", vim.log.levels.INFO)
  return true
end

-- Encrypt buffer content and write to .enc file
function M.encrypt_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  
  -- Get password from cache
  local password = password_cache[filepath]
  if not password then
    password = prompt_password(bufnr)
    if not password then
      return false
    end
  end
  
  -- Get buffer content
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")
  
  -- Encrypt using OpenSSL (vim.system avoids blocking the event loop)
  local obj = vim.system({
    "openssl", "enc", "-aes-256-cbc", "-pbkdf2",
    "-iter", "100000", "-salt", "-pass", "pass:" .. password, "-out", filepath,
  }, { stdin = content, text = true }):wait()

  if obj.code ~= 0 then
    vim.notify("Encryption failed: " .. (obj.stderr or ""), vim.log.levels.ERROR)
    return false
  end
  
  -- Mark buffer as not modified (we just saved it)
  vim.bo[bufnr].modified = false

  vim.notify("File encrypted and saved", vim.log.levels.INFO)
  return true
end

-- End of module (commands and autocmds are registered in config/commands.lua and config/autocmds.lua)
return M
