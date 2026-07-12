return {
  -- Всплывающие терминалы
{
  "akinsho/toggleterm.nvim",
  opts = {
    direction = "float",
    open_mapping = nil,

    start_in_insert = true,
    persist_mode = true,
    close_on_exit = true,

    float_opts = {
      border = "curved",

      width = function()
        return math.floor(vim.o.columns * 0.85)
      end,

      height = function()
        return math.floor(vim.o.lines * 0.80)
      end,

      winblend = 0,
      title_pos = "center",
    },
  },

  config = function(_, opts)
    require("toggleterm").setup(opts)

    local map = vim.keymap.set

    ------------------------------------------------------------------------
    -- Открытие терминалов
    ------------------------------------------------------------------------

    -- Ctrl+\ открывает терминал с указанным номером.
    --
    -- Ctrl+\     -> терминал 1
    -- 2 Ctrl+\   -> терминал 2
    -- 3 Ctrl+\   -> терминал 3
    map("n", "<C-\\>", function()
      vim.cmd(vim.v.count1 .. "ToggleTerm direction=float")
    end, {
      silent = true,
      desc = "Открыть терминал",
    })

    map("i", "<C-\\>", "<Esc><cmd>ToggleTerm direction=float<cr>", {
      silent = true,
      desc = "Открыть терминал",
    })

    map("t", "<C-\\>", "<C-\\><C-n><cmd>ToggleTerm<cr>", {
      silent = true,
      desc = "Закрыть терминал",
    })

    ------------------------------------------------------------------------
    -- Управление несколькими терминалами
    ------------------------------------------------------------------------

    for number = 1, 4 do
      map("n", "<Leader>t" .. number, function()
        vim.cmd(number .. "ToggleTerm direction=float")
      end, {
        silent = true,
        desc = "Терминал " .. number,
      })
    end

    map("n", "<Leader>tn", "<cmd>TermNew direction=float<cr>", {
      silent = true,
      desc = "Новый терминал",
    })

    map("n", "<Leader>ts", "<cmd>TermSelect<cr>", {
      silent = true,
      desc = "Выбрать терминал",
    })

    map("n", "<Leader>tr", "<cmd>ToggleTermSetName<cr>", {
      silent = true,
      desc = "Переименовать терминал",
    })

    ------------------------------------------------------------------------
    -- Изменение размера плавающего терминала
    ------------------------------------------------------------------------

    local function resize_float(width_delta, height_delta)
      local window = vim.api.nvim_get_current_win()
      local config = vim.api.nvim_win_get_config(window)

      -- Не изменяем обычные окна и split-терминалы.
      if config.relative == "" then
        return
      end

      local width = math.max(
        40,
        math.min(vim.o.columns - 4, config.width + width_delta)
      )

      local height = math.max(
        10,
        math.min(vim.o.lines - 4, config.height + height_delta)
      )

      config.width = width
      config.height = height

      -- После изменения размера снова центрируем окно.
      config.col = math.max(
        0,
        math.floor((vim.o.columns - width) / 2)
      )

      config.row = math.max(
        0,
        math.floor((vim.o.lines - height - 2) / 2)
      )

      vim.api.nvim_win_set_config(window, config)
    end

    map({ "n", "t" }, "<M-h>", function()
      resize_float(-4, 0)
    end, {
      silent = true,
      desc = "Уменьшить ширину терминала",
    })

    map({ "n", "t" }, "<M-l>", function()
      resize_float(4, 0)
    end, {
      silent = true,
      desc = "Увеличить ширину терминала",
    })

    map({ "n", "t" }, "<M-j>", function()
      resize_float(0, -2)
    end, {
      silent = true,
      desc = "Уменьшить высоту терминала",
    })

    map({ "n", "t" }, "<M-k>", function()
      resize_float(0, 2)
    end, {
      silent = true,
      desc = "Увеличить высоту терминала",
    })
  end,
},
}
