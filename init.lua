-- This file simply bootstraps the installation of Lazy.nvim and then calls other files for execution
-- This file doesn't necessarily need to be touched, BE CAUTIOUS editing this file and proceed at your own risk.
local lazypath = vim.env.LAZY or vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not (vim.env.LAZY or (vim.uv or vim.loop).fs_stat(lazypath)) then
  -- stylua: ignore
  local result = vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
  if vim.v.shell_error ~= 0 then
    -- stylua: ignore
    vim.api.nvim_echo({ { ("Error cloning lazy.nvim:\n%s\n"):format(result), "ErrorMsg" }, { "Press any key to exit...", "MoreMsg" } }, true, {})
    vim.fn.getchar()
    vim.cmd.quit()
  end
end

vim.opt.rtp:prepend(lazypath)

-- validate that lazy is available
if not pcall(require, "lazy") then
  -- stylua: ignore
  vim.api.nvim_echo({ { ("Unable to load lazy from: %s\n"):format(lazypath), "ErrorMsg" }, { "Press any key to exit...", "MoreMsg" } }, true, {})
  vim.fn.getchar()
  vim.cmd.quit()
end


-- MUST be set before lazy.nvim / AstroNvim loads
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require "lazy_setup"
require "polish"

-- Сохранять выделение после смещения
vim.api.nvim_set_keymap("v", ">", ">gv", { noremap = true })
vim.api.nvim_set_keymap("v", "<", "<gv", { noremap = true })

-- Настройка буфера обмена
-- Принудительно используем OSC52 как clipboard


-- И делаем unnamedplus по умолчанию
vim.opt.clipboard = 'unnamedplus'  -- для Linux
-- vim.opt.clipboard = 'unnamed'   -- для macOS
-- vim.opt.clipboard = 'unnamedplus'  -- для Windows

-- Или более полная настройка
vim.opt.clipboard:append({ 'unnamed', 'unnamedplus' })


-- =========================
-- HARD LSP INIT (DEBUG SAFE)
-- =========================

-- mouse
vim.o.mouse = "a"

-- helpers
local map = vim.keymap.set

-- LSP basic bindings
map("n", "K", function()
  vim.lsp.buf.hover()
end, { desc = "LSP Hover" })

map("n", "gd", function()
  vim.lsp.buf.definition()
end, { desc = "LSP Goto Definition" })

map("n", "<leader>cr", function()
  vim.lsp.buf.rename()
end, { desc = "LSP Rename" })

map("n", "<leader>ca", function()
  vim.lsp.buf.code_action()
end, { desc = "LSP Code Action" })

-- mouse hover
map("n", "<RightMouse>", function()
  vim.lsp.buf.hover()
end, { desc = "LSP Hover (mouse)" })


-- FOLDS SETTIGNS
vim.opt.viewoptions = { "cursor", "folds", "slash", "unix" }



vim.api.nvim_create_augroup("remember_folds", { clear = true })

vim.api.nvim_create_autocmd("BufWinLeave", {
  group = "remember_folds",
  pattern = "*",
  command = "silent! mkview",
})

vim.api.nvim_create_autocmd("BufWinEnter", {
  group = "remember_folds",
  pattern = "*",
  command = "silent! loadview",
})
