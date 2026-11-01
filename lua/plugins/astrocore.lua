-- Activate only the real policy, not the template's example mappings/filetypes.
return {
  "AstroNvim/astrocore",
  opts = {
    features = { large_buf = { size = 2 * 1024 * 1024, lines = 30000, line_length = 2000 } },
    autocmds = {
      performance_large_buffers = {
        {
          event = { "BufReadPost", "BufWinEnter" },
          callback = function(args) require("user.large_buffer").check(args.buf) end,
        },
        {
          event = "LspAttach",
          callback = function(args)
            if vim.b[args.buf].large_buf then
              vim.schedule(function()
                if vim.api.nvim_buf_is_valid(args.buf) then
                  pcall(vim.lsp.semantic_tokens.stop, args.buf, args.data.client_id)
                end
              end)
            end
          end,
        },
      },
    },
  },
}
