-- ~/.config/nvim/lua/plugins/snacks-image.lua

return {{
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,

  opts = {
    image = {
      enabled = true,
    },
  },
},
}
