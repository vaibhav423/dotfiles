return {


    VaultInit = {
      function() require("personal.vault").init_template() end,
      desc = "Initialise vault topic template and pin directory",
    },

    VaultPin = {
      function() require("personal.vault").set_pinned() end,
      desc = "Pick and save a vault directory as pinned",
    },

    VaultOpen = {
      function() require("personal.vault").open_pinned() end,
      desc = "Open pinned topic files in splits",
    },

    YtFrame = {
      function() require("personal.ytframe").capture() end,
      desc = "Capture a frame from a YouTube URL and insert as markdown image",
    },


    EncryptBuffer = {
      function() require("personal.encryption").encrypt_buffer() end,
      desc = "Encrypt current buffer to .enc file",
    },

    DecryptBuffer = {
      function() require("personal.encryption").decrypt_buffer() end,
      desc = "Decrypt current .enc file into buffer",
    },

    ClearEncryptionPassword = {
      function() require("personal.encryption").clear_password() end,
      desc = "Clear cached encryption password",
    },

    Jeerem = {
      function() require("personal.jeerem").insert() end,
      desc = "Insert/overwrite reminder on first line",
    },
}
