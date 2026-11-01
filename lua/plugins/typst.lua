-- Tinymist owns language features. typst-format.lua owns the single save formatter.
return {
  "AstroNvim/astrolsp",
  opts = function(_, opts)
    opts.servers = opts.servers or {}
    if not vim.tbl_contains(opts.servers, "tinymist") then table.insert(opts.servers, "tinymist") end
    opts.config = opts.config or {}
    opts.config.tinymist = vim.tbl_deep_extend("force", opts.config.tinymist or {}, {
      settings = { projectResolution = "lockDatabase", exportPdf = "never" },
    })
    -- PDF production is already handled by the user's explicit typst watch.
    -- Do not compile/export another PDF on each keystroke in Tinymist.
    opts.formatting = opts.formatting or {}
    opts.formatting.disabled = opts.formatting.disabled or {}
    if not vim.tbl_contains(opts.formatting.disabled, "tinymist") then
      table.insert(opts.formatting.disabled, "tinymist")
    end
    opts.formatting.format_on_save = opts.formatting.format_on_save or {}
    local save = opts.formatting.format_on_save
    save.ignore_filetypes = save.ignore_filetypes or {}
    if not vim.tbl_contains(save.ignore_filetypes, "typst") then table.insert(save.ignore_filetypes, "typst") end
  end,
}
