return {
  -- Убираем neo-tree
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },

  -- Новый файловый менеджер
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      view = {
        side = "left",
        width = 30,
      },
      renderer = {
        group_empty = true,
      },
      filters = {
        dotfiles = false,
      },
    },
  },

  -- Всплывающий терминал

  {
    "akinsho/toggleterm.nvim",
    opts = {
      direction = "float",
      size = 15,
      -- open_mapping можно оставить nil, мы явно задаём маппинги в config
      open_mapping = nil,
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)
      local map = vim.keymap.set
      map("n", "<C-\\>", "<cmd>ToggleTerm<CR>", { noremap = true, silent = true })
      map("i", "<C-\\>", "<Esc><cmd>ToggleTerm<CR>", { noremap = true, silent = true })
      map("t", "<C-\\>", "<C-\\><C-n>:ToggleTerm<CR>", { noremap = true, silent = true })
    end,
  },
}
