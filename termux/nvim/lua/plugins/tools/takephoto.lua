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

    opts.commands["OpenImages"] = {
      function(args)
        local cwd = vim.fn.getcwd()
        local lines = vim.api.nvim_buf_get_lines(0, args.line1 - 1, args.line2, false)

        local seen = {}
        local paths = {}
        for _, line in ipairs(lines) do
          for path in line:gmatch("!%[.-%]%((.-)%)") do
            if not seen[path] then
              seen[path] = true
              table.insert(paths, path)
            end
          end
        end

        if #paths == 0 then
          vim.notify("OpenImages: no image paths found in selection", vim.log.levels.WARN)
          return
        end

        local tmp_dir = "/sdcard/tmp"
        vim.fn.system(string.format("mkdir -p %s && rm -rf %s/*", vim.fn.shellescape(tmp_dir), vim.fn.shellescape(tmp_dir)))

        local copied = 0
        for _, rel_or_abs in ipairs(paths) do
          local abs_path = rel_or_abs:sub(1, 1) == "/" and rel_or_abs or (cwd .. "/" .. rel_or_abs)
          if vim.fn.filereadable(abs_path) == 1 then
            vim.fn.system(string.format("cp %s %s/",
              vim.fn.shellescape(abs_path), vim.fn.shellescape(tmp_dir)))
            copied = copied + 1
          end
        end

        if copied == 0 then
          vim.notify("OpenImages: no readable files found", vim.log.levels.WARN)
          return
        end

        vim.fn.system(string.format(
          'am start -a android.intent.action.VIEW -d "file://%s" -t "resource/folder" com.mixplorer',
          tmp_dir
        ))
        vim.notify(string.format("OpenImages: copied %d file(s) → %s", copied, tmp_dir), vim.log.levels.INFO)
      end,
      range = true,
      desc = "Copy images from line range to tmp dir and open in MixPlorer",
    }
  end,
}
