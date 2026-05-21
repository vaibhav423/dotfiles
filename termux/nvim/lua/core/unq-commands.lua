-- termux/nvim/lua/core/unq-commands.lua
-- Termux-specific commands that extend common.core.commands.

return {
  TakePhoto = {
    function() require("personal.takephoto").take() end,
    desc = "Take photo and insert markdown link at current line",
  },

  EditPhoto = {
    function() require("personal.takephoto").edit() end,
    desc = "Edit photo under cursor in Picsart, update markdown link",
  },

  OpenImages = {
    function() require("personal.takephoto").OpenImages() end,
    desc = "open multiple imgs",
  },
}
