-- lib/vault.lua
-- Vault template initialisation and pinned-dir management.
--
-- M.init_template()
--   Reads vault root from ~/Water/Fire/vault, prompts for a relative path (pre-filled
--   with the current value in ~/Water/Fire/pinned), creates the directory tree and
--   writes the two topic markdown template files.
--
-- M.set_pinned()
--   Opens a snacks.picker listing all vault subdirs (excluding .git / .obsidian).
--   On confirm, writes the chosen relative path to ~/Water/Fire/pinned.
--
-- M.open_pinned()
--   Reads ~/Water/Fire/vault and /Water/Fire/pinned, cds into the pinned dir, then opens
--   <topic>.md and <topic>-Questions.md in two vertical splits.

local M = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local vars = require(personal.variables)
local VAULT = vars.vaultdir
local PINNED_CFG = vim.fn.expand( VAULT .. "/pinned")

--- Read a file and return its trimmed contents, or nil + error message.
local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then return nil, err end
  local content = f:read("*a")
  f:close()
  return content:match("^%s*(.-)%s*$")
end

--- Write text + newline to a file. Returns true or nil + error message.
local function write_file(path, text)
  local f, err = io.open(path, "w")
  if not f then return nil, err end
  f:write(text .. "\n")
  f:close()
  return true
end

--- Write text + newline to a file. Returns true or nil + error message.
local function write_file2(path, text)
  local f, err = io.open(path, "w")
  if not f then return nil, err end
  f:write(text)
  f:close()
  return true
end
--- Create directory (and parents). Returns true or nil + error.
local function mkdir(path)
  local ok = vim.fn.mkdir(path, "p")
  if ok == 0 then return nil, "mkdir failed: " .. path end
  return true
end

--- Write a markdown file only if it does not already exist.
local function write_md(path, content)
  if vim.fn.filereadable(path) == 1 then
    vim.notify("vault: file already exists, skipping: " .. path, vim.log.levels.WARN)
    return
  end
  local ok, err = write_file(path, content)
  if not ok then
    vim.notify("vault: could not write " .. path .. ": " .. (err or "?"), vim.log.levels.ERROR)
  end
end

-- ---------------------------------------------------------------------------
-- M.create_topic_files
-- ---------------------------------------------------------------------------

local function create_topic_files(vault, value)
  -- 5. Derive paths
  local full_pinned = vault .. "/" .. value
  local topic_name  = vim.fn.fnamemodify(full_pinned, ":t")
  local assets_dir  = vault .. "/Assets/" .. topic_name
  local questions_dir = assets_dir .. "/questions"

  -- 6. Create directories
  for _, dir in ipairs({ full_pinned, questions_dir }) do
    local mok, merr = mkdir(dir)
    if not mok then
      vim.notify("vault: " .. (merr or "mkdir error"), vim.log.levels.ERROR)
      return false
    end
  end

  -- 7. Write <topic>.md
  local topic_md = table.concat({
    "# gallery",
    "```img-gallery",
    "path: Assets/" .. topic_name,
    "type: vertical",
    "mobile: 3",
    "columns: 3",
    "gutter: 2",
    "radius: 20",
    "```",
    "# general",
    "[[" .. topic_name .. "-Questions]]",
    "# images",
    "",
  }, "\n")
  write_md(full_pinned .. "/" .. topic_name .. ".md", topic_md)

  -- 8. Write <topic>-Questions.md
  local questions_md = table.concat({
    "# gallery",
    "```img-gallery",
    "path: Assets/" .. topic_name .. "/questions",
    "type: vertical",
    "mobile: 3",
    "columns: 3",
    "gutter: 2",
    "radius: 20",
    "```",
    "# solve-tips",
    "# Question",
    "",
  }, "\n")
  write_md(full_pinned .. "/" .. topic_name .. "-Questions.md", questions_md)
  
  return true
end

-- ---------------------------------------------------------------------------
-- M.init_template
-- ---------------------------------------------------------------------------

function M.init_template()
  -- 1. Read vault root
  local vault, err1 = VAULT

  -- 2. Read current pinned value as default for the prompt
  local current_pinned = read_file(PINNED_CFG) or ""

  -- 3. Prompt via snacks.input
  require("snacks").input({
    prompt  = "Pinned path (relative to vault: " .. vault .. ")",
    default = current_pinned,
    win     = { width = 70 },
  }, function(value)
    if not value or value == "" then
      vim.notify("vault: init cancelled", vim.log.levels.INFO)
      return
    end

    -- 4. Persist to ~/Water/Fire/pinned
    local ok, err = write_file2(PINNED_CFG, value)
    if not ok then
      vim.notify("vault: cannot write " .. PINNED_CFG .. ": " .. (err or "?"), vim.log.levels.ERROR)
      return
    end

    -- 5. Derive paths and create files
    local full_pinned = vault .. "/" .. value
    local topic_name  = vim.fn.fnamemodify(full_pinned, ":t")

    if not create_topic_files(vault, value) then
      return
    end

    vim.notify(
      "vault: initialized " .. topic_name .. "\npinned → " .. PINNED_CFG,
      vim.log.levels.INFO
    )
  end)
