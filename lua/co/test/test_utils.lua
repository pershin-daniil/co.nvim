local Levels = require("co.logger.level")
local M = {}

--- @type co.Providers.Observer
local DevNullObserver = {
  on_start = function() end,
  on_complete = function() end,
  on_stderr = function() end,
  on_stdout = function() end,
}

function M.next_frame()
  local next = false
  vim.schedule(function()
    next = true
  end)

  vim.wait(1000, function()
    return next
  end)
end

M.created_files = {}

--- @class co.test.ProviderRequest
--- @field query string
--- @field prompt co.Prompt
--- @field observer co.Providers.Observer
--- @field logger co.Logger

--- @class co.test.Provider : co.Providers.BaseProvider
--- @field request co.test.ProviderRequest?
local TestProvider = {}
TestProvider.__index = TestProvider

function TestProvider.new()
  return setmetatable({}, TestProvider)
end

--- @param query string
---@param prompt co.Prompt
---@param observer co.Providers.Observer?
function TestProvider:make_request(query, prompt, observer)
  local logger = prompt.logger:set_area("TestProvider")
  logger:debug("make_request", "tmp_file", prompt.tmp_file)

  observer = observer or DevNullObserver
  observer.on_start()

  self.request = {
    query = query,
    prompt = prompt,
    observer = observer,
    logger = logger,
  }
end

--- @param status co.Prompt.EndingState
--- @param result string
function TestProvider:resolve(status, result)
  assert(self.request, "you cannot call resolve until make_request is called")

  if self.request.prompt:is_cancelled() then
    self.request.observer.on_complete("cancelled", result)
  else
    self.request.observer.on_complete(status, result)
  end

  self.request = nil
end

--- @param line string
function TestProvider:stdout(line)
  assert(self.request, "you cannot call stdout until make_request is called")
  self.request.observer.on_stdout(line)
end

--- @param line string
function TestProvider:stderr(line)
  assert(self.request, "you cannot call stderr until make_request is called")
  self.request.observer.on_stderr(line)
end

M.TestProvider = TestProvider

function M.clean_files()
  for _, bufnr in ipairs(M.created_files) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  M.created_files = {}
end

---@param contents string[]
---@param file_type string?
---@param row number?
---@param col number?
function M.create_file(contents, file_type, row, col)
  assert(type(contents) == "table", "contents must be a table of strings")
  file_type = file_type or "lua"
  local bufnr = vim.api.nvim_create_buf(false, false)

  vim.api.nvim_set_current_buf(bufnr)
  vim.bo[bufnr].ft = file_type
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
  vim.api.nvim_win_set_cursor(0, { row or 1, col or 0 })

  table.insert(M.created_files, bufnr)
  return bufnr
end

--- @param opts co.Options | nil
--- @param provider co.Providers.BaseProvider
--- @return co.Options
function M.get_test_setup_options(opts, provider)
  opts = opts or {}
  opts.tmp_dir = opts.tmp_dir or vim.fn.tempname()
  opts.__request_backend = provider
  opts.logger = {
    error_cache_level = Levels.ERROR,
    type = "print",
  }
  opts.in_flight_options = opts.in_flight_options
    or {
      throbber_opts = {
        tick_time = 10,
        throb_time = 1000,
        cooldown_time = 500,
      },
      in_flight_interval = 10,
      enable = true,
    }
  return opts
end

--- @param content string[]
--- @param row number
--- @param col number
--- @param lang string?
--- @param opts co.Options | nil
--- @return co.test.Provider, number
function M.test_setup(content, row, col, lang, opts)
  lang = lang or "lua"
  local provider = M.TestProvider.new()
  require("co").setup(M.get_test_setup_options(opts, provider))

  local buffer = M.create_file(content, lang, row, col)
  return provider, buffer
end

--- @param buffer number
--- @return string[]
function M.r(buffer)
  return vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
end

return M
