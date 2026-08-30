return {
  "HakonHarnes/img-clip.nvim",

  ft = { "typst" },

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
  },
}
