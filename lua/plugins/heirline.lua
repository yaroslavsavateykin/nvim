return {
  {
    "rebelot/heirline.nvim",

    opts = function(_, opts)
      local marimo_status = {
        condition = function()
          local ok, marimo =
            pcall(require, "marimo")

          if not ok then
            return false
          end

          -- ВАЖНО: не get_session(0)
          return marimo.get_session() ~= nil
        end,

        provider = function()
          local ok, marimo =
            pcall(require, "marimo")

          if not ok then
            return ""
          end

          local session =
            marimo.get_session()

          if not session then
            return ""
          end

          if session.ready then
            return " 󰢱 Marimo ● "
          end

          return " 󰢱 Marimo ◐ "
        end,

        hl = {
          bold = true,
        },
      }

      -- Добавляем справа,
      -- не переписывая statusline AstroNvim целиком.
      table.insert(
        opts.statusline,
        #opts.statusline,
        marimo_status
      )
    end,
  },
}
