local M = {}
function M.check(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.b[buf].performance_guard then return end
  local count = vim.api.nvim_buf_line_count(buf)
  local size = vim.api.nvim_buf_get_offset(buf, count)
  local large = size > 2 * 1024 * 1024 or count > 30000
  -- AstroCore's average line length test misses one huge JSON/output line.
  if not large then
    for start = 0, count - 1, 512 do
      for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, start, math.min(start + 512, count), false)) do
        if #line > 20000 then large = true; break end
      end
      if large then break end
    end
  end
  if not large then return end
  vim.b[buf].performance_guard = true
  vim.b[buf].large_buf = true
  vim.b[buf].autoformat = false
  vim.b[buf].completion = false
  vim.bo[buf].synmaxcol = 300
  pcall(vim.treesitter.stop, buf)
  vim.diagnostic.enable(false, { bufnr = buf })
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
    pcall(vim.lsp.semantic_tokens.stop, buf, client.id)
  end
  vim.api.nvim_buf_call(buf, function()
    if package.loaded["illuminate"] then require("illuminate").pause_buf() end
    if package.loaded["render-markdown"] then require("render-markdown").buf_disable() end
  end)
end
return M
