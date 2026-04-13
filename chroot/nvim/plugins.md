
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

