-- lua/my_vars.lua
local M = {}

local CONFIG_PATH = vim.fn.expand("~/.config/personal/config.json")
local DEFAULT_VAULTDIR = "~/Water/Fire"

local ok, config = pcall(vim.json.decode, table.concat(vim.fn.readfile(CONFIG_PATH), "\n"))
if not ok or type(config) ~= "table" then config = {} end

M.vaultdir = vim.fn.expand(config.vaultdir or DEFAULT_VAULTDIR)

return M
