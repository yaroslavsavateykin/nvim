return {
  {
    "linux-cultist/venv-selector.nvim",
    cmd = { "VenvSelect", "VenvSelectCache" },
    dependencies = { "neovim/nvim-lspconfig", "nvim-telescope/telescope.nvim" },
    keys = { { ",v", "<cmd>VenvSelect<cr>", desc = "Select Python environment" } },
    opts = {
      options = { enable_default_searches = false, cached_venv_automatic_activation = false },
      search = {
        project = { command = "$FD '/bin/python$' $CWD --hidden --no-ignore --max-depth 5 --exclude node_modules --exclude .git" },
      },
    },
  },
}
