return {
  "AstroNvim/astrolsp",

  ---@param opts AstroLSPOpts
  opts = function(_, opts)
    -- Гарантируем запуск Tinymist.
    opts.servers = opts.servers or {}

    if not vim.tbl_contains(opts.servers, "tinymist") then
      table.insert(opts.servers, "tinymist")
    end

    -- Расширяем существующую конфигурацию,
    -- в том числе конфигурацию из AstroCommunity.
    opts.config = opts.config or {}

    opts.config.tinymist = vim.tbl_deep_extend(
      "force",
      opts.config.tinymist or {},
      {
        settings = {
          formatterMode = "typstyle",
          projectResolution = "lockDatabase",
        },
      }
    )
  end,
}
