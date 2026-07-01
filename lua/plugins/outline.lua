return {
  -- Полностью отключаем старый Aerial
  {
    "stevearc/aerial.nvim",
    enabled = false,
  },

  -- Ставим новую панель структуры файла
  {
    "hedyhli/outline.nvim",

    cmd = {
      "Outline",
      "OutlineOpen",
      "OutlineClose",
      "OutlineFocus",
      "OutlineRefresh",
      "OutlineStatus",
    },

    keys = {
      {
        "<leader>o",
        "<cmd>Outline<CR>",
        desc = "Открыть структуру файла",
      },
    },

    opts = {
      outline_window = {
        position = "right",
        width = 30,
        relative_width = false,

        auto_close = false,
        auto_jump = false,
        center_on_jump = true,

        focus_on_open = true,
        show_cursorline = true,
        wrap = false,
      },

      outline_items = {
        show_symbol_details = true,
        show_symbol_lineno = true,
        highlight_hovered_item = true,
        auto_set_cursor = true,
      },

      symbol_folding = {
        -- При открытии показать всю структуру
        autofold_depth = false,

        auto_unfold = {
          hovered = true,
          only = false,
        },
      },

      preview_window = {
        auto_preview = false,
        open_hover_on_preview = false,
        border = "rounded",
      },

      -- Используем LSP, Markdown и man.
      -- Общий Tree-sitter-провайдер не подключаем.
      providers = {
        priority = {
          "lsp",
          "markdown",
          "man",
        },

        lsp = {
          blacklist_clients = {},
        },
      },
    },
  },
}
