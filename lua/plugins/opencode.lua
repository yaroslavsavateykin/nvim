return {
  {
    "nickjvandyke/opencode.nvim",
    version = "*",
    config = function()
      vim.g.opencode_opts = {
        contexts = {
          ["@raw"] = function(context)
            local range = context.range
            if not range then
              return nil
            end

            local start_row = range.from[1] - 1
            local end_row = range.to[1] - 1
            local lines = vim.api.nvim_buf_get_lines(context.buf, start_row, end_row + 1, false)

            if range.kind == "char" then
              lines = vim.api.nvim_buf_get_text(
                context.buf,
                start_row,
                range.from[2],
                end_row,
                range.to[2] + 1,
                {}
              )
            elseif range.kind == "block" then
              for index, line in ipairs(lines) do
                lines[index] = line:sub(range.from[2] + 1, range.to[2] + 1)
              end
            end

            return table.concat(lines, "\n")
          end,
        },
        select = {
          -- A trailing space makes opencode.nvim append instead of submit.
          prompts = {
            ask = "@this ",
            diagnostics = "Explain @diagnostics ",
            document = "Add comments documenting @this ",
            explain = "Explain @this and its context ",
            fix = "Fix @diagnostics ",
            implement = "Implement @this ",
            optimize = "Optimize @this for performance and readability ",
            raw_code = "@raw ",
            review = "Review @this for correctness and readability ",
            test = "Add tests for @this ",
          },
        },
      }

      -- нужно, чтобы Neovim перечитывал файлы после правок OpenCode
      vim.o.autoread = true

      local opencode = require("opencode")

      vim.keymap.set({ "n", "x" }, "<leader>oa", function()
        opencode.prompt("@this ")
      end, { desc = "Append selection to OpenCode" })

      vim.keymap.set({ "n", "x" }, "<leader>os", function()
        opencode.select()
      end, { desc = "Select OpenCode" })

      vim.keymap.set({ "n", "x" }, "go", function()
        return opencode.operator("@this ")
      end, { expr = true, desc = "Append motion to OpenCode" })

      vim.keymap.set("n", "goo", function()
        return opencode.operator("@this ") .. "_"
      end, { expr = true, desc = "Append current line to OpenCode" })

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
