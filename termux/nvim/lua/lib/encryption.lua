-- Transparent encryption/decryption for sensitive notes (.enc files)
-- Uses OpenSSL AES-256-CBC with PBKDF2. Decrypted content stays only in buffer.

local M = {}

-- Session password cache (cleared on nvim exit)
local password_cache = {}

-- Encryption settings
local ENCRYPTION_CMD = "openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -pass pass:%s"
local DECRYPTION_CMD = "openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -pass pass:%s"

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
  
  -- Escape password for shell (basic escaping, consider more robust solution for production)
  local escaped_password = password:gsub("'", "'\\''")
  
  -- Decrypt using OpenSSL
  local decrypt_cmd = string.format(DECRYPTION_CMD, escaped_password) .. " -in '" .. filepath .. "'"
  local handle = io.popen(decrypt_cmd .. " 2>&1")
  
  if not handle then
    vim.notify("Failed to run decryption command", vim.log.levels.ERROR)
    return false
  end
  
  local result = handle:read("*a")
  local success = handle:close()
  
  if not success then
    vim.notify("Decryption failed. Wrong password or corrupted file.", vim.log.levels.ERROR)
    -- Clear the cached password since it's wrong
    password_cache[filepath] = nil
    return false
  end
  
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
  vim.api.nvim_buf_set_option(bufnr, "modified", false)
  
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
  
  -- Escape password for shell
  local escaped_password = password:gsub("'", "'\\''")
  
  -- Encrypt using OpenSSL
  local encrypt_cmd = string.format(ENCRYPTION_CMD, escaped_password) .. " -out '" .. filepath .. "'"
  local handle = io.popen(encrypt_cmd .. " 2>&1", "w")
  
  if not handle then
    vim.notify("Failed to run encryption command", vim.log.levels.ERROR)
    return false
  end
  
  handle:write(content)
  local success = handle:close()
  
  if not success then
    vim.notify("Encryption failed", vim.log.levels.ERROR)
    return false
  end
  
  -- Mark buffer as not modified (we just saved it)
  vim.api.nvim_buf_set_option(bufnr, "modified", false)
  
  vim.notify("File encrypted and saved", vim.log.levels.INFO)
  return true
end

-- Setup function to register autocommands and commands
function M.setup()
  -- Create autocommands for .enc files
  local augroup = vim.api.nvim_create_augroup("EncryptionPlugin", { clear = true })
  
  -- Auto-decrypt when opening .enc files
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = augroup,
    pattern = "*.enc",
    callback = function()
      -- Disable swap files for encrypted files
      vim.opt_local.swapfile = false
      vim.opt_local.backup = false
      vim.opt_local.writebackup = false
      vim.opt_local.undofile = false
      
      -- Decrypt the file
      M.decrypt_buffer()
    end,
  })
  
  -- Auto-encrypt when writing .enc files
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = augroup,
    pattern = "*.enc",
    callback = function()
      M.encrypt_buffer()
    end,
  })
  
  -- Clear password cache when buffer is closed
  vim.api.nvim_create_autocmd("BufDelete", {
    group = augroup,
    pattern = "*.enc",
    callback = function()
      local filepath = vim.api.nvim_buf_get_name(0)
      password_cache[filepath] = nil
    end,
  })
  
  -- User commands
  vim.api.nvim_create_user_command("EncryptBuffer", function()
    M.encrypt_buffer()
  end, { desc = "Encrypt current buffer to .enc file" })
  
  vim.api.nvim_create_user_command("DecryptBuffer", function()
    M.decrypt_buffer()
  end, { desc = "Decrypt current .enc file into buffer" })
  
  vim.api.nvim_create_user_command("ClearEncryptionPassword", function()
    M.clear_password()
  end, { desc = "Clear cached encryption password" })
end

return M
