-- Custom configuration for image.nvim to work with Obsidian vaults
return {
  "3rd/image.nvim",
  opts = {
    backend = "kitty", -- or "ueberzug" if you prefer
    integrations = {
      markdown = {
        enabled = true,
        clear_in_insert_mode = false,
        download_remote_images = true,
        only_render_image_at_cursor = true,
        filetypes = { "markdown", "vimwiki" },
        resolve_image_path = function(document_path, image_path, fallback)
          -- For Obsidian vaults, resolve paths from the vault root
          local vault_root = vim.fn.expand("~/Water/Fire")
          
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
        end,
      },
    },
    max_width = nil,
    max_height = nil,
    max_width_window_percentage = nil,
    max_height_window_percentage = 50,
    window_overlap_clear_enabled = false,
    window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
    editor_only_render_when_focused = false,
    tmux_show_only_in_active_window = false,
    hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
  },
}