end

-- ---------------------------------------------------------------------------
-- M.set_pinned
-- ---------------------------------------------------------------------------

function M.set_pinned()
  -- 1. Read vault root
  local vault, err1 = VAULT

  -- 2. Enumerate subdirs via find, excluding .git and .obsidian
  local raw = vim.fn.systemlist(
    "cd " .. vim.fn.shellescape(vault)
    .. " && find . -mindepth 1 -type d"
    .. " \\( -name '.git' -o -name '.obsidian' \\) -prune"
    .. " -o -type d -printf '%P\\n'"
  )

  -- Filter out empty lines that come from the -prune side of -o
  local dirs = {}
  for _, line in ipairs(raw) do
    if line ~= "" then
      table.insert(dirs, line)
    end
  end

  if #dirs == 0 then
    vim.notify("vault: no subdirectories found in " .. vault, vim.log.levels.WARN)
    return
  end

  -- 3. Build snacks picker items
  local items = {}
  for i, rel in ipairs(dirs) do
    table.insert(items, {
      text = rel,
      _rel = rel,
      idx  = i,
    })
  end

  -- 4. Open picker
  require("snacks").picker({
    title   = "Set Pinned Dir  (" .. vault .. ")",
    items   = items,
    format  = function(item) return { { item.text } } end,
    confirm = function(picker, item)
      picker:close()
      if not item then return end
      local ok, err = write_file2(PINNED_CFG, item._rel)
      if not ok then
        vim.notify("vault: cannot write " .. PINNED_CFG .. ": " .. (err or "?"), vim.log.levels.ERROR)
        return
      end
      vim.notify("vault: pinned → " .. item._rel, vim.log.levels.INFO)
    end,
  })
end

-- ---------------------------------------------------------------------------
-- M.open_pinned
-- ---------------------------------------------------------------------------

function M.open_pinned()
  -- 1. Read vault root and pinned relative path
  local vault, err1 = VAULT

  local pinned_rel, err2 = read_file(PINNED_CFG)
  if not pinned_rel or pinned_rel == "" then
    vim.notify("vault: cannot read " .. PINNED_CFG .. ": " .. (err2 or "empty"), vim.log.levels.ERROR)
    return
  end

  -- 2. Derive paths
  local full_pinned  = vault .. "/" .. pinned_rel
  local topic_name   = vim.fn.fnamemodify(full_pinned, ":t")
  local topic_file   = full_pinned .. "/" .. topic_name .. ".md"
  local questions_file = full_pinned .. "/" .. topic_name .. "-Questions.md"

  -- 3. Verify files exist, create if not
  for _, f in ipairs({ topic_file, questions_file }) do
    if vim.fn.filereadable(f) == 0 then
      vim.notify("vault: file not found, recreating templates...", vim.log.levels.INFO)
      create_topic_files(vault, pinned_rel)
      break
    end
  end
  -- 4. set markdown oxide with full path
  -- this is go version which is not present in pacmas -S yq
  -- local yq_expr = string.format('.new_file_folder_path = "%s"', full_pinned)
  -- local cmd = string.format(
  --   "yq -i -p toml -o toml %s ~/.config/moxide/settings.toml",
  --   vim.fn.shellescape(yq_expr)
  -- )
  
  local yq_expr = string.format('.new_file_folder_path = "%s"', full_pinned)

  -- this is python version
  -- Use 'tomlq' instead of 'yq'
  -- We remove '-p toml' and '-o toml' as tomlq assumes them
  local moxide_cfg = vim.fn.expand("~/.config/moxide/settings.toml")
  local cmd = string.format(
    "tomlq -it %s %s",
    vim.fn.shellescape(yq_expr),
    vim.fn.shellescape(moxide_cfg)
  )

  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    -- We include the 'output' variable to see exactly what the shell complained about
    vim.notify(
      "vault: failed to update moxide path to " .. full_pinned .. "\nError: " .. vim.trim(output),
      vim.log.levels.ERROR
    )
  end


  -- 5. cd into the pinned directory
  vim.cmd("cd " .. vim.fn.fnameescape(vault))

  -- 6. Open both files as buffers (no splits)
  vim.cmd("edit " .. vim.fn.fnameescape(topic_file))
  vim.cmd("badd " .. vim.fn.fnameescape(questions_file))

  -- vim.notify("vault: opened " .. topic_name, vim.log.levels.INFO)
end

return M

