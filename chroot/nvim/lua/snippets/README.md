This folder contains LuaSnip snippets loaded by the `luasnip.loaders.from_lua`
loader (see `lua/plugins/latex.lua`).

Quick guide — add one snippet file
- File name = filetype. Example: to add snippets for TeX use `tex.lua`.
- Each file must return a *flat list* of snippet objects, e.g. `{ s1, s2 }`.
- The loader maps the filename to the filetype (no table keyed by filetype).

Minimal example for `lua/snippets/tex.lua`:

```lua
local ok, ls = pcall(require, "luasnip")
if not ok then return {} end
local s, t, i = ls.s, ls.t, ls.i

local nCr = s("nCr", { t("{}^{"), i(1, "n"), t("}C_{"), i(2, "r"), t("}") })
local ncr = s("ncr", { t("{}^{"), i(1, "n"), t("}C_{"), i(2, "r"), t("}") })

return { nCr, ncr }
```

Notes
- Your config already runs `luasnip.filetype_extend("markdown", { "tex", "latex" })`,
  so a single `tex.lua` will make those snippets available in markdown and latex buffers.
- Use `pcall(require, "luasnip")` to avoid errors if LuaSnip isn't loaded when the file is
  evaluated.

Reloading and testing
- After adding or editing snippets you can either restart Neovim or reload the snippets
  loader manually:

  ```vim
  :lua require('luasnip.loaders.from_lua').load({ paths = vim.fn.stdpath('config') .. '/lua/snippets' })
  ```

- Inspect loaded snippets for a filetype:

  ```vim
  :lua print(vim.inspect(require('luasnip').get_snippets('tex')))
  ```

- If your completion plugin (nvim-cmp, coc, etc.) does caching, you may need to trigger a
  manual completion refresh or restart the editor to pick up new snippet metadata.

Further tips
- Keep file names focused (e.g., `tex.lua`, `latex.lua`) so the loader associates them
  with the correct filetypes.
- Prefer returning a flat list from each file — that's the `from_lua` convention and avoids
  mysterious missing-snippet issues.
- If you need snippets that apply to multiple filetypes and want a single source file,
  keep it named after one primary filetype (like `tex.lua`) and rely on
  `filetype_extend` in your config to share them.
