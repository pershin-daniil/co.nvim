local utils = require("co.utils")
local Tracking = require("co.state.tracking")
local Provider = require("co.provider")

local STATE_FILE = "co-state"

--- @class co.StateProps
--- @field model string
--- @field prompts co.Prompts
--- @field ai_stdout_rows number
--- @field display_errors boolean
--- @field treesitter boolean
--- @field __tmp_dir string | nil

--- @class co.State
--- @field model string
--- @field prompts co.Prompts
--- @field ai_stdout_rows number
--- @field display_errors boolean
--- @field treesitter boolean
--- @field tracking co.State.Tracking
--- @field __tmp_dir string | nil
--- @field request_backend any
local State = {}
State.__index = State

--- @return co.StateProps
local function create()
  return {
    model = Provider.default_model(),
    ai_stdout_rows = 3,
    display_errors = false,
    treesitter = false,
    tmp_dir = nil,
  }
end

--- @param oos co.Options | co.State
local function get_tmp_dir(oos)
  local tmp_dir = oos.tmp_dir and type(oos.tmp_dir) == "string" and oos.tmp_dir
    or oos.__tmp_dir and oos.__tmp_dir
    or "./tmp"
  if tmp_dir then
    tmp_dir = vim.fn.expand(tmp_dir)
  end
  return tmp_dir
end

--- @param opts co.Options
--- @return co.State.Tracking.Serialized | nil
local function read_state_from_tmp(opts)
  local state_file = utils.named_tmp_file(get_tmp_dir(opts), STATE_FILE)
  return utils.read_file_json_safe(state_file)
end

--- @param opts co.Options
--- @return co.State
function State.new(opts)
  local props = create()
  local co_state = setmetatable(props, State)

  if opts.treesitter ~= nil then
    assert(
      type(opts.treesitter) == "boolean",
      "opts.treesitter must be a boolean"
    )
    co_state.treesitter = opts.treesitter
  end

  co_state.request_backend = opts.__request_backend or Provider
  co_state.prompts = require("co.prompt-settings")

  local previous = read_state_from_tmp(opts)
  co_state.tracking = Tracking.new(co_state, previous)

  return co_state
end

function State:sync()
  local tracking = self.tracking:serialize()
  local tmp = self:tmp_dir()
  local file = utils.named_tmp_file(tmp, STATE_FILE)
  utils.write_file_json_safe(tracking, file)
end

--- @return string
function State:tmp_dir()
  return get_tmp_dir(self)
end

return State
