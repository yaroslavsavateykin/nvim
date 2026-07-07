return {
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    opts = {
      cmdline = {
        enabled = true,
        -- view = "cmdline", -- обычная командная строка снизу
      },

      messages = {
        enabled = true,
      },

      popupmenu = {
        enabled = false, -- не перехватывать подсказки команд
      },

      notify = {
        enabled = true,
      },

      presets = {
        bottom_search = true,
        command_palette = false, -- важно
        long_message_to_split = true,
        lsp_doc_border = true,
      },
    },
  }
}
