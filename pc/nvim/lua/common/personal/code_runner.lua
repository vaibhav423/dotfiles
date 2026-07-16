local M = {}

-- Define paths for I/O
local io_dir = vim.fn.stdpath("data") .. "/code_runner"
vim.fn.mkdir(io_dir, "p")
M.input_file = io_dir .. "/input.txt"
M.output_file = io_dir .. "/output.txt"

-- Ensure I/O files exist
if vim.fn.filereadable(M.input_file) == 0 then
  vim.fn.writefile({""}, M.input_file)
end
if vim.fn.filereadable(M.output_file) == 0 then
  vim.fn.writefile({""}, M.output_file)
end

-- Define how to compile and format the run command.
-- This now returns the full command string that will read from stdin.
M.runners = {
  cpp = function(file, out_file)
    return string.format("g++ -std=c++17 -O2 -Wall '%s' -o '%s' && '%s'", file, out_file, out_file)
  end,
  c = function(file, out_file)
    return string.format("gcc -O2 -Wall '%s' -o '%s' && '%s'", file, out_file, out_file)
  end,
  python = function(file, _)
    return string.format("python3 '%s'", file)
  end,
  sh = function(file, _)
    return string.format("bash '%s'", file)
  end,
  javascript = function(file, _)
    return string.format("node '%s'", file)
  end,
  rust = function(file, out_file)
    return string.format("rustc '%s' -o '%s' && '%s'", file, out_file, out_file)
  end,
  go = function(file, _)
    return string.format("go run '%s'", file)
  end,
}

M.extension_map = {
  py = "python",
  js = "javascript",
  cc = "cpp",
  cxx = "cpp",
  rs = "rust",
}

-- Helper to find a window displaying a specific file
local function get_win_by_bufname(name)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buf_name = vim.api.nvim_buf_get_name(buf)
    if buf_name == name then
      return win
    end
  end
  return nil
end

-- Ensure I/O files stay unlisted from the bufferline forever
vim.api.nvim_create_autocmd({"BufAdd", "BufRead", "BufEnter"}, {
  pattern = { "*/code_runner/input.txt", "*/code_runner/output.txt" },
  callback = function(args)
    vim.bo[args.buf].buflisted = false
    vim.bo[args.buf].swapfile = false
  end
})

-- Helper to set buffer options to hide them from the bufferline/tabline
local function hide_buf(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.bo[buf].buflisted = false
    vim.bo[buf].swapfile = false
  end
end

-- Sets up the 3-pane UI layout (Code | Input / Output)
function M.setup_layout()
  local input_win = get_win_by_bufname(M.input_file)
  local output_win = get_win_by_bufname(M.output_file)

  if not input_win and not output_win then
    vim.cmd("botright vsplit " .. M.input_file)
    input_win = vim.api.nvim_get_current_win()
    vim.cmd("split " .. M.output_file)
    output_win = vim.api.nvim_get_current_win()
    vim.cmd("wincmd h") -- Return to code
  elseif not output_win then
    vim.api.nvim_set_current_win(input_win)
    vim.cmd("split " .. M.output_file)
    output_win = vim.api.nvim_get_current_win()
    vim.cmd("wincmd h")
  elseif not input_win then
    vim.api.nvim_set_current_win(output_win)
    vim.cmd("split " .. M.input_file)
    input_win = vim.api.nvim_get_current_win()
    vim.cmd("wincmd h")
  end
  
  -- Hide both buffers from the tabline
  if input_win then
    hide_buf(vim.api.nvim_win_get_buf(input_win))
  end
  if output_win then
    hide_buf(vim.api.nvim_win_get_buf(output_win))
    -- Auto reload when file changes
    vim.bo[vim.api.nvim_win_get_buf(output_win)].autoread = true
  end
end

-- Closes the I/O layout panes
function M.close_layout()
  local input_win = get_win_by_bufname(M.input_file)
  local output_win = get_win_by_bufname(M.output_file)
  if input_win then vim.api.nvim_win_close(input_win, true) end
  if output_win then vim.api.nvim_win_close(output_win, true) end
end

-- Toggle the layout visibility
function M.toggle_layout()
  local input_win = get_win_by_bufname(M.input_file)
  local output_win = get_win_by_bufname(M.output_file)
  
  if input_win or output_win then
    M.close_layout()
  else
    M.setup_layout()
  end
end

-- Main function to run the code
function M.run()
  local file = vim.fn.expand("%:p")
  local name = vim.fn.expand("%:t:r")
  local ext = vim.fn.expand("%:e")
  local filetype = vim.bo.filetype

  if file == "" or file == M.input_file or file == M.output_file then
    -- If we are in the input/output buffer, switch to the code buffer to run
    vim.cmd("wincmd h")
    file = vim.fn.expand("%:p")
    if file == "" then
      vim.notify("No code file to run", vim.log.levels.ERROR, { title = "Code Runner" })
      return
    end
  end

  local lang = filetype
  if not lang or lang == "" or not M.runners[lang] then
    lang = M.extension_map[ext] or ext
  end

  local runner_func = M.runners[lang]
  if not runner_func then
    vim.notify("No runner configured for: " .. (lang or "unknown"), vim.log.levels.ERROR, { title = "Code Runner" })
    return
  end

  -- Save code buffer
  vim.cmd("silent! write")
  
  -- Save input buffer if modified
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf) == M.input_file and vim.api.nvim_get_option_value('modified', { buf = buf }) then
      vim.api.nvim_buf_call(buf, function() vim.cmd("silent! write") end)
    end
  end

  -- Ensure UI is open
  M.setup_layout()

  -- Empty output file before running
  vim.fn.writefile({"Compiling and running..."}, M.output_file)
  
  local out_file = "/tmp/" .. name .. "_runner.out"
  local base_cmd = runner_func(file, out_file)

  -- Execute using bash, capturing time and exit code
  local full_cmd = string.format(
    "bash -c \"START=\\$(date +%%s%%3N); %s < '%s' > '%s' 2>&1; EXIT_CODE=\\$?; END=\\$(date +%%s%%3N); echo -e '\\n\\n=== Execution Report ===\\nExit Code:' \\$EXIT_CODE '\\nTime:' \\$((END-START)) 'ms' >> '%s'\"",
    base_cmd, M.input_file, M.output_file, M.output_file
  )

  -- Run asynchronously
  vim.fn.jobstart(full_cmd, {
    on_exit = function(_, exit_code, _)
      -- Reload output buffer to show new contents
      local out_win = get_win_by_bufname(M.output_file)
      if out_win then
        local out_buf = vim.api.nvim_win_get_buf(out_win)
        vim.api.nvim_buf_call(out_buf, function() vim.cmd("edit!") end)
      end
    end
  })
end

return M
