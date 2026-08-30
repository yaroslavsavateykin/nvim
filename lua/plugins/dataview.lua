return {
  "SpollaL/datasight.nvim",
  keys = {
    {
      "<leader>ds",
      function()
        local filepath

        if vim.bo.filetype == "NvimTree" then
          local node = require("nvim-tree.api").tree.get_node_under_cursor()
          filepath = node and node.absolute_path
        else
          filepath = vim.api.nvim_buf_get_name(0)
        end

        require("datasight").open(filepath)
      end,
      desc = "Open Datasight for current file",
    },
  },
  opts = {
    binary_path = "datasight", -- бинарник на PATH
    width = 0.85,
    height = 0.85,
    border = "rounded",
    display = "float",
    auto_open = false,
    -- The lazy.nvim key above also works while NvimTree has focus.
    keymaps = { open = false },
  },
  cmd = "Datasight",
  ft = { "csv", "tsv", "parquet", "json", "ndjson", "jsonl" },
}
