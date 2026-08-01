local function format_typst(bufnr)
  local fileencoding = vim.bo[bufnr].fileencoding

  if fileencoding ~= "" and fileencoding ~= "utf-8" then
    vim.schedule(function()
      vim.notify(
        (
          "Skipped typstyle for %s: buffer encoding is %s, expected utf-8"
        ):format(vim.api.nvim_buf_get_name(bufnr), fileencoding),
        vim.log.levels.WARN,
        { title = "Typst Format" }
      )
    end)

    return
  end

  require("conform").format({
    bufnr = bufnr,
    formatters = { "typstyle" },
    timeout_ms = 3000,
    lsp_format = "never",
  })
end

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
          format_typst(0)
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
          format_typst(args.buf)
        end,
      })
    end,
  },
}
