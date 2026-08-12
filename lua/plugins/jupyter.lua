local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, {
    title = "Jupyter notebook",
  })
end

local format_timers = {}
local notebook_for
local markdown_extmarks = {}

local function reconcile_undo_cells(bufnr)
  local notebook = notebook_for(bufnr)
  if not notebook then return end

  notebook:sync_from_buffer()
  local has_new_cell = false
  for _, cell in ipairs(notebook.cells) do
    if cell.id:match("^new_") then
      has_new_cell = true
      break
    end
  end
  if not has_new_cell then return end

  local ok, jupynvim = pcall(require, "jupynvim")
  if not ok or not jupynvim.client then return end

  local Embedded = require("jupynvim.embedded")
  local incoming = {}
  for _, cell in ipairs(notebook.cells) do
    local source = cell.source or ""
    if cell.cell_type == "markdown" then
      source = Embedded.postprocess(cell.id, source)
    end
    table.insert(incoming, {
      id = cell.id,
      cell_type = cell.cell_type or "code",
      source = source,
    })
  end

  local err, result = jupynvim.client:call_sync(
    "replace_cells",
    { session_id = notebook.session_id, cells = incoming },
    5000
  )
  if err then
    notify("Undo cell synchronization failed: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  for index, id in ipairs(result and result.ids or {}) do
    if notebook.cells[index] then notebook.cells[index].id = id end
  end
end

notebook_for = function(bufnr)
  local ok, Notebook = pcall(require, "jupynvim.notebook")
  if not ok then return nil end
  return Notebook.get(bufnr)
end

local function clear_render_markdown_cells(bufnr)
  local namespace = vim.api.nvim_create_namespace("JupynvimRenderMarkdownCells")
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  markdown_extmarks[bufnr] = nil
end

local function render_inline_markers(bufnr, parser, ranges, namespace)
  local query = vim.treesitter.query.parse("markdown_inline", [[
    (strong_emphasis) @strong
    (emphasis) @emphasis
    (code_span) @code
  ]])

  local function in_markdown(start_row, end_row)
    for _, range in ipairs(ranges) do
      if start_row >= range[1] and end_row <= range[2] then
        return true
      end
    end
    return false
  end

  local function conceal(row, start_col, end_col)
    vim.api.nvim_buf_set_extmark(bufnr, namespace, row, start_col, {
      end_col = end_col,
      conceal = "",
      priority = 250,
    })
  end

  local function highlight(row, start_col, end_col, group)
    vim.api.nvim_buf_set_extmark(bufnr, namespace, row, start_col, {
      end_col = end_col,
      hl_group = group,
      hl_mode = "combine",
      priority = 240,
    })
  end

  parser:for_each_tree(function(tree, language_tree)
    if language_tree:lang() ~= "markdown_inline" then
      return
    end

    for capture, node in query:iter_captures(tree:root(), bufnr, 0, -1) do
      local kind = query.captures[capture]
      local start_row, start_col, end_row, end_col = node:range()
      if start_row == end_row and in_markdown(start_row, end_row) then
        local text = vim.treesitter.get_node_text(node, bufnr)
        local marker
        local group

        if kind == "strong" then
          if text:sub(1, 2) == "**" and text:sub(-2) == "**" then
            marker = "**"
          elseif text:sub(1, 2) == "__" and text:sub(-2) == "__" then
            marker = "__"
          end
          group = "JupynvimMdBold"
        elseif kind == "emphasis" then
          if text:sub(1, 1) == "*"
              and text:sub(-1) == "*"
              and text:sub(2, 2) ~= "*" then
            marker = "*"
          elseif text:sub(1, 1) == "_"
              and text:sub(-1) == "_"
              and text:sub(2, 2) ~= "_" then
            marker = "_"
          end
          group = "JupynvimMdEm"
        elseif kind == "code" then
          local ticks = text:match("^(`+)")
          if ticks and text:sub(-#ticks) == ticks then
            marker = ticks
          end
        end

        if marker and #text > #marker * 2 then
          local width = #marker
          conceal(start_row, start_col, start_col + width)
          conceal(end_row, end_col - width, end_col)
          if group then
            highlight(
              start_row,
              start_col + width,
              end_col - width,
              group
            )
          end
        end
      end
    end
  end)
end

local function render_markdown_cells(bufnr)
  local notebook = notebook_for(bufnr)
  if not notebook then return end

  if vim.fn.mode(true):sub(1, 1) == "i" then
    clear_render_markdown_cells(bufnr)
    return
  end

  local win = vim.fn.bufwinid(bufnr)
  if win == -1 then return end

  local ok, err = xpcall(function()
    local render_state = require("render-markdown.state")
    render_state.attach()

    local _, ranges = notebook:to_lines()
    local markdown_ranges = {}
    local parser_regions = {}
    for _, range in ipairs(ranges) do
      if range.type == "markdown" and range.stop > range.start then
        table.insert(markdown_ranges, { range.start, range.stop })
        local last_row = range.stop - 1
        local lines = vim.api.nvim_buf_get_lines(bufnr, last_row, range.stop, false)
        local last_line = lines[1] or ""
        table.insert(parser_regions, {
          {
            range.start,
            0,
            vim.api.nvim_buf_get_offset(bufnr, range.start),
            last_row,
            #last_line,
            vim.api.nvim_buf_get_offset(bufnr, last_row) + #last_line,
          },
        })
      end
    end

    clear_render_markdown_cells(bufnr)
    if #markdown_ranges == 0 then return end

    local namespace = vim.api.nvim_create_namespace("JupynvimRenderMarkdownCells")
    local mode_util = require("render-markdown.lib.env").mode
    local config = render_state.get(bufnr)
    local parser = vim.treesitter.get_parser(bufnr, "markdown")
    local marks = {}

    -- A single parser with several disjoint regions can create only the
    -- final markdown_inline tree. Parse each markdown cell independently so
    -- inline code, emphasis, and links work in every cell.
    for index, markdown_range in ipairs(markdown_ranges) do
      parser:set_included_regions({ parser_regions[index] })
      local view = require("render-markdown.request.view").new(bufnr)
      view.ranges = { markdown_range }
      local context = require("render-markdown.request.context").new(
        bufnr,
        win,
        config,
        view
      )
      local cell_marks
      view:parse(parser, function()
        cell_marks = require("render-markdown.core.handlers")
          .run(context, parser)
      end)
      vim.list_extend(marks, cell_marks or {})
      render_inline_markers(
        bufnr,
        parser,
        { markdown_range },
        namespace
      )
    end

    local mode = vim.fn.mode(true)
    markdown_extmarks[bufnr] = {}
    for _, mark in ipairs(marks or {}) do
      local modes = mark.modes
      local visible = mode_util.is(
        mode,
        mode_util.join(config.render_modes, modes)
      )
      if visible then
        local extmark = require("render-markdown.lib.extmark").new(mark)
        extmark:show(namespace, bufnr)
        table.insert(markdown_extmarks[bufnr], extmark)
      end
    end
  end, debug.traceback)

  if not ok then
    clear_render_markdown_cells(bufnr)
    vim.notify_once(
      ("Markdown cell rendering failed: %s"):format(err),
      vim.log.levels.WARN,
      { title = "Jupyter notebook" }
    )
  end
end

local function notebook_is_busy(notebook)
  if notebook.kernel_starting then return true end

  for _, state in pairs(notebook.cell_state or {}) do
    if state.exec_state == "busy" or state.exec_state == "running" then
      return true
    end
  end

  return false
end

local function has_ipython_magic(lines)
  for _, line in ipairs(lines) do
    if line:match("^%s*!") or line:match("^%s*%%") then
      return true
    end
  end

  return false
end

local function scratch_name(bufnr)
  local notebook_path = vim.api.nvim_buf_get_name(bufnr)
  local directory = vim.fn.fnamemodify(notebook_path, ":h")

  if directory == "" or directory == "." then
    directory = vim.fn.getcwd()
  end

  return vim.fs.joinpath(
    directory,
    (".jupynvim-cell-%d.py"):format(bufnr)
  )
end

local function format_source_with_ruff(bufnr, lines)
  local ok, conform = pcall(require, "conform")
  if not ok then
    return nil, "conform.nvim is not available"
  end

  local scratch = vim.api.nvim_create_buf(false, true)
  local formatted
  local format_error

  local ok_run, run_error = xpcall(function()
    vim.api.nvim_buf_set_name(scratch, scratch_name(bufnr))

    vim.bo[scratch].buftype = "nofile"
    vim.bo[scratch].bufhidden = "wipe"
    vim.bo[scratch].swapfile = false
    vim.bo[scratch].filetype = "python"

    vim.api.nvim_buf_set_lines(
      scratch,
      0,
      -1,
      false,
      lines
    )

    local formatter =
      conform.get_formatter_info("ruff_format", scratch)

    if not formatter.available then
      error(formatter.available_msg or "ruff is unavailable")
    end

    local attempted = conform.format({
      bufnr = scratch,
      formatters = { "ruff_format" },
      lsp_format = "never",
      async = false,
      quiet = true,
      timeout_ms = 3000,
    }, function(err)
      format_error = err
    end)

    if not attempted then
      error("ruff_format was not run")
    end

    if format_error then
      error(format_error)
    end

    formatted = vim.api.nvim_buf_get_lines(
      scratch,
      0,
      -1,
      false
    )
  end, debug.traceback)

  if vim.api.nvim_buf_is_valid(scratch) then
    pcall(vim.api.nvim_buf_delete, scratch, {
      force = true,
    })
  end

  if not ok_run then
    return nil, run_error
  end

  return formatted
end

local function sync_notebook_after_edit(bufnr, notebook)
  local ok, err = pcall(
    notebook.sync_from_buffer,
    notebook
  )

  if not ok then
    return false, err
  end

  vim.bo[bufnr].modified = true

  -- Для notebook-aware LSP-клиентов. Для basedpyright эта функция
  -- станет no-op, потому что ниже мы принудительно используем
  -- единое очищенное whole-file представление notebook.
  pcall(function()
    require("jupynvim.notebook_lsp")
      .on_text_change(bufnr, notebook)
  end)

  pcall(function()
    require("jupynvim")
      ._sync_treesitter_ranges(notebook)
  end)

  pcall(function()
    local window = vim.fn.bufwinid(bufnr)
    require("jupynvim.render")
      .refresh(notebook, window)
  end)

  return true
end

local function apply_cell_lines(
  bufnr,
  notebook,
  range,
  lines,
  restore_view
)
  local window = vim.fn.bufwinid(bufnr)
  local cursor
  local view

  if
    window ~= -1
    and vim.api.nvim_win_is_valid(window)
  then
    cursor = vim.api.nvim_win_get_cursor(window)
    view = vim.fn.winsaveview()
  end

  local was_modifiable = vim.bo[bufnr].modifiable
  vim.bo[bufnr].modifiable = true

  local ok, err = pcall(
    vim.api.nvim_buf_set_lines,
    bufnr,
    range.start,
    range.stop,
    false,
    lines
  )

  vim.bo[bufnr].modifiable = was_modifiable

  if not ok then
    return false, err
  end

  local synced, sync_error =
    sync_notebook_after_edit(bufnr, notebook)

  if not synced then
    return false, sync_error
  end

  if
    restore_view
    and window ~= -1
    and cursor
    and vim.api.nvim_win_is_valid(window)
  then
    if view then
      pcall(vim.fn.winrestview, view)
    end

    local new_line = math.min(
      cursor[1],
      vim.api.nvim_buf_line_count(bufnr)
    )

    local current_line =
      vim.api.nvim_buf_get_lines(
        bufnr,
        new_line - 1,
        new_line,
        false
      )[1] or ""

    pcall(
      vim.api.nvim_win_set_cursor,
      window,
      {
        new_line,
        math.min(cursor[2], #current_line),
      }
    )
  end

  return true
end

local function format_cell_impl(bufnr, line, force)
  local notebook = notebook_for(bufnr)
  if not notebook then return false end

  if notebook_is_busy(notebook) then
    notify(
      "Formatting skipped while a cell is executing",
      vim.log.levels.WARN
    )
    return false
  end

  notebook:sync_from_buffer()

  local cell_id, range =
    notebook:cell_at_line(line)

  if
    not cell_id
    or not range
    or line - 1 < range.start
    or line - 1 >= range.stop
  then
    notify(
      "Place the cursor inside a code cell",
      vim.log.levels.WARN
    )
    return false
  end

  local cell = notebook:get_cell(cell_id)

  if not cell or cell.cell_type ~= "code" then
    notify(
      "Only code cells can be formatted",
      vim.log.levels.WARN
    )
    return false
  end

  local source_lines =
    vim.api.nvim_buf_get_lines(
      bufnr,
      range.start,
      range.stop,
      false
    )

  local source = table.concat(source_lines, "\n")

  if source:match("^%s*$") then
    return false
  end

  if has_ipython_magic(source_lines) then
    vim.notify_once(
      "Skipped a cell containing IPython magic (!, %, or %%); "
        .. "Ruff must not rewrite it",
      vim.log.levels.INFO,
      {
        title = "Jupyter notebook",
      }
    )
    return false
  end

  local formatted_sources =
    vim.b[bufnr].jupynvim_format_sources or {}

  vim.b[bufnr].jupynvim_format_sources =
    formatted_sources

  if
    not force
    and formatted_sources[cell_id] == source
  then
    return false
  end

  local formatted, err =
    format_source_with_ruff(bufnr, source_lines)

  if not formatted then
    notify(
      ("Ruff formatting failed: %s")
        :format(tostring(err)),
      vim.log.levels.ERROR
    )
    return false
  end

  if vim.deep_equal(source_lines, formatted) then
    formatted_sources[cell_id] = source
    return false
  end

  local ok, apply_error =
    apply_cell_lines(
      bufnr,
      notebook,
      range,
      formatted,
      true
    )

  if not ok then
    notify(
      ("Could not apply formatted cell: %s")
        :format(tostring(apply_error)),
      vim.log.levels.ERROR
    )
    return false
  end

  formatted_sources[cell_id] =
    table.concat(formatted, "\n")

  return true
end

local function format_notebook_cell(
  bufnr,
  line,
  force
)
  bufnr = bufnr == 0
      and vim.api.nvim_get_current_buf()
    or bufnr

  if vim.b[bufnr].jupynvim_formatting then
    return false
  end

  vim.b[bufnr].jupynvim_formatting = true

  local ok, changed = xpcall(function()
    return format_cell_impl(
      bufnr,
      line or vim.fn.line("."),
      force == true
    )
  end, debug.traceback)

  vim.b[bufnr].jupynvim_formatting = false

  if not ok then
    notify(
      ("Cell formatting failed: %s")
        :format(changed),
      vim.log.levels.ERROR
    )
    return false
  end

  return changed
end

local function restore_position(
  bufnr,
  window,
  cursor,
  view
)
  if
    not window
    or window == -1
    or not vim.api.nvim_win_is_valid(window)
  then
    return
  end

  if view then
    pcall(vim.fn.winrestview, view)
  end

  local line = math.min(
    cursor[1],
    vim.api.nvim_buf_line_count(bufnr)
  )

  local text =
    vim.api.nvim_buf_get_lines(
      bufnr,
      line - 1,
      line,
      false
    )[1] or ""

  pcall(
    vim.api.nvim_win_set_cursor,
    window,
    {
      line,
      math.min(cursor[2], #text),
    }
  )
end

local function format_notebook_all(
  bufnr,
  force
)
  bufnr = bufnr == 0
      and vim.api.nvim_get_current_buf()
    or bufnr

  if vim.b[bufnr].jupynvim_formatting then
    return 0
  end

  local notebook = notebook_for(bufnr)
  if not notebook then return 0 end

  if notebook_is_busy(notebook) then
    notify(
      "Formatting skipped while a cell is executing",
      vim.log.levels.WARN
    )
    return 0
  end

  local window = vim.fn.bufwinid(bufnr)

  local cursor =
    window ~= -1
      and vim.api.nvim_win_get_cursor(window)
    or { 1, 0 }

  local view =
    window ~= -1
      and vim.fn.winsaveview()
    or nil

  local changed = 0
  vim.b[bufnr].jupynvim_formatting = true

  for index = 1, #notebook.cells do
    notebook:sync_from_buffer()

    local _, ranges = notebook:to_lines()
    local range = ranges[index]

    if range and range.type == "code" then
      local ok, did_change = xpcall(function()
        return format_cell_impl(
          bufnr,
          range.start + 1,
          force == true
        )
      end, debug.traceback)

      if ok then
        if did_change then
          changed = changed + 1
        end
      else
        notify(
          ("Cell %d formatting failed: %s")
            :format(index, did_change),
          vim.log.levels.ERROR
        )
      end
    end
  end

  vim.b[bufnr].jupynvim_formatting = false

  restore_position(
    bufnr,
    window,
    cursor,
    view
  )

  if changed > 0 then
    notify(
      ("Formatted %d code cell%s"):format(
        changed,
        changed == 1 and "" or "s"
      )
    )
  end

  return changed
end

local function cancel_format_timer(bufnr)
  local timer = format_timers[bufnr]

  if timer then
    pcall(timer.stop, timer)
    pcall(timer.close, timer)
    format_timers[bufnr] = nil
  end
end

local function schedule_cell_format(bufnr)
  cancel_format_timer(bufnr)

  local timer = vim.uv.new_timer()
  if not timer then return end

  format_timers[bufnr] = timer

  timer:start(
    350,
    0,
    vim.schedule_wrap(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        pcall(timer.stop, timer)
        pcall(timer.close, timer)
        format_timers[bufnr] = nil
        return
      end

      if format_timers[bufnr] ~= timer then
        return
      end

      format_timers[bufnr] = nil

      pcall(timer.stop, timer)
      pcall(timer.close, timer)

      local window = vim.fn.bufwinid(bufnr)

      if
        window ~= -1
        and vim.api.nvim_win_is_valid(window)
      then
        format_notebook_cell(
          bufnr,
          vim.api.nvim_win_get_cursor(window)[1],
          false
        )
      end
    end)
  )
end

local function setup_notebook_buffer(bufnr)
  if
    vim.b[bufnr].jupynvim_cell_formatting_setup
  then
    return
  end

  vim.b[bufnr].jupynvim_cell_formatting_setup =
    true

  local function run_undo_action(action)
    local was_modifiable = vim.bo[bufnr].modifiable
    vim.bo[bufnr].modifiable = true
    local ok, err = xpcall(action, debug.traceback)
    vim.bo[bufnr].modifiable = was_modifiable

    if ok then reconcile_undo_cells(bufnr) end

    if not ok then
      notify(("Undo action failed: %s"):format(err), vim.log.levels.ERROR)
    end
  end

  vim.keymap.set("n", "u", function()
    run_undo_action(function() vim.cmd("undo") end)
  end, {
    buffer = bufnr,
    silent = true,
    desc = "Undo notebook change",
  })
  vim.keymap.set("n", "<C-r>", function()
    run_undo_action(function() vim.cmd("redo") end)
  end, {
    buffer = bufnr,
    silent = true,
    desc = "Redo notebook change",
  })

  vim.keymap.set(
    "n",
    "<leader>nf",
    function()
      local window = vim.fn.bufwinid(bufnr)

      if
        window == -1
        or not vim.api.nvim_win_is_valid(window)
      then
        return
      end

      format_notebook_cell(
        bufnr,
        vim.api.nvim_win_get_cursor(window)[1],
        true
      )
    end,
    {
      buffer = bufnr,
      silent = true,
      desc = "Format current code cell",
    }
  )

  vim.keymap.set(
    "n",
    "<leader>nF",
    function()
      format_notebook_all(bufnr, true)
    end,
    {
      buffer = bufnr,
      silent = true,
      desc = "Format all code cells",
    }
  )

  vim.api.nvim_create_autocmd(
    "InsertLeave",
    {
      group = "JupynvimCellFormatting",
      buffer = bufnr,
      desc =
        "Format the current Jupyter code cell after editing",
      callback = function()
        schedule_cell_format(bufnr)
      end,
    }
  )

  vim.api.nvim_create_autocmd(
    "BufWritePre",
    {
      group = "JupynvimCellFormatting",
      buffer = bufnr,
      desc =
        "Format Jupyter code cells before saving",
      callback = function()
        cancel_format_timer(bufnr)
        format_notebook_all(bufnr, false)
      end,
    }
  )

  vim.api.nvim_create_autocmd(
    "BufWipeout",
    {
      group = "JupynvimCellFormatting",
      buffer = bufnr,
      callback = function()
        cancel_format_timer(bufnr)
        clear_render_markdown_cells(bufnr)
      end,
    }
  )

end

local function add_unique(list, value)
  if not vim.tbl_contains(list, value) then
    table.insert(list, value)
  end
end

local blocked_python_servers = {
  "pyright",
  "ruff",
  "pylsp",
  "pylyzer",
  "ty",
}

return {
  {
    "AstroNvim/astrolsp",

    opts = function(_, opts)
      opts.servers = opts.servers or {}

      -- Оставляем один type checker: basedpyright.
      for index = #opts.servers, 1, -1 do
        if
          vim.tbl_contains(
            blocked_python_servers,
            opts.servers[index]
          )
        then
          table.remove(opts.servers, index)
        end
      end

      add_unique(opts.servers, "basedpyright")

      opts.handlers = opts.handlers or {}

      for _, server in ipairs(
        blocked_python_servers
      ) do
        opts.handlers[server] = false
      end

      opts.config = opts.config or {}

      local old_basedpyright =
        opts.config.basedpyright or {}

      local previous_on_init =
        old_basedpyright.on_init
      local previous_on_attach =
        old_basedpyright.on_attach

      opts.config.basedpyright =
        vim.tbl_deep_extend(
          "force",
          old_basedpyright,
          {
            capabilities = vim.tbl_deep_extend(
              "force",
              old_basedpyright.capabilities or {},
              {
                notebookDocument = {
                  synchronization = {
                    dynamicRegistration = false,
                    executionSummarySupport = true,
                  },
                },
              }
            ),
            flags = {
              -- Критично для jupynvim:
              -- каждый didChange должен отправлять полный
              -- очищенный текст всех code-cells.
              allow_incremental_sync = false,
            },

            on_init = function(
              client,
              initialize_result
            )
              if previous_on_init then
                local ok, err = pcall(
                  previous_on_init,
                  client,
                  initialize_result
                )

                if not ok then
                  vim.schedule(function()
                    notify(
                      (
                        "Previous basedpyright on_init failed: %s"
                      ):format(tostring(err)),
                      vim.log.levels.WARN
                    )
                  end)
                end
              end

            end,

            on_attach = function(client, bufnr)
              if previous_on_attach then
                previous_on_attach(client, bufnr)
              end

              if not client._jupynvim_file_notebook_uri then
                client._jupynvim_file_notebook_uri = true

                local original_notify = client.notify
                client.notify = function(self, method, params)
                if
                  type(method) == "string"
                  and method:sub(1, 17) == "notebookDocument/"
                  and params
                then
                  params = vim.deepcopy(params)

                  local notebook = notebook_for(bufnr)
                  local markdown_ids = {}
                  if notebook then
                    for _, cell in ipairs(notebook.cells) do
                      if cell.cell_type == "markdown" then
                        markdown_ids[cell.id] = true
                      end
                    end
                  end

                  local function blank_markdown(document)
                    local id = document.uri
                      and document.uri:match("#(.+)$")
                    if markdown_ids[id] then
                      document.text = ""
                    end
                  end

                  for _, document in ipairs(
                    params.cellTextDocuments or {}
                  ) do
                    blank_markdown(document)
                  end

                  local cells = params.change
                    and params.change.cells
                  for _, document in ipairs(
                    cells and cells.structure
                      and cells.structure.didOpen or {}
                  ) do
                    blank_markdown(document)
                  end

                  for _, content in ipairs(
                    cells and cells.textContent or {}
                  ) do
                    local id = content.document.uri
                      and content.document.uri:match("#(.+)$")
                    if markdown_ids[id] then
                      for _, change in ipairs(
                        content.changes or {}
                      ) do
                        change.text = ""
                      end
                    end
                  end

                  local document = params.notebookDocument
                  if document
                    and type(document.uri) == "string"
                    and document.uri:sub(1, 9) == "jupynvim:" then
                    local path = document.uri:sub(10)
                    document.uri = vim.uri_from_fname(path)
                  end
                end
                  return original_notify(self, method, params)
                end
              end

              local ok, notebook = pcall(
                function()
                  return require("jupynvim.notebook").get(bufnr)
                end
              )
              if ok and notebook then
                local notebook_lsp = require("jupynvim.notebook_lsp")
                pcall(notebook_lsp.on_close, bufnr)
                pcall(
                  notebook_lsp.on_attach,
                  bufnr,
                  notebook,
                  client
                )
              end
            end,

            settings = {
              basedpyright = {
                analysis = {
                  diagnosticMode =
                    "openFilesOnly",
                  typeCheckingMode = "basic",
                  autoSearchPaths = true,
                  useLibraryCodeForTypes = true,
                },
              },
            },
          }
        )

      opts.formatting = opts.formatting or {}
      opts.formatting.disabled =
        opts.formatting.disabled or {}

      -- Форматирует только Conform.
      add_unique(
        opts.formatting.disabled,
        "basedpyright"
      )

    end,
  },

  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",

    opts = function(_, opts)
      opts.ensure_installed =
        opts.ensure_installed or {}

      add_unique(
        opts.ensure_installed,
        "basedpyright"
      )

      add_unique(
        opts.ensure_installed,
        "ruff"
      )
    end,
  },

  {
    "stevearc/conform.nvim",

    opts = function(_, opts)
      opts.formatters_by_ft =
        opts.formatters_by_ft or {}

      opts.formatters_by_ft.python = {
        "ruff_format",
      }

      opts.default_format_opts =
        vim.tbl_deep_extend(
          "force",
          opts.default_format_opts or {},
          {
            lsp_format = "never",
          }
        )
    end,
  },

  {
    "sheng-tse/jupynvim",

    version = "v0.4.2",

    dependencies = {
      "AstroNvim/astrolsp",
      "neovim/nvim-lspconfig",
      "stevearc/conform.nvim",
      "nvim-treesitter/nvim-treesitter",
    },

    build = function(plugin)
      local install =
        loadfile(
          plugin.dir
            .. "/lua/jupynvim/install.lua"
        )()

      install.run(plugin)
    end,

    config = function()
      local group =
        vim.api.nvim_create_augroup(
          "JupynvimCellFormatting",
          {
            clear = true,
          }
        )

      local function try_setup_buffer(bufnr)
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end

        if notebook_for(bufnr) then
          local jupynvim_markdown = require("jupynvim.markdown")
          if not jupynvim_markdown._render_markdown_adapter then
            jupynvim_markdown.render = function() end
            jupynvim_markdown._render_markdown_adapter = true
          end
          if vim.treesitter and vim.treesitter.start then
            pcall(vim.treesitter.start, bufnr, "python")
          end
          setup_notebook_buffer(bufnr)
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(bufnr) then
              render_markdown_cells(bufnr)
            end
          end)
          vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(bufnr) then
              render_markdown_cells(bufnr)
            end
          end, 100)
        end
      end

      vim.api.nvim_create_autocmd(
        "FileType",
        {
          group = group,
          pattern = "python",
          desc =
            "Install cell-aware formatting for jupynvim buffers",
          callback = function(args)
            try_setup_buffer(args.buf)
          end,
        }
      )

      -- Запасной путь на случай, если FileType был
      -- отправлен до создания объекта Notebook.
      vim.api.nvim_create_autocmd(
        "BufEnter",
        {
          group = group,
          pattern = "*.ipynb",
          desc =
            "Ensure jupynvim cell formatting is installed",
          callback = function(args)
            vim.schedule(function()
              try_setup_buffer(args.buf)
            end)
          end,
        }
      )

      vim.api.nvim_create_autocmd(
        {
          "BufEnter",
          "BufWinEnter",
          "TextChanged",
          "TextChangedI",
          "CursorMoved",
          "InsertEnter",
          "InsertLeave",
          "ModeChanged",
          "WinScrolled",
          "ColorScheme",
        },
        {
          group = group,
          desc =
            "Refresh notebook diagnostic rendering",
          callback = function(args)
            if not notebook_for(args.buf) then
              return
            end

            reconcile_undo_cells(args.buf)

            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(args.buf) then
                render_markdown_cells(args.buf)
                pcall(
                  vim.diagnostic.show,
                  nil,
                  args.buf
                )
              end
            end)
          end,
        }
      )

      require("jupynvim").setup({
        log_level = "info",

        image_renderer = "placeholder",
        image_rows = 18,
        image_cols = 60,

        auto_venv = true,
        smooth_scroll = false,

        -- Basedpyright здесь намеренно НЕ указан:
        -- он должен анализировать единое очищенное
        -- представление всех code-cells.
        lsp_blocklist = {
          "pyright",
          "ruff",
          "pylsp",
          "pylyzer",
          "ty",
        },
      })

      local markdown_palette = {
        JupynvimMdH1 = "RenderMarkdownH1",
        JupynvimMdH2 = "RenderMarkdownH2",
        JupynvimMdH3 = "RenderMarkdownH3",
        JupynvimMdH4 = "RenderMarkdownH4",
        JupynvimMdH5 = "RenderMarkdownH5",
        JupynvimMdH6 = "RenderMarkdownH6",
        JupynvimMdCode = "RenderMarkdownCode",
        JupynvimMdLink = "RenderMarkdownLink",
        JupynvimMdQuote = "RenderMarkdownQuote",
        JupynvimMdBullet = "RenderMarkdownBullet",
        JupynvimMdHR = "RenderMarkdownDash",
        JupynvimMdMath = "RenderMarkdownMath",
        JupynvimMdMathBlock = "RenderMarkdownMath",
        JupynvimMdCheck = "RenderMarkdownChecked",
        JupynvimMdTableBorder = "RenderMarkdownTableRow",
        JupynvimMdTableHead = "RenderMarkdownTableHead",
      }

      local function apply_markdown_palette()
        for group, target in pairs(markdown_palette) do
          vim.api.nvim_set_hl(0, group, { link = target })
        end
      end

      local palette_group = vim.api.nvim_create_augroup(
        "JupynvimRenderMarkdownPalette",
        { clear = true }
      )
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = palette_group,
        desc = "Use render-markdown highlights in jupynvim markdown cells",
        callback = apply_markdown_palette,
      })
      apply_markdown_palette()
    end,
  },
}
