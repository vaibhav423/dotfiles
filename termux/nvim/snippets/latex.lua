-- Snippets for LaTeX/TeX/Markdown loaded by LuaSnip's from_lua loader
local ok, ls = pcall(require, "luasnip")
if not ok or not ls then
  return {}
end

local s = ls.s
local t = ls.t
local i = ls.i

-- Register both `nCr` and lowercase `ncr` triggers; many completion
-- frontends and users type lowercase, so provide both to avoid missing
-- the snippet in the completion menu.
local nCr = s("nCr", { t("{}^{"), i(1, "n"), t("}C_{"), i(2, "r"), t("}") })
local ncr = s("ncr", { t("{}^{"), i(1, "n"), t("}C_{"), i(2, "r"), t("}") })

return {
  tex = { nCr, ncr },
  latex = { nCr, ncr },
  markdown = { nCr, ncr },
}
