-- PDFs use the system viewer by default (external-files.lua).
-- :PDFReader remains an explicit opt-in to the embedded reader.
return {
  "r-pletnev/pdfreader.nvim",
  cmd = { "PDFReader", "PDFOpen" },
  dependencies = { "folke/snacks.nvim", "nvim-telescope/telescope.nvim" },
  config = function()
    require("pdfreader").setup()
    vim.api.nvim_create_user_command("PDFOpen", function(args)
      vim.g.pdfreader_embedded_open = true
      local ok, err = pcall(vim.cmd.edit, vim.fn.fnameescape(vim.fn.fnamemodify(args.args, ":p")))
      vim.g.pdfreader_embedded_open = nil
      if not ok then error(err) end
    end, { nargs = 1, complete = "file", desc = "Open PDF inside Neovim (opt-in)" })
    local group = vim.api.nvim_create_augroup("pdfreader_user", { clear = true })
    vim.api.nvim_create_autocmd("BufEnter", {
      group = group, pattern = "*.pdf",
      callback = function(args)
        vim.keymap.set("n", "r", "<cmd>PDFReader redrawPage<cr>",
          { buffer = args.buf, silent = true, desc = "Обновить страницу PDF" })
      end,
    })
    -- No global checktime polling: explicit redraw also works with external builds.
  end,
}
