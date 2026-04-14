# Config Maintenance Guide

This document covers the conventions, patterns, and decision rules used in this config.
Read it before making any change — most bugs come from putting things in the wrong place.

---

## The three rules that prevent most mistakes

### 1. Mappings go in `config/mappings.lua` or `lsp/mappings.lua` — never `vim.keymap.set` at module level

All global keymaps belong in `lua/config/mappings.lua`. LSP-specific keymaps (only active when a language server attaches) belong in `lua/lsp/mappings.lua`. Both files return a plain table that is merged into `opts.mappings` by `astrocore.lua` and `astrolsp.lua` respectively:

```lua
-- lua/config/mappings.lua (global) OR lua/lsp/mappings.lua (LSP)
return {
  n = { ["<Leader>xx"] = { function() ... end, desc = "..." } },
  i = { ... },
  t = { ... },
  v = { ... },
}
```

The only exceptions where `vim.keymap.set` is acceptable:
- **Buffer-local** maps inside `astrolsp.lua`'s `on_attach` (e.g. `buffer = bufnr`).
- A plugin's own `keys = { ... }` table in its lazy spec (preferred over `config`).

Never put `vim.keymap.set` at the top level of any file in `plugins/`, `lib/`, or `polish.lua`.

### 2. Autocmds go in `config/autocmds.lua` or `lsp/autocmds.lua` — never `vim.api.nvim_create_autocmd` at module level

Global autocmds belong in `lua/config/autocmds.lua`. LSP-specific autocmds belong in `lua/lsp/autocmds.lua`. They are required by `astrocore.lua` and `astrolsp.lua` respectively into their `opts.autocmds`:

```lua
-- lua/config/autocmds.lua OR lua/lsp/autocmds.lua
return {
  my_group = {          -- group name (string key)
    {
      event = "BufReadPost",
      pattern = "*.foo",
      desc = "...",
      callback = function(args) ... end,
    },
  },
}
```

The only exception: autocmds tightly coupled to a specific plugin that aren't worth
wiring through astrocore (e.g. the copilot per-filetype auto_trigger autocmd in
`plugins/copilot.lua`). These must still live inside the plugin's `config` function,
never at module level.

### 3. Vim options go in `astrocore.lua` — never `vim.opt` at module level

```lua
opts = {
  options = {
    opt = { relativenumber = true, wrap = false },  -- vim.opt.*
    g   = { some_plugin_var = true },               -- vim.g.*
  },
}
```

---

## Where to add things

### New global keymap

Add to `lua/config/mappings.lua` in the appropriate mode block (`n`, `i`, `v`, `t`):

```lua
["<Leader>xy"] = { function() require("lib.mymodule").do_thing() end, desc = "Do thing" },
```

Keep all `require()` calls inside the function body, never at the top of the mapping table.

### New autocmd

Add to `lua/config/autocmds.lua` (for global) or `lua/lsp/autocmds.lua` (for LSP-specific):

```lua
my_feature = {
  { event = "BufEnter", pattern = "*.md", desc = "...", callback = function() ... end },
},
```

### New vim option

Add to `config/astrocore.lua` → `opts.options.opt` or `opts.options.g`.

### New custom Lua module (not a plugin spec)

Add to `lua/lib/`. Return a module table containing only pure functions (no `vim.api.nvim_create_autocmd` or `vim.keymap.set` inside).

```lua
-- lua/lib/mymodule.lua
local M = {}

function M.do_thing() ... end

return M
```

Then "wire it up" centrally:
- **For a keymap:** Add it to `lua/config/mappings.lua` mapped to `function() require("lib.mymodule").do_thing() end`.
- **For an autocmd:** Add it to `lua/config/autocmds.lua`.
- **For a user command:** Add it to `lua/config/commands.lua`.

### New LSP server

In `config/astrolsp.lua`:

```lua
-- For servers installed via Mason:
-- Add to mason.lua ensure_installed instead.

-- For servers installed manually (not via Mason):
opts.servers = vim.list_extend(opts.servers or {}, { "my-server" })

-- Per-server lspconfig options:
opts.config = vim.tbl_deep_extend("force", opts.config or {}, {
  ["my-server"] = {
    cmd = { "/path/to/server" },
    filetypes = { "myft" },
    root_dir = require("lspconfig.util").root_pattern(".git"),
  },
})
```

Always use `vim.list_extend` for `opts.servers` (list) and `vim.tbl_deep_extend` for
everything else (tables). Using `opts.servers = { "my-server" }` directly wipes any
servers added by upstream AstroNvim.

---

## Plugin spec patterns

### `opts` vs `opts = function(_, opts)`

Use a plain table when you own the spec entirely:
```lua
{ "author/plugin", opts = { key = "value" } }
```

