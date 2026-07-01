local function show_lsp_hover()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })

  for _, client in ipairs(clients) do
    if client.server_capabilities.hoverProvider then
      vim.lsp.buf.hover({
        border = "rounded",
        max_width = 80,
        max_height = 25,
      })
      return
    end
  end

  vim.notify(
    "Python LSP не подключён. Проверь :LspInfo и :Mason",
    vim.log.levels.WARN
  )
end

return {
  {
    "AstroNvim/astrocore",
    opts = {
      mappings = {
        n = {
          ["K"] = {
            show_lsp_hover,
            desc = "Показать документацию LSP",
          },
        },
      },
    },
  },
}
