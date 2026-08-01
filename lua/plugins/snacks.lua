-- ~/.config/nvim/lua/plugins/snacks-image.lua

return {
  "r-pletnev/pdfreader.nvim",

  lazy = false,

  dependencies = {
    "folke/snacks.nvim",
    "nvim-telescope/telescope.nvim",
  },

  config = function()
    require("pdfreader").setup()

    local group = vim.api.nvim_create_augroup(
      "pdfreader_user",
      { clear = true }
    )

    -- Ручное обновление текущей страницы
    vim.api.nvim_create_autocmd("BufEnter", {
      group = group,
      pattern = "*.pdf",

      callback = function(args)
        vim.keymap.set(
          "n",
          "r",
          "<cmd>PDFReader redrawPage<cr>",
          {
            buffer = args.buf,
            silent = true,
            desc = "Обновить страницу PDF",
          }
        )
      end,
    })

    -- Проверять, не пересобрался ли PDF снаружи
    vim.opt.autoread = true

    vim.api.nvim_create_autocmd({
      "FocusGained",
      "BufEnter",
      "CursorHold",
      "CursorHoldI",
    }, {
      group = group,

      callback = function()
        vim.cmd("silent! checktime")
      end,
    })

    -- Перерисовать PDF после изменения файла на диске
    vim.api.nvim_create_autocmd("FileChangedShellPost", {
      group = group,
      pattern = "*.pdf",

      callback = function(args)
        vim.api.nvim_buf_call(args.buf, function()
          vim.cmd("silent! PDFReader redrawPage")
        end)
      end,
    })
  end,
}
