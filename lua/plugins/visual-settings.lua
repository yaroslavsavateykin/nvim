return {
  -- Отключаем стандартный Neo-tree из AstroNvim
  {
    "nvim-neo-tree/neo-tree.nvim",
    enabled = false,
  },

  -- Файловый менеджер
  {
    "nvim-tree/nvim-tree.lua",

    -- Плагин должен загрузиться до VimEnter,
    -- чтобы правильно обработать `nvim .` и `nvim file`
    lazy = false,

    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },

    keys = {
      {
        "<leader>e",
        "<cmd>NvimTreeToggle<cr>",
        desc = "Открыть или закрыть файловый менеджер",
      },
      {
        "<leader>o",
        "<cmd>NvimTreeFocus<cr>",
        desc = "Перейти в файловый менеджер",
      },
    },

    opts = {
      disable_netrw = true,
      hijack_netrw = true,

      -- Директории обрабатывает наш VimEnter ниже,
      -- поэтому автоматическое открытие здесь отключено
      hijack_directories = {
        enable = true,
        auto_open = false,
      },

      sync_root_with_cwd = true,
      respect_buf_cwd = true,

      -- Подсвечивать текущий открытый файл в дереве
      update_focused_file = {
        enable = true,
        update_root = false,
      },

      view = {
        side = "left",
        width = 30,
        preserve_window_proportions = true,
      },

      filters = {
        -- Показывать скрытые файлы вида .env
        dotfiles = false,

        -- Показывать файлы из .gitignore
        git_ignored = false,

        custom = {},
        exclude = {},
      },

      git = {
        enable = true,
        ignore = false,
        timeout = 400,
      },

      renderer = {
        group_empty = true,

        -- Окрашивать только маленький Git-значок,
        -- а не всё имя файла
        highlight_git = "name",

        icons = {
          show = {
            file = true,
            folder = true,
            folder_arrow = true,
            git = true,
          },

          glyphs = {
            git = {
              -- unstaged = "●",
              staged = "✓",
              unmerged = "",
              renamed = "➜",
              untracked = "★",
              deleted = "",
              ignored = "◌",
            },
          },
        },
      },

      actions = {
        open_file = {
          -- При открытии файла дерево остаётся слева
          quit_on_open = false,

          -- Не менять размеры остальных окон
          resize_window = true,

          window_picker = {
            enable = true,
          },
        },
      },
    },

    config = function(_, opts)
      require("nvim-tree").setup(opts)

      local api = require("nvim-tree.api")

      ------------------------------------------------------------------------
      -- Оформление файлов из .gitignore
      ------------------------------------------------------------------------

      local function set_nvim_tree_highlights()
        vim.api.nvim_set_hl(0, "NvimTreeGitIgnoredIcon", {
          link = "Comment",
        })

        vim.api.nvim_set_hl(0, "NvimTreeGitFileIgnoredHL", {
          link = "Comment",
        })

        vim.api.nvim_set_hl(0, "NvimTreeGitFolderIgnoredHL", {
          link = "Comment",
        })
      end

      set_nvim_tree_highlights()

      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = set_nvim_tree_highlights,
      })

      ------------------------------------------------------------------------
      -- Автоматическое открытие дерева
      ------------------------------------------------------------------------

      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,

        callback = function(data)
          -- Берём первый аргумент командной строки:
          --
          -- nvim .
          -- nvim main.go
          -- nvim ~/project
          local startup_path = vim.fn.argv(0)

          -- При обычном запуске `nvim` без аргументов
          -- оставляем стандартный стартовый экран AstroNvim
          if startup_path == nil or startup_path == "" then
            return
          end

          vim.schedule(function()
            ----------------------------------------------------------------
            -- Случай: nvim .
            -- Или: nvim /путь/к/проекту
            ----------------------------------------------------------------

            if vim.fn.isdirectory(startup_path) == 1 then
              local directory =
                vim.fn.fnamemodify(startup_path, ":p")

              local directory_buffer = data.buf
              local editor_window = vim.api.nvim_get_current_win()

              -- Устанавливаем открытую директорию
              -- как рабочую директорию Neovim
              vim.cmd.cd(vim.fn.fnameescape(directory))

              -- Создаём обычный пустой буфер справа
              vim.cmd.enew()

              local empty_buffer = vim.api.nvim_get_current_buf()

              -- Удаляем технический буфер директории
              if
                vim.api.nvim_buf_is_valid(directory_buffer)
                and directory_buffer ~= empty_buffer
              then
                pcall(
                  vim.api.nvim_buf_delete,
                  directory_buffer,
                  { force = true }
                )
              end

              -- Открываем дерево слева
              api.tree.open({
                path = directory,
                focus = false,
              })

              -- Возвращаем курсор в редактор справа
              if vim.api.nvim_win_is_valid(editor_window) then
                vim.api.nvim_set_current_win(editor_window)
              end

              return
            end

            ----------------------------------------------------------------
            -- Случай: nvim main.go
            -- Файл остаётся справа, дерево открывается слева
            ----------------------------------------------------------------

            local editor_window = vim.api.nvim_get_current_win()
            local root_directory = vim.fn.getcwd()

            api.tree.open({
              path = root_directory,
              focus = false,
            })

            -- Находим и подсвечиваем открытый файл в дереве
            api.tree.find_file({
              open = true,
              focus = false,
            })

            -- Оставляем курсор в открытом файле
            if vim.api.nvim_win_is_valid(editor_window) then
              vim.api.nvim_set_current_win(editor_window)
            end
          end)
        end,
      })
    end,
  },

  -- Всплывающий терминал
  {
    "akinsho/toggleterm.nvim",

    opts = {
      direction = "float",
      size = 15,
      open_mapping = nil,
    },

    config = function(_, opts)
      require("toggleterm").setup(opts)

      local map = vim.keymap.set

      map(
        "n",
        "<C-\\>",
        "<cmd>ToggleTerm<cr>",
        {
          noremap = true,
          silent = true,
          desc = "Открыть терминал",
        }
      )

      map(
        "i",
        "<C-\\>",
        "<Esc><cmd>ToggleTerm<cr>",
        {
          noremap = true,
          silent = true,
          desc = "Открыть терминал",
        }
      )

      map(
        "t",
        "<C-\\>",
        "<C-\\><C-n><cmd>ToggleTerm<cr>",
        {
          noremap = true,
          silent = true,
          desc = "Закрыть терминал",
        }
      )
    end,
  },
}
