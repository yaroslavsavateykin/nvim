vim.api.nvim_create_autocmd("FileType", {
  pattern = { "tex", "plaintex", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true

    if vim.bo.filetype == "tex" or vim.bo.filetype == "plaintex" then
      vim.opt_local.textwidth = 80
      vim.opt_local.colorcolumn = "80"
      vim.opt_local.formatoptions:append("t")
    end
  end,
})

-- This will run last in the setup process.
-- This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

local firefly_runtime = "/home/yaroslav/firefly_parse-rs/editors/neovim"
if vim.fn.isdirectory(firefly_runtime) == 1 then
  vim.opt.rtp:append(firefly_runtime)
  vim.cmd("runtime! plugin/firefly.lua")
end
