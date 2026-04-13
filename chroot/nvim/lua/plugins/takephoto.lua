-- plugins/tools/takephoto.lua
-- Registers :TakePhoto, :EditPhoto, and :OpenImages commands.

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

    opts.commands["VaultInit"] = {
      function() require("lib.vault").init_template() end,
      desc = "Initialise vault topic template and pin directory",
    }

    opts.commands["VaultPin"] = {
      function() require("lib.vault").set_pinned() end,
      desc = "Pick and save a vault directory as pinned",
    }

    opts.commands["VaultOpen"] = {
      function() require("lib.vault").open_pinned() end,
      desc = "Open pinned topic files in splits",
    }

    opts.commands["YtFrame"] = {
      function() require("lib.ytframe").capture() end,
      desc = "Capture a frame from a YouTube URL and insert as markdown image",
    }

    opts.commands["OpenImages"] = {
      function() require("lib.takephoto").OpenImages() end,
      desc = "open multiple imgs",
    }
  end,
}
