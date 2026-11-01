-- Universal Python environment detection for basedpyright.
--
-- Neovim inherits the environment it was started from, so an activated Conda
-- environment, an activated virtualenv and PYTHONPATH are simply read from
-- `vim.env` - no project-specific knowledge is needed anywhere in this module.
-- The project root comes from root markers and local environments are looked
-- up relative to that root, so the same logic works for Conda, plain venvs,
-- uv/poetry projects and a system-wide Python.
--
-- basedpyright itself does not look at the environment of the editor: it reads
-- `python.pythonPath` and `basedpyright.analysis.extraPaths` from the settings
-- of the running client. That is what this module produces and keeps in sync.

local M = {}

--- Language server that receives the detected environment.
M.server = "basedpyright"

--- Root markers, most specific first. `vim.fs.root` honours this order, so an
--- ancestor `pyproject.toml` wins over a nested `.git` - the same convention
--- the built-in basedpyright `root_dir` uses, plus the uv/poetry lock files.
M.root_markers = {
  "pyproject.toml",
  "uv.lock",
  "poetry.lock",
  "requirements.txt",
  "setup.py",
  "setup.cfg",
  ".git",
}

--- Local environments, relative to the project root.
M.local_envs = { ".venv", "venv", "env" }

--- PYTHONPATH is a path *list*: it is split on the system path separator, not
--- on ":" (Windows uses ";").
local path_separator = vim.fn.has "win32" == 1 and ";" or ":"

--- Signature of the environment last applied per project root. Autocommands
--- compare against it so the language server is only touched when the detected
--- environment really changed.
M.state = { signatures = {}, checks = {}, roots = {} }

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------

local function nonempty(value)
  if type(value) ~= "string" then return nil end
  return value ~= "" and value or nil
end

local function resolve_bufnr(bufnr)
  if bufnr == nil or bufnr == 0 then return vim.api.nvim_get_current_buf() end
  return bufnr
end

--- An interpreter we can actually hand to basedpyright: a file, executable.
local function is_executable(path)
  if not path or path == "" then return false end
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type == "directory" then return false end
  return vim.fn.executable(path) == 1
end

--- Interpreter inside an environment prefix (conda env, virtualenv, ...).
--- Conda on Windows keeps `python.exe` in the prefix root, virtualenvs keep it
--- in `Scripts/`.
local function prefix_python(prefix)
  local candidates = vim.fn.has "win32" == 1 and { "python.exe", "Scripts/python.exe", "bin/python" }
    or { "bin/python", "bin/python3" }

  for _, candidate in ipairs(candidates) do
    local path = vim.fs.joinpath(prefix, candidate)
    if is_executable(path) then return vim.fs.normalize(path) end
  end

  return nil
end

local function is_absolute(path)
  return path:sub(1, 1) == "/" or path:match "^%a:[/\\]" ~= nil or path:sub(1, 2) == "\\\\" or path:sub(1, 1) == "~"
end

--- Split PYTHONPATH the way Python does: on the system path separator, without
--- empty entries and without duplicates.
function M.split_pythonpath(value)
  value = nonempty(value)
  if not value then return {} end

  local entries, seen = {}, {}
  for _, entry in ipairs(vim.split(value, path_separator, { plain = true, trimempty = true })) do
    entry = entry:gsub("^%s+", ""):gsub("%s+$", "")
    if entry ~= "" and not seen[entry] then
      seen[entry] = true
      table.insert(entries, entry)
    end
  end

  return entries
end

--- Root directory of a buffer: its directory when it has a name, else the cwd.
local function buffer_dir(bufnr)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name ~= "" then
      local dir = vim.fs.dirname(vim.fs.normalize(name))
      if dir and dir ~= "" then return dir end
    end
  end

  return vim.uv.cwd() or vim.fn.getcwd()
end

