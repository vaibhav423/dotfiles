-- Snippets for the `tex` filetype.
-- from_lua loader: filename = filetype, return value must be a flat list.
local ok, ls = pcall(require, "luasnip")
if not ok then return {} end
local s = ls.s
local t = ls.t
local i = ls.i
local ncr = s("ncr", { t("{}^{"), i(1, "n"), t("}C_{"), i(2, "r"), t("}") })
local binom = s("bin", { t("\\binom{"), i(1, "n"), t("}{"), i(2, "k"), t("}") })
return { ncr,binom }
