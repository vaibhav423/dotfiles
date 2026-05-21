return {
  n = {
    -- tasker
    ["<Leader>rt"] = { 
      ":silent !am broadcast -a net.dinglisch.android.tasker.ACTION_TASK -e task_name youtube_img_url_mode_toggle<CR><CR>", desc = "Run Tasker task" 
    },


    -- find buffer
    ["<Leader>fb"] = {false},
    ["\\"] = {false},
    ["te"] = { function() require("snacks").picker.buffers() end, desc = "Find buffers" },

    -- Open gallery path in MixPlorer via Android intent
    ["<Leader>gg"] = {
      function() require("personal.takephoto").open_gallery() end,
      desc = "Open gallery path in MixPlorer",
    },
  },


  v = {
    -- Copy images from visually selected lines to a temp dir and open in MixPlorer
    ["<Leader>gg"] = {
      ":<C-u>'<,'>OpenImages<CR>",
      desc = "Copy selected images to tmp dir and open in MixPlorer",
    },
  },
}
