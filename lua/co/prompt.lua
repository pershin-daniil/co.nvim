local Logger = require("co.logger.logger")
local utils = require("co.utils")
local random_file = utils.random_file
local get_id = require("co.id")
local Range = require("co.geo").Range
local Time = require("co.time")

local Provider = require("co.provider")

local function set_selection_marks()
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
    "x",
    false
  )
end

local filetype_map = {
  typescriptreact = "typescript",
}

--- @alias co.Prompt.Data co.Prompt.Data.Search | co.Prompt.Data.Visual
--- @alias co.Prompt.Operation "visual" | "search"
--- @alias co.Prompt.EndingState "failed" | "success" | "cancelled"
--- @alias co.Prompt.State "ready" | "requesting" | co.Prompt.EndingState

--- @class co.Prompt.Serialized
--- @field data co.Prompt.Data
--- @field user_prompt string

--- @class co.Prompt.Data.Search
--- @field type "search"
--- @field qfix_items co.Search.Result[]
--- @field response string

--- @class co.Prompt.Data.Visual
--- @field type "visual"
--- @field buffer number
--- @field file_type string
--- @field range co.Range

--- @class co.Prompt
--- @field model string
--- @field user_prompt string
--- @field operation co.Prompt.Operation
--- @field state co.Prompt.State
--- @field full_path string
--- @field started_at number
--- @field data co.Prompt.Data
--- @field agent_context string[]
--- @field tmp_file string
--- @field marks table<string, co.Mark>
--- @field logger co.Logger
--- @field xid number
--- @field clean_ups (fun(): nil)[]
--- @field _co co.State
--- @field co co.State
--- @field _proc vim.SystemObj?
local Prompt = {}
Prompt.__index = Prompt

--- @param context co.Prompt
--- @param co_state co.State
local function set_defaults(context, co_state)
  local xid = get_id()
  local full_path = vim.api.nvim_buf_get_name(0)

  context.state = "ready"
  context._co = co_state
  context.co = co_state
  context.user_prompt = ""
  context.clean_ups = {}
  context.model = co_state.model
  context.agent_context = {}
  context.tmp_file = random_file(co_state:tmp_dir())
  context.logger = Logger:set_id(xid)
  context.xid = xid
  context.full_path = full_path
  context.marks = {}
  context.started_at = Time.now()
end

--- @param co_state co.State
--- @param data co.Prompt.Serialized
--- @return co.Prompt
function Prompt.deserialize(co_state, data)
  local prompt = setmetatable({
    _co = co_state,
    co = co_state,
    data = data.data,
    operation = data.data.type,
    user_prompt = data.user_prompt,
    started_at = Time.now(),
    xid = get_id(),
  }, Prompt)
  assert(prompt:valid(), "prompt is not valid from data")
  return prompt
end

--- @return co.Prompt.Serialized
function Prompt:serialize()
  return {
    data = self.data,
    user_prompt = self.user_prompt,
  }
end

--- @param co_state co.State
--- @return co.Prompt
function Prompt.visual(co_state)
  set_selection_marks()
  local range = Range.from_visual_selection()

  local file_type = vim.bo[0].ft
  local buffer = vim.api.nvim_get_current_buf()
  file_type = filetype_map[file_type] or file_type

  local context = setmetatable({}, Prompt)
  set_defaults(context, co_state)
  context.operation = "visual"
  context.data = {
    type = "visual",
    buffer = buffer,
    file_type = file_type,
    range = range,
  }
  context.logger:debug("co Request", "method", "visual")

  return context
end

--- @param co_state co.State
--- @return co.Prompt
function Prompt.search(co_state)
  local context = setmetatable({}, Prompt)
  set_defaults(context, co_state)
  context.operation = "search"
  context.data = {
    type = "search",
    qfix_items = {},
    response = "",
  }
  context.logger:debug("co Request", "method", "search")

  return context
end

--- @return string
function Prompt:summary()
  local prompt_str = utils.split_with_count(self.user_prompt, 8)
  return string.format("%s: %s", self.operation, table.concat(prompt_str, " "))
end

--- @param obs co.Provider.Observer | nil
function Prompt:_observer(obs)
  return {
    on_start = function()
      self.state = "requesting"
      self._co.tracking:track(self)

      if obs then
        obs.on_start()
      end
    end,
    on_complete = function(status, res)
      self.state = status
      if obs then
        obs.on_complete(status, res)
      end
    end,
    on_stderr = function(line)
      if obs then
        obs.on_stderr(line)
      end
    end,
    on_stdout = function(line)
      if obs then
        obs.on_stdout(line)
      end
    end,
  }
