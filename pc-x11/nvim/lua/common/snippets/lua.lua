local ok, ls = pcall(require, "luasnip")
if not ok then return {} end
local s, t, i = ls.s, ls.t, ls.i

local kmf = s("kmf", {
  t("[\"<Leader>"), i(1, "dd"), t("\"] = { function() "),
  i(2, "func()"),
  t(" end, desc = \""),
  i(3, "description"),
  t("\" },"),
})

local kms = s("kms", {
  t("[\"<Leader>"), i(1, "e"), t("\"] = { \"<Cmd>"),
  i(2, "command"),
  t("<CR>\", desc = \""),
  i(3, "description"),
  t("\" },"),
})

return {  kmf, kms }
