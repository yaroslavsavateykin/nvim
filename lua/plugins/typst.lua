-- Typst: Tinymist provides language features; the typstyle CLI formats on save.
-- No LSP formatting request or Conform.nvim is involved.
local function typstyle_executable()
  if vim.fn.executable("typstyle") == 1 then return "typstyle" end
  local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/typstyle"
  if vim.fn.executable(mason_bin) == 1 then return mason_bin end
  return nil
end

local function format_typst(bufnr)
  if not vim.bo[bufnr].modifiable or vim.bo[bufnr].buftype ~= "" then return end

  local executable = typstyle_executable()
  if not executable then
    vim.notify("typstyle не найден в PATH или Mason", vim.log.levels.WARN)
    return
  end

  local original = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local input = table.concat(original, "\n")
  if vim.bo[bufnr].endofline then input = input .. "\n" end

  local result = vim.system({ executable }, { stdin = input, text = true }):wait(5000)
  if result.code ~= 0 then
    vim.notify("typstyle: " .. (result.stderr or "formatting failed"), vim.log.levels.WARN)
    return
  end

  local output = result.stdout or ""
  if output == input then return end

  local ends_with_newline = output:sub(-1) == "\n"
  local lines = vim.split(output, "\n", { plain = true, trimempty = false })
  if ends_with_newline then table.remove(lines) end
  if #lines == 0 then lines = { "" } end

  local view = vim.fn.winsaveview()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].endofline = ends_with_newline
  vim.fn.winrestview(view)
end

return {
  "AstroNvim/astrolsp",

  init = function()
    local group = vim.api.nvim_create_augroup("TypstyleDirectFormat", { clear = true })
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = group,
      pattern = "*.typ",
      desc = "Format Typst directly with typstyle (not through LSP)",
      callback = function(args) format_typst(args.buf) end,
    })
  end,

  ---@param opts AstroLSPOpts
  opts = function(_, opts)
    opts.servers = opts.servers or {}
    if not vim.tbl_contains(opts.servers, "tinymist") then
      table.insert(opts.servers, "tinymist")
    end

    opts.config = opts.config or {}
    opts.config.tinymist = vim.tbl_deep_extend("force", opts.config.tinymist or {}, {
      settings = {
        projectResolution = "lockDatabase",
      },
    })

    -- Stop AstroLSP from also requesting formatting on every Typst save.
    opts.formatting = opts.formatting or {}
    opts.formatting.disabled = opts.formatting.disabled or {}
    if not vim.tbl_contains(opts.formatting.disabled, "tinymist") then
      table.insert(opts.formatting.disabled, "tinymist")
    end
    opts.formatting.format_on_save = opts.formatting.format_on_save or {}
    opts.formatting.format_on_save.ignore_filetypes =
      opts.formatting.format_on_save.ignore_filetypes or {}
    if not vim.tbl_contains(opts.formatting.format_on_save.ignore_filetypes, "typst") then
      table.insert(opts.formatting.format_on_save.ignore_filetypes, "typst")
    end
  end,
}