Use the function form when extending an upstream spec (AstroNvim already configures the plugin):
```lua
{
  "AstroNvim/astrolsp",
  opts = function(_, opts)
    opts.features = vim.tbl_deep_extend("force", opts.features or {}, { codelens = true })
    opts.servers = vim.list_extend(opts.servers or {}, { "my-server" })
    return opts
  end,
}
```

The function form is **required** for all four AstroNvim core plugins:
`astrocore`, `astrolsp`, `astroui`, `mason-tool-installer`.

### `keys` table vs `vim.keymap.set` in `config`

Prefer `keys`:
```lua
{
  "author/plugin",
  keys = {
    { "<leader>mt", function() require("myplugin").action() end, desc = "Do thing" },
  },
}
```

This integrates with lazy's lazy-loading (the key triggers the load) and with which-key.
Only use `config` for logic that must run after setup, not for mapping registration.

### `require()` inside callbacks, not at the top of `opts`

Wrong — runs at spec-load time before the plugin exists:
```lua
opts = function(_, opts)
  local plugin = require("some.plugin")   -- ERROR: not loaded yet
  ...
end
```

Correct — runs at call time, after the plugin is loaded:
```lua
opts = function(_, opts)
  opts.keymap["<C-x>"] = {
    function()
      local plugin = require("some.plugin")   -- safe: called when key is pressed
      plugin.do_thing()
    end,
    "fallback",
  }
end
```

### `optional = true`

Use on specs that extend a plugin which may or may not be present:
```lua
{ "Saghen/blink.cmp", optional = true, opts = function(_, opts) ... end }
```

This prevents an error if `blink.cmp` is later removed.

---

## Filetype conventions

Neovim normalizes filetype internally. Never use `"md"` — always use `"markdown"`:

```lua
-- Wrong
if vim.bo.filetype == "md" then ...

-- Correct
if vim.bo.filetype == "markdown" then ...
```

---

## `polish.lua` rules

`polish.lua` runs after all plugins are loaded. Keep it thin — it should only contain:
- `require("lib.X").setup()` calls for custom modules that register commands/autocmds
- One-time environment checks (e.g. `if vim.env.SSH_TTY then`)

Do not put plugin configuration, mappings, or options in `polish.lua`.

---

## `community.lua`

Add AstroCommunity packs here. The file is imported before `plugins/`, so community
specs are processed first and can be overridden by your own specs.

```lua
{ import = "astrocommunity.pack.python" },
```

To disable a community pack that conflicts, add a spec with `enabled = false` in
the relevant `plugins/` file:
```lua
{ "some/plugin-from-community", enabled = false }
```

---

## Deprecated APIs to avoid

These were deprecated in Neovim 0.10 and will be removed:

| Deprecated | Replacement |
|---|---|
| `vim.api.nvim_buf_get_option(buf, name)` | `vim.bo[buf].name` |
| `vim.api.nvim_buf_set_option(buf, name, val)` | `vim.bo[buf].name = val` |
| `vim.api.nvim_win_get_option(win, name)` | `vim.api.nvim_get_option_value(name, { win = win })` |
| `vim.api.nvim_win_set_option(win, name, val)` | `vim.api.nvim_set_option_value(name, val, { win = win })` |
| `vim.api.nvim_get_option(name)` | `vim.o.name` |

---

## Adding a new lib module — checklist

- [ ] Create `lua/lib/mymodule.lua`, return `M`
- [ ] Public API: `M.my_function()` for reusable logic
- [ ] Do **not** use `M.setup()` to register autocmds/commands
- [ ] If the module needs a keymap: add it to `lua/config/mappings.lua`, `require` the module inside the lambda
- [ ] If the module needs an autocmd/command: add it to `lua/config/autocmds.lua` or `lua/config/commands.lua`

## Adding a new plugin — checklist

- [ ] Create file in correct `plugins/` subdirectory
- [ ] Return a `---@type LazySpec` table
- [ ] All `require()` calls inside callbacks/functions, never at top of `opts`
- [ ] Keymaps in `keys = { ... }` table, not in `config`
- [ ] If extending an AstroNvim-owned plugin: use `opts = function(_, opts)` form
- [ ] If the plugin is optional (extends another): add `optional = true`

## Modifying an existing mapping — checklist

- [ ] Find it in `lua/config/mappings.lua` (global mappings)
- [ ] If it's an LSP mapping (only active when an LSP attaches): it's in `lua/lsp/mappings.lua`
- [ ] If it's a plugin-specific key (triggers load): it's in that plugin's `keys` table
- [ ] Do not add a second mapping for the same key in a different file — last-writer wins and it's confusing

---
