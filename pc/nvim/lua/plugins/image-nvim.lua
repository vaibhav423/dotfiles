-- Custom configuration for image.nvim to work with Obsidian vaults
-- https://github.com/3rd/image.nvim
-- https://github.com/AstroNvim/astrocommunity/blob/main/lua/astrocommunity/media/image-nvim/init.lua
-- return {
--   "3rd/image.nvim",
--   opts = {
--     backend = "sixel", -- or "ueberzug" if you prefer
--     integrations = {
--       markdown = {
--         enabled = true,
--         clear_in_insert_mode = false,
--         download_remote_images = true,
--         only_render_image_at_cursor = true,
--         filetypes = { "markdown", "vimwiki" },
--         resolve_image_path = function(document_path, image_path, fallback)
--           -- For Obsidian vaults, resolve paths from the vault root
--           local vault_root = vim.fn.expand("~/Water/Fire")
--
--           -- If the path is already absolute, use it as-is
--           if image_path:sub(1, 1) == "/" or image_path:sub(1, 1) == "~" then
--             return fallback(document_path, image_path)
--           end
--
--           -- Try resolving from vault root (Obsidian-style)
--           local vault_path = vault_root .. "/" .. image_path
--           if vim.fn.filereadable(vault_path) == 1 then
--             return vault_path
--           end
--
--           -- Fall back to default resolution (relative to document)
--           return fallback(document_path, image_path)
--         end,
--       },
--     },
--     max_width = nil,
--     max_height = nil,
--     max_width_window_percentage = nil,
--     max_height_window_percentage = 50,
--     window_overlap_clear_enabled = false,
--     window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
--     editor_only_render_when_focused = false,
--     tmux_show_only_in_active_window = false,
--     hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
--   },
-- }
return {
  "3rd/image.nvim",
  event = "VeryLazy",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "https://github.com/leafo/magick",
  },
  specs = {
    {
      "AstroNvim/astrocore",
      optional = true,
      ---@type AstroCoreOpts
      opts = {
        treesitter = { ensure_installed = { "markdown", "markdown_inline" } },
      },
    },
  },
  opts = {
    backend = "sixel",
    integrations = {
      markdown = {
        enabled = true,
        clear_in_insert_mode = false,
        download_remote_images = true,
        filetypes = { "markdown", "vimwiki" }, -- markdown extensions (ie. quarto) can go here
        processor = "magick_cli",
        only_render_image_at_cursor = true,
        only_render_image_at_cursor_mode="popup", --inline or popup
        floating_windows = true,
        resolve_image_path = (function()
          -- Hoist vault_root expansion: vim.fn.expand is called once at plugin
          -- load time instead of on every image render.
          local vault_root = vim.fn.expand("~/Water/Fire")
          return function(document_path, image_path, fallback)
          -- For Obsidian vaults, resolve paths from the vault root

          -- If the path is already absolute, use it as-is
          if image_path:sub(1, 1) == "/" or image_path:sub(1, 1) == "~" then
            return fallback(document_path, image_path)
          end

          -- Try resolving from vault root (Obsidian-style)
          local vault_path = vault_root .. "/" .. image_path
          if vim.fn.filereadable(vault_path) == 1 then
            return vault_path
          end

          -- Fall back to default resolution (relative to document)
          return fallback(document_path, image_path)
          end
        end)(),

      },
      neorg = {
        enabled = true,
        clear_in_insert_mode = false,
        download_remote_images = true,
        only_render_image_at_cursor = false,
        filetypes = { "norg" },
      },
    },
    max_width = nil,
    max_height = nil,
    max_width_window_percentage = nil,
    max_height_window_percentage = nil, -- was 50
    -- kitty_method = "normal",
    hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp" }, -- render image files as images when opened
  },
  config = function(_, opts)
    require("image").setup(opts)

    -- ==========================================================================
    -- WHY THIS PATCH EXISTS (image popup sizing)
    -- ==========================================================================
    -- render_popup_image (lua/image/utils/document.lua) hard-codes the popup
    -- width to floor(screen_cols / 2) and derives height from the aspect ratio,
    -- with image.ignore_global_max_size = true -> no height clamp. Tall/portrait
    -- images in wide terminals are over-scaled and clipped at the bottom.
    --
    -- Patch, not edit: the plugin lives under .local/share/nvim/lazy/image.nvim
    -- and is reverted on every `:Lazy update`. Every caller resolves
    -- utils.math.adjust_to_aspect_ratio on its module table at call time (never
    -- captured into a local), so swapping the exported field is safe.
    --
    -- Only the branch height == 0 and width ~= 0 is intercepted - that exact
    -- combination is used solely by the popup sizing. Other call sites (renderer.lua
    -- aspect fix-up ~line 211, inline/neorg integrations, file hijacking) pass both
    -- nonzero dims and fall through to the original.
    --
    -- The replacement contain-fits the image inside
    -- (half terminal width) x (80% terminal height - 2 border cells), preserving
    -- aspect. math.max(1, ...) guards against a pathologically small terminal.
    -- ==========================================================================
    local math_utils = require "image/utils/math"
    local original_adjust_to_aspect_ratio = math_utils.adjust_to_aspect_ratio
    math_utils.adjust_to_aspect_ratio = function(term_size, image_width, image_height, width, height)
      if height == 0 and width ~= 0 then
        local max_width_px = width * term_size.cell_width
        local max_height_px = math.max(1, math.floor(term_size.screen_rows * 0.8) - 2) * term_size.cell_height
        local scale = math.min(max_width_px / image_width, max_height_px / image_height)
        return math.max(1, math.floor(image_width * scale / term_size.cell_width)),
          math.max(1, math.floor(image_height * scale / term_size.cell_height))
      end
      return original_adjust_to_aspect_ratio(term_size, image_width, image_height, width, height)
    end

    -- ==========================================================================
    -- WHY THE POPUP IS RECENTERED
    -- ==========================================================================
    -- render_popup_image anchors the popup below the cursor
    -- (win_config = { relative = "cursor", row = 1 }), so its size is bounded by
    -- the distance from the cursor to the terminal bottom; the contain-fit above
    -- shrank it to a sliver when the cursor sat low. We re-anchor it to terminal
    -- center (relative = "editor") after creation.
    --
    -- Why an autocmd + deferred callback instead of patching:
    --   render_popup_image is a local closure in document.lua and its window
    --   position is only set at creation, so "WinNew" is the only intercept point.
    --   It fires while the window is still being created - not yet in
    --   nvim_list_wins() - so a 0-delay defer_fn runs after the window is
    --   registered but BEFORE the plugin's own 10ms deferred render reads its
    --   geometry. The buffer filetype "image_nvim_popup" is unique to this plugin,
    --   so no other floating window is affected.
    --
    -- Coordinate notes: vim.o.lines/columns are terminal size in cells; row/col for
    -- relative = "editor" are 1-indexed top-left including the border; width/height
    -- include the border, so floor((size - win) / 2) + 1 centers the window.
    -- ==========================================================================
    vim.api.nvim_create_autocmd("WinNew", {
      group = vim.api.nvim_create_augroup("image_nvim_center_popup", { clear = true }),
      callback = function()
        vim.defer_fn(function()
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_is_valid(win) then
              local buf = vim.api.nvim_win_get_buf(win)
              if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "image_nvim_popup" then
                local cfg = vim.api.nvim_win_get_config(win)
                if cfg.relative ~= "" and cfg.relative ~= "editor" then
                  local rows, cols = vim.o.lines, vim.o.columns
                  vim.api.nvim_win_set_config(win, {
                    relative = "editor",
                    row = math.max(1, math.floor((rows - cfg.height) / 2) + 1),
                    col = math.max(1, math.floor((cols - cfg.width) / 2) + 1),
                  })
                end
                break -- popup found; no need to keep iterating windows
              end
            end
          end
        end, 0)
      end,
    })
  end,
}
