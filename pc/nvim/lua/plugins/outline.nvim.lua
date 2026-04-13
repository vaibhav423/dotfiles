-- Plugin: hedyhli/outline.nvim
-- Installed via store.nvim

return {
    "hedyhli/outline.nvim",
    config = function()
        -- Example mapping to toggle outline
        vim.keymap.set(
            "n",
            "<leader>Oo",
            "<cmd>Outline<CR>",
            {
                desc = "Toggle Outline"
            }
        )

        require("outline").setup {}
    end
}