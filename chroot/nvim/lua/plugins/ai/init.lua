return {
  { import = "plugins.ai.copilot" },
  { import = "plugins.ai.copilotchat" },
  { import = "plugins.ai.cmp_ai" },
  {
    'nvim-telescope/telescope.nvim', version = '*',
    dependencies = {
        'nvim-lua/plenary.nvim',
        -- optional but recommended
        { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    }
  },
}
