return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",

    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      if not vim.tbl_contains(opts.ensure_installed, "typstyle") then
        table.insert(opts.ensure_installed, "typstyle")
      end
    end,
  },

  {
    "stevearc/conform.nvim",

    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.typst = { "typstyle" }

      opts.formatters = opts.formatters or {}

      opts.formatters.typstyle = {
        prepend_args = {
          "--wrap-text",
          "--line-width",
          "70",
          "--indent-width",
          "2",
        },
      }
    end,

    keys = {
      {
        "<leader>lf",
        function()
          require("conform").format({
            bufnr = 0,
            formatters = { "typstyle" },
            timeout_ms = 3000,
            lsp_format = "never",
          })
        end,
        desc = "Format Typst",
      },
    },

    init = function()
      local group = vim.api.nvim_create_augroup(
        "TypstFormatOnSave",
        { clear = true }
      )

      vim.api.nvim_create_autocmd("BufWritePre", {
        group = group,
        pattern = "*.typ",

        callback = function(args)
          require("conform").format({
            bufnr = args.buf,
            formatters = { "typstyle" },
            timeout_ms = 3000,
            lsp_format = "never",
          })
        end,
      })
    end,
  },
}
