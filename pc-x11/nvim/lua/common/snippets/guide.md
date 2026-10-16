
1) File structure reminder
- Put one file per filetype in `lua/snippets/`. Example: `tex.lua` for TeX.
- Each file must `return { s1, s2, ... }` — a flat list of snippet objects.

2) Basic snippet (multiple in one file)
```lua
local ok, ls = pcall(require, "luasnip")
if not ok then return {} end
local s, t, i = ls.s, ls.t, ls.i

local bold = s({ trig = "bf", dscr = "Bold text" }, { t("\\textbf{"), i(1), t("}") })
local frac = s("fr", { t("\\frac{"), i(1, "a"), t("}{"), i(2, "b"), t("}") })

return { bold, frac }
```

3) Useful nodes
- `t("text")` — plain text node (no cursor)
- `i(n, "default")` — insert node; `n` is the tabstop index
- `c(n, { node1, node2 })` — choice node: user can pick one option at that tabstop
- `f(func, {args})` — function node: `func(args, snip)` returns a string to insert

Example with a choice node and a function node:
```lua
local c, f = ls.c, ls.f

local symbol = s("sym", {
  t("\\"), c(1, { t("alpha"), t("beta"), t("gamma") }),
})

local upcase = s("up", {
  i(1, "text"), t(" -> "), f(function(args) return args[1][1]:upper() end, {1})
})

return { symbol, upcase }
```

4) Re-using values (repeat)
- To repeat what the user typed in a previous insert node you can use a
  function node that returns the value of that insert. The `f` example above
  demonstrates transforming `i(1)` and showing it again.

5) Trigger options and metadata
- Instead of just giving a string trigger you can pass a table: `s({ trig = "fr",
  name = "Fraction", dscr = "Create a LaTeX \frac{}{}" }, {...})`. Many
  completion frontends show `dscr` as a tooltip.

6) Adding many snippets
- Simply add more `s(...)` entries to the `return { ... }` list in the same file.
