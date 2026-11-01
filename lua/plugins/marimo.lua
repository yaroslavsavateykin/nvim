local function urlencode(str)
  return (
    str:gsub("([^%w%-_%.~])", function(c)
      return string.format("%%%02X", string.byte(c))
    end)
  )
end

local function make_empty_notebook()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")

  -- Непустой файл вообще не трогаем
  if not text:match("^%s*$") then
    return
  end

  -- Пустой .py автоматически превращаем
  -- в минимальный marimo notebook
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "import marimo",
    "",
    "app = marimo.App()",
    "",
    "",
    "@app.cell",
    "def _():",
    "    import marimo as mo",
    "    return (mo,)",
    "",
    "",
    "@app.cell",
    "def _(mo):",
    '    mo.md("# New marimo notebook")',
    "    return",
    "",
    "",
    'if __name__ == "__main__":',
    "    app.run()",
  })

  vim.cmd("write")
end

local pending = {}
local function cancel_open(bufnr)
  local timer = pending[bufnr]
  pending[bufnr] = nil
  if timer and not timer:is_closing() then timer:stop(); timer:close() end
end

local function open_full_editor(marimo, bufnr, path)
  cancel_open(bufnr)
  local attempts = 0
  local timer = vim.uv.new_timer()
  pending[bufnr] = timer

  local function try_open()
    if pending[bufnr] ~= timer then return end
    if not vim.api.nvim_buf_is_valid(bufnr) then cancel_open(bufnr); return end
    attempts = attempts + 1

    local session = marimo.get_session(bufnr)

    if session then
      cancel_open(bufnr)
      local conn = session.conn

      local url = string.format(
        "http://%s:%d/?file=%s",
        conn.host,
        conn.port,
        urlencode(path)
      )

      if conn.token and conn.token ~= "" then
        url = url
          .. "&access_token="
          .. urlencode(conn.token)
      end

      -- ВАЖНО:
      -- kiosk=true здесь НЕТ.
      --
      -- Поэтому открывается полноценный marimo editor,
      -- а не пустой kiosk preview.
      vim.ui.open(url)

      vim.notify(
        "[marimo] editor opened",
        vim.log.levels.INFO
      )

      vim.cmd("redrawstatus")
      return
    end

    -- Ждём пока marimo.nvim создаст session
    if attempts < 80 then
      return
    end

    cancel_open(bufnr)
    vim.notify(
      "[marimo] failed to connect",
      vim.log.levels.ERROR
    )
  end

  timer:start(0, 250, vim.schedule_wrap(try_open))
end

return {
  {
    "bri-ijk/marimo.nvim",

    cmd = { "MarimoStart", "MarimoStop", "MarimoAttach", "MarimoDetach", "MarimoStatus" },

    opts = {
      -- Браузер откроем сами без kiosk=true
      open_browser = false,

      follow_cursor = true,
      autorun_markdown_on_attach = true,

      host = "127.0.0.1",
      port = nil,

      run_definition_cells = false,

      -- Не превращаем Enter во "выполнить cell"
      enter_to_run = false,

      -- Родные mappings marimo.nvim оставляем
      -- keys не переопределяем
    },

    config = function(_, opts)
      local marimo = require("marimo")

      marimo.setup(opts)
      local stop = marimo.stop
      marimo.stop = function(...)
        for buf in pairs(pending) do cancel_open(buf) end
        return stop(...)
      end

      ----------------------------------------------------------
      -- Browser -> Neovim
      ----------------------------------------------------------

      vim.opt.autoread = true

      local sync_group = vim.api.nvim_create_augroup(
        "MarimoFileSync",
        { clear = true }
      )

      vim.api.nvim_create_autocmd({
        "FocusGained",
        "BufEnter",
        "BufWritePost",
      }, {
        group = sync_group,

        callback = function(args)
          local buf = args.buf
          if vim.api.nvim_buf_is_valid(buf) and marimo.get_session(buf)
            and vim.bo[buf].buftype == "" and not vim.bo[buf].modified then
            vim.api.nvim_buf_call(buf, function() vim.cmd("silent! checktime " .. buf) end)
          end
        end,
      })

      vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
        group = sync_group, callback = function(args) cancel_open(args.buf) end,
      })
      vim.api.nvim_create_autocmd("VimLeavePre", {
        group = sync_group, callback = function()
          for buf in pairs(pending) do cancel_open(buf) end
        end,
      })
      -- Upstream closes websocket sessions on BufDelete and its managed server on VimLeavePre.
      ----------------------------------------------------------
      -- Переопределяем ТОЛЬКО :MarimoStart
      ----------------------------------------------------------

      pcall(
        vim.api.nvim_del_user_command,
        "MarimoStart"
      )

      vim.api.nvim_create_user_command(
        "MarimoStart",
        function()
          local bufnr =
            vim.api.nvim_get_current_buf()

          local path =
            vim.api.nvim_buf_get_name(bufnr)

          if path == "" then
            vim.notify(
              "[marimo] сначала сохрани файл",
              vim.log.levels.ERROR
            )
            return
          end

          if not path:match("%.py$") then
            vim.notify(
              "[marimo] нужен .py файл",
              vim.log.levels.ERROR
            )
            return
          end

          make_empty_notebook()

          vim.cmd("write")

          -- Родной marimo.nvim:
          -- server
          -- PID
          -- websocket
          -- --watch
          -- session
          marimo.start()

          -- Наше отличие:
          -- открываем ПОЛНЫЙ editor
          open_full_editor(
            marimo,
            bufnr,
            path
          )
        end,
        {
          desc = "Start marimo full editor",
        }
      )
    end,

    ------------------------------------------------------------
    -- Твои удобные bindings
    ------------------------------------------------------------

    keys = {
      {
        "<leader>ms",
        "<cmd>MarimoStart<cr>",
        desc = "Marimo Start",
      },

      {
        "<leader>mq",
        "<cmd>MarimoStop<cr>",
        desc = "Marimo Stop",
      },

      {
        "<leader>mr",
        "<cmd>MarimoRunCell<cr>",
        desc = "Marimo Run Cell",
      },

      {
        "<leader>mR",
        "<cmd>MarimoRunAll<cr>",
        desc = "Marimo Run All",
      },

      {
        "<leader>mf",
        "<cmd>MarimoToggleFollow<cr>",
        desc = "Marimo Follow",
      },

      {
        "<leader>mi",
        "<cmd>MarimoStatus<cr>",
        desc = "Marimo Status",
      },

      {
        "<leader>ma",
        "<cmd>MarimoAttach<cr>",
        desc = "Marimo Attach",
      },

      {
        "<leader>md",
        "<cmd>MarimoDetach<cr>",
        desc = "Marimo Detach",
      },
    },
  },
}

-- opts = {
--   marimo_bin = vim.fn.expand(
--     "~/.local/src/marimo-astro/.venv/bin/marimo"
--   ),
--
--   open_browser = false,
--   follow_cursor = true,
--   autorun_markdown_on_attach = true,
--   enter_to_run = false,
-- }