--- Jupyter notebooks are rendered as Python source and carry the kernel
--- environment. jupynvim injects that interpreter itself, so this module stays
--- out of the way for them.
local function is_notebook_buffer(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return false end
  if vim.b[bufnr].jupynvim_alias ~= nil then return true end
  return vim.api.nvim_buf_get_name(bufnr):lower():sub(-6) == ".ipynb"
end

--- Kernel interpreter of a notebook, when jupynvim already resolved one.
local function notebook_kernel(bufnr)
  if not is_notebook_buffer(bufnr) then return nil end
  local ok, notebook = pcall(function() return require("jupynvim.notebook").get(bufnr) end)
  return ok and notebook or nil
end

local function clients()
  return vim.lsp.get_clients { name = M.server }
end

--- Python buffers a client is attached to, notebooks last so that a plain
--- project buffer is preferred as the anchor for a restart.
local function client_buffers(client)
  local found = vim.lsp.get_buffers_by_client_id(client.id)
  if type(found) ~= "table" or vim.tbl_isempty(found) then
    found = vim.tbl_keys(client.attached_buffers or {})
  end

  local plain, notebooks = {}, {}
  for _, bufnr in ipairs(found) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      if is_notebook_buffer(bufnr) then
        table.insert(notebooks, bufnr)
      else
        table.insert(plain, bufnr)
      end
    end
  end

  return plain, notebooks
end

--------------------------------------------------------------------------------
-- detection
--------------------------------------------------------------------------------

--- Project root of a buffer. Never derived from the cwd alone: a buffer may
--- well live outside of it (`:e /elsewhere/main.py`).
---@return string
function M.detect_root(bufnr)
  bufnr = resolve_bufnr(bufnr)
  local dir = buffer_dir(bufnr)
  local cached = M.state.roots[bufnr]
  if cached and cached.dir == dir then return cached.root end
  local root = vim.fs.root(dir, M.root_markers)
  if root then M.state.roots[bufnr] = { dir = dir, root = root } end
  if root then return root end

  -- No marker anywhere above the file: fall back to the workspace of a Python
  -- client that already knows about this buffer, then to the file's directory.
  local best
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
    if client.root_dir then
      if client.name == M.server then return client.root_dir end
      if not best then best = client.root_dir end
    end
  end

  return best or dir
end

--- Interpreter for a project root, in order of priority:
--- 1. the active Conda environment, 2. the active virtualenv,
--- 3. a local environment inside the project root, 4. python3 from PATH,
--- 5. python from PATH.
---@return string? interpreter, string? source
function M.detect_python(root)
  local conda = nonempty(vim.env.CONDA_PREFIX)
  if conda then
    local python = prefix_python(conda)
    if python then return python, "conda" end
  end

  local virtualenv = nonempty(vim.env.VIRTUAL_ENV)
  if virtualenv then
    local python = prefix_python(virtualenv)
    if python then return python, "virtualenv" end
  end

  for _, name in ipairs(M.local_envs) do
    local python = prefix_python(vim.fs.joinpath(root, name))
    if python then return python, "local:" .. name end
  end

  for _, name in ipairs { "python3", "python" } do
    local python = vim.fn.exepath(name)
    if python ~= "" then return vim.fs.normalize(python), "path:" .. name end
  end

  return nil, "none"
end

--- PYTHONPATH as `basedpyright.analysis.extraPaths`. Relative entries are
--- resolved against the current directory, because that is what Python does
--- with them while basedpyright would resolve them against the workspace root.
---@return string[]
function M.get_pythonpath(root)
  local base = root or vim.uv.cwd() or vim.fn.getcwd()
  local entries = {}

  for _, entry in ipairs(M.split_pythonpath(vim.env.PYTHONPATH)) do
    local path = entry
    if not is_absolute(path) then path = vim.fs.joinpath(base, path) end
    path = vim.fs.normalize(path)

    if not vim.tbl_contains(entries, path) then table.insert(entries, path) end
  end

  return entries
end

--- Full picture for a buffer (or, with `root` given, for a project root).
function M.detect_at(root, bufnr)
  local python, source = M.detect_python(root)
  local notebook = notebook_kernel(resolve_bufnr(bufnr))

  return {
    root = root,
    python = python,
    source = source,
    extra_paths = M.get_pythonpath(root),
    pythonpath = nonempty(vim.env.PYTHONPATH),
    conda_prefix = nonempty(vim.env.CONDA_PREFIX),
    virtual_env = nonempty(vim.env.VIRTUAL_ENV),
    notebook = notebook and notebook.kernel_python_path or nil,
  }
end

--- Full picture for a buffer.
function M.detect(bufnr)
  bufnr = resolve_bufnr(bufnr)
  return M.detect_at(M.detect_root(bufnr), bufnr)
end

--- Everything that identifies an environment, without the root: two buffers of
--- the same project share a signature even when they were opened from
--- different directories.
function M.signature(env)
  return table.concat({ env.python or "", table.concat(env.extra_paths, ";") }, "\0")
end

--------------------------------------------------------------------------------
-- basedpyright settings
--------------------------------------------------------------------------------

local function merge_tables(...)
  local merged = {}
  for _, tbl in ipairs { ... } do
    if type(tbl) == "table" then merged = vim.tbl_deep_extend("force", merged, tbl) end
  end
  return merged
end

--- Basedpyright settings for a detected environment, keeping every other key of
--- the existing settings untouched.
function M.settings(env, base)
  local settings = vim.deepcopy(base or {})

  if env.python and env.python ~= "" then
    settings.python = merge_tables(settings.python, { pythonPath = env.python })
  end

  settings.basedpyright = merge_tables(settings.basedpyright, {
    analysis = { extraPaths = vim.deepcopy(env.extra_paths or {}) },
  })

  return settings
end

--- Settings a client should carry for `env`, merged onto its *live* settings so
--- that keys owned by somebody else - jupynvim adds notebook specific ones - are
--- carried over. Only `python.pythonPath` and
--- `basedpyright.analysis.extraPaths` are ever overwritten.
local function expected_settings(client, env)
  return M.settings(env, client.settings or client.config.settings or {})
end

--- Send the settings to the running server.
---
--- `client.settings` is what basedpyright reads right now, `config.settings` is
--- what the next start begins from. They are written separately on purpose:
--- jupynvim *rebinds* `client.settings` for notebooks to inject the kernel
--- interpreter, so a plain Python buffer sharing that client can be left on the
--- kernel. `config.settings` always keeps the detected environment, and
--- `client.settings` is what repairs the live client.
local function push_settings(client, settings, env)
  client.settings = settings
  if client.config then
    client.config.settings = M.settings(env, client.config.settings or {})
  end

  client:notify("workspace/didChangeConfiguration", { settings = client.settings })
end

--- Static configuration, so that clients started later - by lspconfig or by
--- jupynvim - see the same environment.
local function apply_static(env)
  local settings = M.settings(env)

  local ok, astrolsp = pcall(require, "astrolsp")
  if ok then
    local config = astrolsp.config.config or {}
    local server = config[M.server]
    if server then
      settings = M.settings(env, server.settings)
      server.settings = settings
    end
  end

  -- lspconfig keeps its own copy of the resolved options, and that copy is
  -- what `make_config()` hands to a client started later.
  local ok_configs, configs = pcall(require, "lspconfig.configs")
  if ok_configs then
    local server = configs[M.server]
    local stored = server and server.manager and server.manager.config
    if stored then stored.settings = M.settings(env, stored.settings) end
  end

  return settings
end

--- Apply the detected environment to every basedpyright client of this
--- instance. Each client gets the environment of its own project root.
---
--- A *restart* is reserved for a real environment change (the signature of the
--- client's root differs from the one last applied). Settings that merely drifted
--- - jupynvim swapping the interpreter of a client that also serves plain Python
--- buffers - are repaired with a cheap `workspace/didChangeConfiguration`, so the
--- two can never turn into a restart loop.
---@return integer restarted, integer pushed
function M.apply_at(root, opts)
  opts = opts or {}
  local restarted, pushed = 0, 0
  local signatures = {}

  for _, client in ipairs(clients()) do
    if not client:is_stopped() then
      local plain, notebooks = client_buffers(client)

      if root and client.root_dir and client.root_dir ~= root then
        -- Refresh only this project, never leak the current interpreter into others.
      elseif #plain == 0 and #notebooks > 0 then
        -- Notebook-only client: the kernel interpreter wins.
      else
        local client_root = client.root_dir or root or M.detect_root(nil)
        local env = M.detect_at(client_root)
        local settings = expected_settings(client, env)
        signatures[env.root] = M.signature(env)

        if not vim.deep_equal(settings, client.settings) then
          local changed = M.state.signatures[env.root] ~= M.signature(env)
          if opts.restart and changed and #plain > 0 and M.restart_client(client, settings, plain) then
            restarted = restarted + 1
          else
            push_settings(client, settings, env)
            pushed = pushed + 1
          end
        end
      end
    end
  end

  if root then signatures[root] = M.signature(M.detect_at(root)) end
  for key, value in pairs(signatures) do
    M.state.signatures[key] = value
  end

  return restarted, pushed
end

--- Restart one basedpyright client, keeping cmd, capabilities, flags and the
--- whole `on_attach` chain astrolsp and jupynvim installed on it.
function M.restart_client(client, settings, buffers)
  local bufnr = buffers and buffers[1]
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return false end

  local config = vim.deepcopy(client.config)
  config.settings = settings

  local id = client.id
  vim.lsp.stop_client(id, false)

  vim.defer_fn(function()
    if vim.lsp.get_client_by_id(id) and not vim.lsp.get_client_by_id(id).is_stopped() then
      vim.lsp.stop_client(id, true)
    end

    local new_id = vim.lsp.start(config, {
      bufnr = bufnr,
      silent = true,
      -- Never reuse: the default predicate would hand back the client that is
      -- shutting down right now.
      reuse_client = function() return false end,
    })

    if not new_id then return end
    for _, other in ipairs(buffers or {}) do
      if other ~= bufnr and vim.api.nvim_buf_is_valid(other) then
        pcall(vim.lsp.buf_attach_client, other, new_id)
      end
    end
  end, 250)

  return true
end

--- Re-detect the environment of the current buffer and hand it to basedpyright.
function M.apply(opts)
  opts = opts or {}
  local bufnr = resolve_bufnr(opts.bufnr)
  local root = M.detect_root(bufnr)

  -- Per-client settings only. Mutating a global server config leaks across roots.
  M.state.checks[root] = nil
  return M.apply_at(root, opts)
end

--- Push the environment of a freshly attached client. Runs for one buffer only
--- and never restarts anything: the client was just started with the static
--- configuration and only needs the per-project values.
function M.attach(client, bufnr)
  if not client or client.name ~= M.server then return end
  if is_notebook_buffer(resolve_bufnr(bufnr)) then return end

  bufnr = resolve_bufnr(bufnr)
  local env = M.detect(bufnr)
  local settings = expected_settings(client, env)

  M.state.signatures[env.root] = M.signature(env)
  if not vim.deep_equal(settings, client.settings) then push_settings(client, settings, env) end
end

--------------------------------------------------------------------------------
-- commands
--------------------------------------------------------------------------------

local function report(text, level)
  vim.notify(text, level or vim.log.levels.INFO, { title = "Python environment" })
end

--- Human readable summary of a detected environment.
function M.describe(env)
  local lines = {
    "Python environment",
    "Interpreter: " .. (env.python or "-"),
    "Detected by: " .. (env.source or "none"),
    "Project root: " .. (env.root or "-"),
    "CONDA_PREFIX: " .. (env.conda_prefix or "-"),
    "VIRTUAL_ENV: " .. (env.virtual_env or "-"),
  }

  local function block(label, values)
    table.insert(lines, label .. ":")
    if #values == 0 then
      table.insert(lines, "  -")
      return
    end
    for _, value in ipairs(values) do
      table.insert(lines, "  " .. value)
    end
  end

  block("PYTHONPATH", M.split_pythonpath(env.pythonpath))
  block("Basedpyright extraPaths", env.extra_paths or {})
  if env.notebook then table.insert(lines, "Notebook kernel: " .. env.notebook) end

  return table.concat(lines, "\n")
end

local function refresh(opts)
  opts = opts or {}
  local env = M.detect(opts.bufnr)
  local restarted, pushed = M.apply { bufnr = opts.bufnr, restart = true }
  return env, restarted, pushed
end

local function command_env()
  report(M.describe(M.detect(0)))
end

local function command_refresh()
  local env, restarted, pushed = refresh {}
  local lines = {
    M.describe(env),
    ("Refreshed: %d basedpyright client(s) restarted, %d updated"):format(restarted, pushed),
  }
  report(table.concat(lines, "\n"))
end

--- Check the environment of a buffer and hand it to basedpyright. Called from
--- DirChanged/BufEnter. `apply_at` only restarts a client when the detected
--- environment really changed, and only notifies when the live settings drifted,
--- so this is a no-op in the common case.
function M.check(bufnr)
  bufnr = resolve_bufnr(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or is_notebook_buffer(bufnr) then return end

  local ft = vim.bo[bufnr].filetype
  local name = vim.api.nvim_buf_get_name(bufnr)
  local looks_like_python = name:lower():sub(-3) == ".py"
    or name:lower():sub(-4) == ".pyi"
  if ft ~= "python" and not looks_like_python then return end

  local root = M.detect_root(bufnr)
  local key = table.concat({ vim.env.CONDA_PREFIX or "", vim.env.VIRTUAL_ENV or "", vim.env.PYTHONPATH or "", vim.env.PATH or "" }, "\0")
  local now = vim.uv.now()
  local cached = M.state.checks[root]
  if cached and cached.key == key and now - cached.time < 2000 then return end
  M.state.checks[root] = { key = key, time = now }
  local env = M.detect_at(root)
  local restarted, pushed = M.apply_at(root, { restart = false })

  if restarted + pushed == 0 then return end
  report(
    ("Python environment updated for %s\nInterpreter: %s"):format(root, env.python or "-")
  )
end

local function setup_commands()
  vim.api.nvim_create_user_command("PythonEnv", command_env, {
    desc = "Show the detected Python environment",
  })

  vim.api.nvim_create_user_command("PythonEnvRefresh", command_refresh, {
    desc = "Re-detect the Python environment and update basedpyright",
  })
end

local function setup_autocmds()
  local group = vim.api.nvim_create_augroup("UserPythonEnv", { clear = true })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group, callback = function(args) M.state.roots[args.buf] = nil end,
  })
  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    desc = "Re-check the Python environment after the working directory changed",
    callback = function() M.check(vim.api.nvim_get_current_buf()) end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = { "*.py", "*.pyi" },
    desc = "Re-check the Python environment when entering a Python buffer",
    callback = function(args) M.check(args.buf) end,
  })
end

--- Idempotent: registers :PythonEnv, :PythonEnvRefresh and the autocommands.
function M.setup()
  setup_commands()
  setup_autocmds()
end

return M