end

local allowed_context_types = {
  "visual",
  "search",
}

--- @return boolean
function Prompt:valid()
  local t = self.data.type
  for _, allowed in ipairs(allowed_context_types) do
    if t == allowed then
      return true
    end
  end
  return false
end

--- @param observer co.Provider.Observer?
function Prompt:start_request(observer)
  local l = self.logger
  l:assert(
    self.state == "ready",
    'state is not "ready" when attempting to start a request'
  )

  local ok = self:finalize()
  l:assert(ok, "context failed to finalize")

  local prompt = table.concat(self.agent_context, "\n")
  local obs = self:_observer(observer)
  local backend = self._co.request_backend or Provider

  self:save_prompt(prompt)
  l:debug("start", "prompt", prompt)

  backend:make_request(prompt, self, obs)
end

function Prompt:is_cancelled()
  return self.state == "cancelled"
end

function Prompt:is_completed()
  return self.state == "success" or self.state == "failed"
end

--- @param proc vim.SystemObj?
function Prompt:_set_process(proc)
  self._proc = proc
end

function Prompt:cancel()
  if self:is_cancelled() or self:is_completed() then
    return
  end

  self.state = "cancelled"
  local proc = self._proc
  if proc and proc.pid then
    self._proc = nil
    pcall(function()
      local sigterm = (vim.uv and vim.uv.constants and vim.uv.constants.SIGTERM)
        or 15
      proc:kill(sigterm)
    end)
  end
end

--- @return co.Prompt.Data.Visual
function Prompt:visual_data()
  assert(
    self.data.type == "visual",
    "you cannot get visual data if its not type visual"
  )
  return self.data
end

--- @return co.Prompt.Data.Search
function Prompt:search_data()
  assert(
    self.data.type == "search",
    "you cannot get search data if its not type search"
  )
  return self.data
end

--- @return co.Search.Result[]
function Prompt:qfix_data()
  assert(
    self.data.type == "search",
    "data type is not search: " .. self.data.type
  )
  return self.data.qfix_items
end

function Prompt:stop()
  self:cancel()
  for _, cb in ipairs(self.clean_ups) do
    cb()
  end
end

--- @param clean_up fun(): nil
function Prompt:add_clean_up(clean_up)
  table.insert(self.clean_ups, clean_up)
end

--- @param content string
--- @return self
function Prompt:add_prompt_content(content)
  table.insert(self.agent_context, content)
  return self
end

--- @param refs co.Reference[]
function Prompt:add_references(refs)
  for _, ref in ipairs(refs) do
    self.logger:debug("adding reference to context")
    table.insert(self.agent_context, ref.content)
  end
end

--- @return string[]
function Prompt:content()
  return self.agent_context
end

--- @return boolean
function Prompt:_ready_request_files()
  local response_file = self.tmp_file
  local prompt_file = self.tmp_file .. "-prompt"

  local dir = vim.fs.dirname(prompt_file)

  if dir and not vim.uv.fs_stat(dir) then
    vim.fn.mkdir(dir, "p")
  end

  local files = { prompt_file, response_file }
  for _, f in ipairs(files) do
    local file = io.open(f, "w")
    if file then
      file:write("")
      file:close()
    else
      self.logger:error("unable to create prompt file")
      return false
    end
  end
  return true
end

--- @param prompt string
function Prompt:save_prompt(prompt)
  local prompt_file = self.tmp_file .. "-prompt"
  local file = io.open(prompt_file, "w")
  if file then
    file:write(prompt)
    file:close()
    self.logger:debug("saved prompt to file", "path", prompt_file)
  else
    self.logger:error("failed to save prompt", "path", prompt_file)
  end
end

--- @return boolean, self
function Prompt:finalize()
  if self:_ready_request_files() == false then
    return false, self
  end

  local ok, visual_data = pcall(self.visual_data, self)
  if ok then
    local f_loc =
      self._co.prompts.get_file_location(self.full_path, visual_data.range)
    table.insert(self.agent_context, f_loc)
    table.insert(
      self.agent_context,
      self._co.prompts.get_range_text(visual_data.range)
    )
  end

  table.insert(
    self.agent_context,
    self._co.prompts.tmp_file_location(self.tmp_file)
  )
  table.insert(self.agent_context, self._co.prompts.only_tmp_file_change())

  return true, self
end

function Prompt:clear_marks()
  for _, mark in pairs(self.marks) do
    mark:delete()
  end
end

return Prompt
