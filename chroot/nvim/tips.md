# Config Maintenance Guide

This document covers the conventions, patterns, and decision rules used in this config.
Read it before making any change — most bugs come from putting things in the wrong place.

---

## Directory structure

```
nvim/
├── init.lua                     Bootstrap only. Do not touch.
└── lua/
    ├── lazy_setup.lua           Lazy.nvim setup + 3 imports. Do not touch.
    ├── community.lua            AstroCommunity imports.
    ├── polish.lua               Final setup after plugins load. Keep thin.
    ├── lib/                     Custom Lua modules (not plugin specs).
    │   ├── encryption.lua       .enc file transparent encrypt/decrypt
    │   ├── fold_persist.lua     Save/restore fold state per buffer
    │   ├── fold_toggle.lua      Smart fold-level toggling (z1–z4)
    │   ├── jeerem.lua           Date-countdown reminder command
    │   ├── mappings.lua         All global keymaps (required by astrocore.lua)
    │   ├── mdrender.lua         render-markdown.nvim toggle helper
    │   ├── takephoto.lua        Android camera/Picsart integration
    │   ├── vault.lua            Vault template init, pinned dir picker, open pinned
    │   └── wikilink.lua         [[wikilink]] LSP navigation (Alt-s/Right/Left/f)
    ├── plugins/                 Lazy.nvim plugin specs only.
    │   ├── core/                AstroNvim config extensions
    │   │   ├── init.lua         Re-exports all specs in this subdir (required by Lazy)
    │   │   ├── astrocore.lua    Options, autocmds — mappings live in lib/mappings.lua
    │   │   ├── astrolsp.lua     LSP features, servers, on_attach
    │   │   ├── astroui.lua      Colorscheme, icons, highlights
    │   │   └── mason.lua        mason-tool-installer ensure_installed
    │   ├── ai/                  AI / completion
    │   │   ├── init.lua         Re-exports all specs in this subdir (required by Lazy)
    │   │   ├── copilot.lua      copilot.lua setup + per-ft auto_trigger
    │   │   ├── copilotchat.lua  CopilotChat model override
    │   │   └── cmp_ai.lua       blink.cmp keymap wiring for Copilot
    │   ├── writing/             Markdown, LaTeX, text editing
    │   │   ├── init.lua         Re-exports all specs in this subdir (required by Lazy)
    │   │   ├── latex.lua        vimtex + luasnip-latex-snippets + autopairs
    │   │   ├── mdrender.lua     render-markdown.nvim spec
    │   │   └── surround.lua     nvim-surround
    │   ├── tools/               Terminal and code execution
    │   │   ├── init.lua         Re-exports all specs in this subdir (required by Lazy)
    │   │   ├── takephoto.lua    :TakePhoto, :EditPhoto, :OpenImages, :VaultInit, :VaultPin, :VaultOpen
    │   │   ├── terminal.lua     betterTerm + code_runner
    │   │   └── treesitter.lua   nvim-treesitter parsers
    │   ├── none-ls.lua          DISABLED stub — keep but do not enable
    │   └── user.lua             DISABLED stub — keep but do not enable
    └── snippets/
        └── tex.lua              LuaSnip snippets for tex/latex/markdown
```

---

## The three rules that prevent most mistakes

### 1. Mappings go in `lib/mappings.lua` — never `vim.keymap.set` at module level

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

All autocmds belong in `plugins/core/astrocore.lua` under `opts.autocmds`:

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

Add to `plugins/core/astrocore.lua` → `opts.autocmds`:

```lua
my_feature = {
  { event = "BufEnter", pattern = "*.md", desc = "...", callback = function() ... end },
},
```

### New vim option

Add to `plugins/core/astrocore.lua` → `opts.options.opt` or `opts.options.g`.

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

In `plugins/core/astrolsp.lua`:

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

## Plugin-specific discoveries

### blink.cmp

- `sources.default` is called with **no arguments** during trigger-character detection —
  cannot be used for context-aware source switching.
- `should_show_items` on providers **does** receive context — correct hook for suppressing
  sources inside `[[...]]`.
- `transform_items` runs before blink's fuzzy pass — `item.score` set there is
  unconditionally overwritten at `fuzzy/init.lua:141`. **Do not use `item.score` as a
  custom sort carrier.**
- `item.sortText` is **never overwritten** by blink — safe carrier for external scores.
- Custom sort functions in `fuzzy.sorts` receive `(a, b)` items but no context — read
  cursor position directly via `vim.api.nvim_win_get_cursor` inside the function.
- `use_proximity = true` (default) boosts nearby buffer words above exact matches —
  disable it with `fuzzy = { use_proximity = false }` if wikilink sorting feels wrong.
