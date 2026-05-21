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
      function(args) require("personal.takephoto").OpenImages(args) end,
      desc = "open multiple imgs",
      range = true,
    },

}
