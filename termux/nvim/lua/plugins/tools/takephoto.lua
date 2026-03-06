-- plugins/tools/takephoto.lua
-- Registers :TakePhoto and :EditPhoto commands.

return {
  "AstroNvim/astrocore",
  opts = function(_, opts)
    opts.commands = opts.commands or {}

    opts.commands["TakePhoto"] = {
      function() require("lib.takephoto").take() end,
      desc = "Take photo and insert markdown link at current line",
    }

    opts.commands["EditPhoto"] = {
      function() require("lib.takephoto").edit() end,
      desc = "Edit photo under cursor in Picsart, update markdown link",
    }
  end,
}