- The Lua fuzzy implementation ignores `sorts` passed to `fuzzy()` itself (asserts nil),
  but `fuzzy/init.lua:148` calls `sort.sort(filtered_items, sorts_list)` — so
  `fuzzy.sorts` config **does work** with the Lua implementation.

### markdown-oxide (wikilink LSP)

- When `cmp_text` (text between `[[` and cursor) is **empty**: returns all referenceables
  sorted by file modification time (most recent first) — no fuzzy scoring.
- When `cmp_text` is **non-empty**: runs nucleo fuzzy match, stores score as a plain
  integer string in LSP `sortText` (e.g. `"312"`) — higher = better match.
- A space prefix (e.g. `[[ hypr]]`) goes to the non-empty branch — the space is part of
  the query. blink's keyword extractor stops at spaces so only sees `"hypr"`, which fights
  markdown-oxide's ranking.
- Path resolution for bare filename links must use `cwd` (vault root), not `file_dir`.
  Fallback order: `cwd/name.md` → `file_dir/name.md` → `glob(cwd/**/name.md)`.

### render-markdown.nvim

- The astrocommunity avante spec injects `"Avante"` into render-markdown's `file_types`
  via a `specs[]` entry. This injection only reaches `setup()` if the render-markdown
  spec uses `opts = function(_, opts)` (accepting the merged opts table).
- **Never use `opts = function()` (ignoring `_`) with a manual `config` that calls
  `setup(opts)` directly** — it discards every other spec's opts contributions, including
  the `file_types` injection above.
- Correct pattern for `writing/mdrender.lua`:
  ```lua
  opts = function(_, opts)
    opts.latex = { converter = vim.g.markdown_latex_converter }
    return opts   -- return the merged table, not a fresh one
  end,
  -- no config = function needed; lazy calls setup(opts) automatically
  ```

### avante.nvim

- Community spec sets `provider = "copilot"` when `copilot.lua` is present (via an
  optional nested spec). Local `avante.lua` loads after — scalar fields like `provider`
  are last-writer-wins, so the local spec overrides community.
- `providers.gemini` is deeply merged — community spec never sets it, so it comes
  entirely from the local spec.
- Gemini API key is read from `GEMINI_API_KEY` or `AVANTE_GEMINI_API_KEY` env var.

### snacks.nvim

- `Snacks.input(opts, on_confirm)` — async, callback-based. Any logic that depends on
  the user's input must live inside the `on_confirm` callback, not after the call.
- `Snacks.picker(opts)` custom items pattern:
  ```lua
  require("snacks").picker({
    title   = "My Picker",
    items   = { { text = "label", _mydata = "..." }, ... },
    format  = function(item) return { { item.text } } end,
    confirm = function(picker, item)
      picker:close()
      if not item then return end
      -- use item._mydata
    end,
  })
  ```
- For file-preview pickers, add `preview = "file"` and store the path in `item.file`.

### lib/vault.lua

- Vault root is always read at call time from `/sdcard/vault` (trimmed).
- Pinned relative path is read from `/sdcard/pinned` (trimmed).
- `full_pinned = vault .. "/" .. pinned_rel`; `topic_name = fnamemodify(full_pinned, ":t")`.
- Template files: `<full_pinned>/<topic>.md` and `<full_pinned>/<topic>-Questions.md`.
- Asset dirs: `<vault>/Assets/<topic>/` and `<vault>/Assets/<topic>/questions/`.
- `open_pinned()` cds into `full_pinned` (important for LSP root detection), then
  `edit`s the topic file and `badd`s the questions file (no split).

### lib/ytframe.lua

- Triggered by `:YtFrame` or `<Leader>yf`. Prompts for a YouTube URL via `Snacks.input`.
- Timestamp parsing from `?t=` param supports: `7m28s`, `1h7m28s`, `7m`, `28s`, raw
  seconds (e.g. `448`). Produces `MM:SS` or `HH:MM:SS` for ffmpeg `-ss`.
- The `?t=` param is stripped from the URL before passing to `yt-dlp` (avoids errors).
- Execution chain (fully async via `vim.system`):
  1. `yt-dlp -f bestvideo -g <clean_url>` → direct stream URL
  2. `ffmpeg -ss <ts> -i <stream> -frames:v 1 -q:v 2 -y <out.jpg>`
- Output path uses the same `find_section_path("gallery")` logic as `takephoto.lua`
  (falls back to `"Assets/"`). Filename is `<unix_timestamp>.jpg`.
- The markdown link is inserted **immediately** before the async jobs start (same UX
  as TakePhoto — the link is there optimistically while ffmpeg runs in the background).
- If no `?t=` is present, ffmpeg grabs the frame at position 0 (no `-ss` flag).

