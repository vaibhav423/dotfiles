return {

    TakePhoto = {
      function() require("lib.takephoto").take() end,
      desc = "Take photo and insert markdown link at current line",
    },

    EditPhoto = {
      function() require("lib.takephoto").edit() end,
      desc = "Edit photo under cursor in Picsart, update markdown link",
    },

    VaultInit = {
      function() require("lib.vault").init_template() end,
      desc = "Initialise vault topic template and pin directory",
    },

    VaultPin = {
      function() require("lib.vault").set_pinned() end,
      desc = "Pick and save a vault directory as pinned",
    },

    VaultOpen = {
      function() require("lib.vault").open_pinned() end,
      desc = "Open pinned topic files in splits",
    },

    YtFrame = {
      function() require("lib.ytframe").capture() end,
      desc = "Capture a frame from a YouTube URL and insert as markdown image",
    },

    OpenImages = {
      function(opts) require("lib.takephoto").OpenImages(opts) end,
      desc = "open multiple imgs",
      range = true,
    },

    EncryptBuffer = {
      function() require("lib.encryption").encrypt_buffer() end,
      desc = "Encrypt current buffer to .enc file",
    },

    DecryptBuffer = {
      function() require("lib.encryption").decrypt_buffer() end,
      desc = "Decrypt current .enc file into buffer",
    },

    ClearEncryptionPassword = {
      function() require("lib.encryption").clear_password() end,
      desc = "Clear cached encryption password",
    },

    Jeerem = {
      function() require("lib.jeerem").insert() end,
      desc = "Insert/overwrite reminder on first line",
    },
}
