
local default_handler =
  vim.lsp.handlers["textDocument/inlayHint"]

return {
  {
    "AstroNvim/astrolsp",
    opts = {
      features = {
        -- inlay_hints = true,
        signature_help = true,
        semantic_tokens=true,
        inlay_hints = true,
      },

      config = {
        clangd = {
          handlers = {
            ["textDocument/inlayHint"] = function(err, result, ctx)
              if result then
                result = vim.tbl_filter(function(hint)
                  return hint.kind == 2
                end, result)
              end

              return default_handler(err, result, ctx)
            end,
          },
        },
      },
    },
  },
}

