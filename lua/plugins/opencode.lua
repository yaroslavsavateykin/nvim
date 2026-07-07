return {
  {
    "nickjvandyke/opencode.nvim",
    version = "*",
    config = function()
      vim.g.opencode_opts = {
        -- пока можно оставить пустым
      }

      -- нужно, чтобы Neovim перечитывал файлы после правок OpenCode
      vim.o.autoread = true

      local opencode = require("opencode")

      vim.keymap.set({ "n", "x" }, "<leader>oa", function()
        opencode.ask("@this: ")
      end, { desc = "Ask OpenCode" })

      vim.keymap.set({ "n", "x" }, "<leader>os", function()
        opencode.select()
      end, { desc = "Select OpenCode" })

      vim.keymap.set({ "n", "x" }, "go", function()
        return opencode.operator("@this ")
      end, { expr = true, desc = "Send motion to OpenCode" })

      vim.keymap.set("n", "goo", function()
        return opencode.operator("@this ") .. "_"
      end, { expr = true, desc = "Send current line to OpenCode" })

      vim.keymap.set("n", "<leader>on", function()
        opencode.command("session.new")
      end, { desc = "OpenCode new session" })

      vim.keymap.set("n", "<leader>ou", function()
        opencode.command("session.undo")
      end, { desc = "OpenCode undo" })

      vim.keymap.set("n", "<leader>or", function()
        opencode.command("session.redo")
      end, { desc = "OpenCode redo" })

      vim.keymap.set("n", "<leader>oi", function()
        opencode.command("session.interrupt")
      end, { desc = "OpenCode interrupt" })
    end,
  },
}
