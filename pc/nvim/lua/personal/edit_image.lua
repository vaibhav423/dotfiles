local M = {}

local img_exts = {
  png = true,
  jpg = true,
  jpeg = true,
  webp = true,
  svg = true,
  gif = true,
  bmp = true,
  tiff = true,
  avif = true,
  ico = true,
}

local function get_image_path(line)
  -- 1. Check markdown links [alt](path) or ![alt](path) for image extension
  for path in line:gmatch("%[.-%]%(%s*(.-)%s*%)") do
    local clean = path:gsub("[%?#].*$", "")
    local ext = clean:match("%.(%w+)$")
    if ext and img_exts[ext:lower()] then
      return clean
    end
  end

  -- 2. Check html src="path"
  for path in line:gmatch([[src=["']%s*(.-)%s*["']]) do
    local clean = path:gsub("[%?#].*$", "")
    local ext = clean:match("%.(%w+)$")
    if ext and img_exts[ext:lower()] then
      return clean
    end
  end

  -- 3. Fallback: first markdown link target, html src, or cursor filename
  local fallback = line:match("!%[.-%]%(%s*(.-)%s*%)")
    or line:match("%[.-%]%(%s*(.-)%s*%)")
    or line:match([[src=["']%s*(.-)%s*["']])
    or vim.fn.expand("<cfile>")

  if fallback and fallback ~= "" then
    return fallback:gsub("[%?#].*$", "")
  end

  return nil
end

function M.edit()
  local line = vim.api.nvim_get_current_line()
  local path = get_image_path(line)

  if not path or path == "" then
    vim.notify("EditImage: no image path found on current line", vim.log.levels.WARN)
    return
  end

  local abs_path
  if path:sub(1, 1) == "/" or path:sub(1, 1) == "~" then
    abs_path = vim.fn.expand(path)
  else
    local buf_dir = vim.fn.expand("%:p:h")
    abs_path = buf_dir .. "/" .. path
    if vim.fn.filereadable(abs_path) == 0 then
      abs_path = vim.fn.getcwd() .. "/" .. path
    end
  end

  if vim.fn.filereadable(abs_path) == 0 then
    vim.notify("EditImage: file not found:\n" .. abs_path, vim.log.levels.ERROR)
    return
  end

  vim.system({ "pinta", abs_path }, { detach = true })
  vim.notify("Opened in Pinta: " .. vim.fn.fnamemodify(abs_path, ":t"), vim.log.levels.INFO)
end

return M
