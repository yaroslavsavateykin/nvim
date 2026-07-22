return {
  {
    "gen740/SmoothCursor.nvim",
    enabled = false,

    event = "VeryLazy",
    config = function()
      -- Цвета под твою тему
      vim.api.nvim_set_hl(0, "SmoothCursor", {
        fg = "#f5e0dc",
      })

      vim.api.nvim_set_hl(0, "SmoothCursorBlue", {
        fg = "#50a4e9",
      })

      vim.api.nvim_set_hl(0, "SmoothCursorGreen", {
        fg = "#87c05f",
      })

      vim.api.nvim_set_hl(0, "SmoothCursorRed", {
        fg = "#f8747e",
      })

      vim.api.nvim_set_hl(0, "SmoothCursorOrange", {
        fg = "#f9e2af",
      })

      vim.api.nvim_set_hl(0, "SmoothCursorYellow", {
        fg = "#f9e2af",
      })

      vim.api.nvim_set_hl(0, "SmoothCursorAqua", {
        fg = "#94e2d5",
      })

      vim.api.nvim_set_hl(0, "SmoothCursorPurple", {
        fg = "#cba6f7",
      })

      require("smoothcursor").setup({
        type = "default",

        -- Символ следа. Нужен Nerd Font, у тебя он уже есть.
        cursor = "",

        -- Основной цвет следа
        texthl = "SmoothCursor",

        -- Подсветка строки под курсором
        linehl = "CursorLine",
        fancy = {
          enable = true,
          head = {  texthl = "SmoothCursor", linehl = "CursorLine" },
          body = {
            { cursor = "󰝥", texthl = "SmoothCursorAqua" },
            { cursor = "●", texthl = "SmoothCursorAqua" },
            { cursor = "●", texthl = "SmoothCursorAqua" },
            { cursor = "•", texthl = "SmoothCursorAqua" },
            { cursor = ".", texthl = "SmoothCursor" },
          },
          tail = { cursor = nil, texthl = "SmoothCursor" },
        },
        -- Автозапуск
        autostart = true,

        -- Чем больше speed, тем быстрее догоняет курсор
        speed = 25,

        -- Интервал обновления анимации
        intervals = 25,

        -- След появляется только если курсор прыгнул дальше 2 строк
        threshold = 2,

        -- Чтобы не лагало в больших прыжках
        max_threshold = 120,

        -- Не включать в некоторых окнах
        disabled_filetypes = {
          "TelescopePrompt",
          "NvimTree",
          "neo-tree",
          "lazy",
          "mason",
        },
      })
    end,
  },

-- нормальный след за курсором по всему окну редактора
  {
    "sphamba/smear-cursor.nvim",
    event = "VeryLazy",
    opts = {
      -- цвет курсора под твою тему
      cursor_color = "#f5e0dc",

      -- размазывать курсор при переходе между окнами/буферами
      smear_between_buffers = true,

      -- важно: размазывать при движении внутри строки и между соседними строками
      smear_between_neighbor_lines = true,

      -- чтобы при скролле след ощущался естественнее
      scroll_buffer_space = true,

      -- работать и в insert mode
      smear_insert_mode = true,

      -- для Nerd Font / терминала обычно выглядит лучше
      legacy_computing_symbols_support = true,

      -- если видишь два курсора одновременно, это помогает
      hide_target_hack = true,

      -- скорость и длина хвоста
      stiffness = 0.8,
      trailing_stiffness = 0.45,
      distance_stop_animating = 0.5,
    },
  },
}
