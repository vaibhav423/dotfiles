This folder contains LuaSnip snippets loaded by the `luasnip.loaders.from_lua`
loader (configured in `lua/plugins/latex.lua`).

Guidelines
- Create a Lua file that returns a table mapping filetypes to snippet lists.
  Example: `lua/snippets/latex.lua`

  ```lua
  local ls_ok, ls = pcall(require, "luasnip")
  if not ls_ok then return {} end
  local s, t, i = ls.s, ls.t, ls.i

  local nCr = s("nCr", { t("{}^{"), i(1, "n"), t("}C_{"), i(2, "r"), t("}") })

  return {
    tex = { nCr },
    latex = { nCr },
    markdown = { nCr },
  }
  ```

- The loader uses `vim.fn.stdpath("config") .. "/lua/snippets"` as the
  path, so snippets placed under `lua/snippets/*.lua` are discovered.
- Use unique keys if you call `ls.add_snippets` manually elsewhere; the
  loader handles simple `return { ft = { ... } }` structures.

Testing
- Start Neovim, open a `.tex` or `.md` file and run:

  ```vim
  :lua print(vim.inspect(require('luasnip').get_snippets('latex')))
  ```

  You should see your snippet definition listed.
