New to Neovim and snippets? This quick "noobs" guide walks you through creating
and testing a LuaSnip snippet in your existing AstroNvim-like setup.

1) What is a snippet?
- A snippet is a small piece of text you can expand with a short trigger word.
  Example: type `nCr` then expand it into a LaTeX binomial expression.

2) Where to put snippets
- Put LuaSnip snippets in `lua/snippets/` inside your config: e.g.
  `~/.config/nvim/lua/snippets/`.
- The loader maps filename → filetype. Name files like `tex.lua`, `markdown.lua`.

3) Minimal snippet file (step-by-step)
- Create a file called `tex.lua`:

```lua
local ok, ls = pcall(require, "luasnip")
if not ok then return {} end
local s, t, i = ls.s, ls.t, ls.i

-- Trigger: nCr  Expands to {}^{n}C_{r}
local nCr = s("nCr", { t("{}^{"), i(1, "n"), t("}C_{"), i(2, "r"), t("}") })

return { nCr }
```

4) Reload snippets without restarting Neovim
- In Neovim run:

```vim
:lua require('luasnip.loaders.from_lua').load({ paths = vim.fn.stdpath('config') .. '/lua/snippets' })
```

5) Test the snippet
- Open a `.tex` or `.md` file, type `nCr` and trigger expansion using your snippet key
  (often Tab or Ctrl-k depending on your config / completion plugin). If nothing
  happens, try manual completion (Ctrl-Space) or restart Neovim.

6) Common newbie pitfalls
- Filename must match the filetype (e.g., `tex.lua`).
- Each snippet file must return a flat list `{ s1, s2 }` — not a table keyed by
  filetype. If you want the same snippets in multiple filetypes, rely on
  `filetype_extend("markdown", {"tex","latex"})` in your config.
- Use `pcall(require, 'luasnip')` to avoid errors when LuaSnip isn't loaded yet.

7) Need a template?
- Tell me and I'll add a small `snippet-template.lua` you can copy when creating
  new files.

That's it — quick, simple, and safe for beginners. Keep snippets small and
clear; you can always expand them with choices and nodes as you learn more.

More detail — adding multiple snippets and nodes
------------------------------------------------
Below are practical examples and explanations for the common LuaSnip nodes so
you can add richer snippets.

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

7) Reloading & debugging
- Reload snippets without restarting Neovim:

  ```vim
  :lua require('luasnip.loaders.from_lua').load({ paths = vim.fn.stdpath('config') .. '/lua/snippets' })
  ```

- List loaded snippets for a filetype:

  ```vim
  :lua print(vim.inspect(require('luasnip').get_snippets('tex')))
  ```

8) Completion integration
- Your completion plugin (nvim-cmp, etc.) is responsible for showing snippet
  suggestions; expansion keys (Tab/Ctrl-k) depend on your keymaps. If snippets
  don't appear, try invoking completion manually or restart Neovim.

9) When to split files
- If you have many snippets for different purposes (math, figures, macros),
  consider splitting into `lua/snippets/tex_math.lua`, `lua/snippets/tex_figs.lua`.
  The loader will treat each file as the `tex` filetype if you keep the file
  named with `tex` as prefix — but the simplest option is one file per
  filetype (`tex.lua`) and keep it organized with comments and sections.

If you want, I can add a ready-to-copy `snippet-template.lua` in this folder
to use when creating new snippet files.
