# Config Maintenance Guide

This document covers the conventions, patterns, and decision rules used in this config.
Read it before making any change — most bugs come from putting things in the wrong place.

---

## The three rules that prevent most mistakes

### 1. Mappings go in `config/mappings.lua` — never `vim.keymap.set` at module level

All global keymaps belong in `lua/lib/mappings.lua`. The file returns a plain table
that `astrocore.lua` merges into `opts.mappings` at startup:

```lua
-- lua/lib/mappings.lua  ← edit this file to add keymaps
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

### 2. Autocmds go in `astrocore.lua` — never `vim.api.nvim_create_autocmd` at module level

All autocmds belong in `config/astrocore.lua` under `opts.autocmds`:

```lua
opts = {
  autocmds = {
    my_group = {          -- group name (string key)
      {
        event = "BufReadPost",
        pattern = "*.foo",
        desc = "...",
        callback = function(args) ... end,
      },
    },
  },
}
```

The only exception: autocmds tightly coupled to a specific plugin that aren't worth
wiring through astrocore (e.g. the copilot per-filetype auto_trigger autocmd in
`plugins/ai/copilot.lua`). These must still live inside the plugin's `config` function,
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

Add to `lua/lib/mappings.lua` in the appropriate mode block (`n`, `i`, `v`, `t`):

```lua
["<Leader>xy"] = { function() require("lib.mymodule").do_thing() end, desc = "Do thing" },
```

Keep all `require()` calls inside the function body, never at the top of the mapping table.

### New autocmd

Add to `config/astrocore.lua` → `opts.autocmds`:

```lua
my_feature = {
  { event = "BufEnter", pattern = "*.md", desc = "...", callback = function() ... end },
},
```

### New vim option

Add to `config/astrocore.lua` → `opts.options.opt` or `opts.options.g`.

### New plugin

1. Create a file in the appropriate `plugins/` subdirectory.
2. Return a valid lazy spec table (or a list of specs).
3. Add the new file to that subdirectory's `init.lua` — **this is required**.
   Lazy only auto-loads a subdirectory if it has an `init.lua`; files in subdirs
   without one are silently ignored.

```lua
-- plugins/tools/init.lua  ← add a line here when you add a new file
return {
  { import = "plugins.tools.terminal" },
  { import = "plugins.tools.treesitter" },
  { import = "plugins.tools.mynewplugin" },  -- ← add this
}
```

Pick the right subdirectory:
- `core/` — overrides/extensions of AstroNvim's own plugins (astrocore, astrolsp, astroui, mason, treesitter)
- `ai/` — AI completion or chat plugins
- `writing/` — markdown, LaTeX, prose, text editing
- `tools/` — terminal, runners, debuggers, git, file management

### New custom Lua module (not a plugin spec)

Add to `lua/lib/`. Return a module table with a `setup()` function if it registers
autocmds or user commands. Call `require("lib.mymodule").setup()` from `polish.lua`.

```lua
-- lua/lib/mymodule.lua
local M = {}

function M.do_thing() ... end

function M.setup()
  vim.api.nvim_create_user_command("MyCmd", M.do_thing, { desc = "..." })
end

return M
```

```lua
-- lua/polish.lua
require("lib.mymodule").setup()
```

Do **not** call `M.setup()` at the bottom of the module file itself. Keep setup explicit.

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
- [ ] If registering autocmds/commands: put them in `M.setup()`, call from `polish.lua`
- [ ] Do **not** call `M.setup()` at the bottom of the module file
- [ ] If the module needs a keymap: add it to `lua/lib/mappings.lua`, `require` the module inside the lambda

## Adding a new plugin — checklist

- [ ] Create file in correct `plugins/` subdirectory
- [ ] Return a `---@type LazySpec` table
- [ ] All `require()` calls inside callbacks/functions, never at top of `opts`
- [ ] Keymaps in `keys = { ... }` table, not in `config`
- [ ] If extending an AstroNvim-owned plugin: use `opts = function(_, opts)` form
- [ ] If the plugin is optional (extends another): add `optional = true`

## Modifying an existing mapping — checklist

- [ ] Find it in `lua/lib/mappings.lua` (global mappings)
- [ ] If it's an LSP mapping (only active when an LSP attaches): it's in `astrolsp.lua` `opts.mappings`
- [ ] If it's a plugin-specific key (triggers load): it's in that plugin's `keys` table
- [ ] Do not add a second mapping for the same key in a different file — last-writer wins and it's confusing

---

## Startup / debugging tips

**Check which plugin owns a mapping:**
```
:verbose map <leader>xx
```

**Check why a plugin loaded:**
```
:Lazy profile
```

**Reload a single plugin without restarting:**
```
:Lazy reload plugin-name
```

**Check LSP status on current buffer:**
```
:LspInfo
```

**Inspect what astrocore sees for options/mappings/autocmds:**
```lua
:lua print(vim.inspect(require("astrocore").config))
```

**Check for filetype mismatches:**
```
:lua print(vim.bo.filetype)
```
Should always be `"markdown"`, never `"md"`.


sometimes Neovim caches compiled `.luac` files keyed by their original path. When you move,
rename, or delete a file, the old cache entry is not automatically invalidated — Neovim
may keep loading the stale bytecode and you'll get confusing `module not found` errors
that don't match what's on disk.

if u get that wipe the cache after any structural change (file moves, renames, deletions):
```sh
rm -rf ~/.cache/nvim/luac/
```
Neovim will recompile from source on the next startup. This is safe and fast.

**Run the Lua linter (selene) locally:**
```sh
selene lua/
```
Config is in `selene.toml` at the repo root.

**Format with stylua:**
```sh
stylua lua/
```
Config is in `.stylua.toml` — 2-space indent, 100-column width.

---

