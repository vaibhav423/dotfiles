return {
  i = {

  },

  t = {

  },

  n ={
    
    ["<Leader>ga"] = {function() require("personal.photo").open_gallery() end, desc = "Open gallery with nsxiv"},
    ["<Leader>pp"] = {function() require("personal.photo").paste_image() end, desc = "Paste image from clipboard"},
    ["<Leader>it"] = {
      function()
        local img = require("image")
        if img.is_enabled() then
          img.disable()
          vim.notify("Images Disabled", vim.log.levels.INFO)
        else
          img.enable()
          vim.notify("Images Enabled", vim.log.levels.INFO)
        end
      end,
      desc = "Toggle image rendering",
    },
  },

  v = {

  },
}
