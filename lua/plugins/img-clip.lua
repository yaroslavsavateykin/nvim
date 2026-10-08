return {
  "HakonHarnes/img-clip.nvim",

  ft = { "typst" },

  init = function()
    local function capture_selection()
      local command

      if vim.env.WAYLAND_DISPLAY and vim.fn.executable "grim" == 1 and vim.fn.executable "slurp" == 1 and vim.fn.executable "wl-copy" == 1 then
        command = "grim -g \"$(slurp)\" - | wl-copy --type image/png"
      elseif vim.fn.executable "maim" == 1 and vim.fn.executable "xclip" == 1 then
        command = "maim -s | xclip -selection clipboard -target image/png -i"
      else
        vim.notify("Для снимка области установите grim slurp wl-clipboard (Wayland) или maim xclip (X11)", vim.log.levels.ERROR)
        return
      end

      vim.fn.system(command)
      if vim.v.shell_error ~= 0 then
        vim.notify("Не удалось создать снимок выбранной области", vim.log.levels.ERROR)
        return
      end

      vim.cmd "PasteImage"
    end

    vim.api.nvim_create_user_command("PasteScreenshotSelection", capture_selection, {})
  end,

  opts = function()
    local function current_file_dir()
      local file = vim.api.nvim_buf_get_name(0)

      if file == "" then
        return vim.fn.getcwd()
      end

      return vim.fs.dirname(file)
    end

    local function image_dir()
      local current_dir = current_file_dir()

      -- Ищем ближайший main.typ вверх по дереву
      local main = vim.fs.find("main.typ", {
        path = current_dir,
        upward = true,
        type = "file",
      })[1]

      if main then
        -- Проект Typst:
        --
        -- project/
        -- ├── main.typ
        -- ├── chapters/
        -- └── figures/
        return vim.fs.joinpath(
          vim.fs.dirname(main),
          "figures"
        )
      end

      -- main.typ нет:
      -- сохраняем изображение рядом с текущим .typ
      return current_dir
    end

    return {
      default = {
        dir_path = function()
          -- img-clip работает удобнее с путём относительно cwd.
          -- В самом Typst путь затем будет пересчитан
          -- относительно текущего .typ файла.
          return vim.fn.fnamemodify(image_dir(), ":.")
        end,

        extension = "png",

        -- Например:
        -- screenshot-20260821-175423.png
        file_name = "screenshot-%Y%m%d-%H%M%S",

        prompt_for_file_name = false,

        use_absolute_path = false,

        -- Мы сами определяем место хранения
        relative_to_current_file = false,

        -- А путь в #image(...) должен быть
        -- относительно текущего .typ файла.
        relative_template_path = true,

        embed_image_as_base64 = false,

        insert_mode_after_paste = true,
      },

      filetypes = {
        typst = {
          template = '#image("$FILE_PATH")',
        },
      },
    }
  end,

  keys = {
    {
      "<leader>ip",
      "<cmd>PasteImage<cr>",
      mode = { "n", "i" },
      desc = "Paste clipboard image",
    },
    {
      "<A-S-s>",
      "<cmd>PasteScreenshotSelection<cr>",
      mode = { "n", "i" },
      desc = "Capture selected screen area",
    },
  },
}
