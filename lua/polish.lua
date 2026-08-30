vim.api.nvim_create_autocmd("FileType", {
  pattern = { "tex", "plaintex" },
  callback = function()
    vim.opt_local.textwidth = 80
    vim.opt_local.colorcolumn = "80"
    vim.opt_local.formatoptions:append("t")
  end,
})

-- This will run last in the setup process.
-- This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here
