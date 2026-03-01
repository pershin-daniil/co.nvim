local Logger = require("co.logger.logger")
local Level = require("co.logger.level")
local ops = require("co.ops")
local Window = require("co.window")
local StatusWindow = require("co.window.status-window")
local Prompt = require("co.prompt")
local State = require("co.state")
local Provider = require("co.provider")

--- @param opts co.ops.Opts?
--- @return co.ops.Opts
local function process_opts(opts)
  return opts or {}
end

--- @class co.Options
--- @field logger? co.Logger.Options
--- @field model? string
--- @field in_flight_options? co.StatusWindow.Opts
--- @field display_errors? boolean
--- @field treesitter? boolean
--- @field tmp_dir? string
--- @field __request_backend? any

--- @type co.State
local co_state

local M = {
  DEBUG = Level.DEBUG,
  INFO = Level.INFO,
  WARN = Level.WARN,
  ERROR = Level.ERROR,
  FATAL = Level.FATAL,
}

--- @param cb fun(context: co.Prompt, o: co.ops.Opts?): nil
--- @param name string
--- @param context co.Prompt
--- @param opts co.ops.Opts
local function capture_prompt(cb, name, context, opts)
  Window.capture_input(name, {
    cb = function(ok, response)
      context.logger:debug(
        "capture_prompt",
        "success",
        ok,
        "response",
        response
      )
      if not ok then
        return
      end
      opts.additional_prompt = response
      context.user_prompt = response
      cb(context, opts)
    end,
  })
end

--- @param opts co.ops.Opts?
--- @return number
function M.visual(opts)
  opts = process_opts(opts)
  local context = Prompt.visual(co_state)
  if opts.additional_prompt then
    context.user_prompt = opts.additional_prompt
    ops.over_range(context, opts)
  else
    capture_prompt(ops.over_range, "Visual", context, opts)
  end
  return context.xid
end

--- @return co.State
function M.__get_state()
  return co_state
end

function M.__stop_all_requests()
  co_state.tracking:stop_all_requests()
end

--- @param opts co.Options?
function M.setup(opts)
  opts = opts or {}

  co_state = State.new(opts)

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      M.__stop_all_requests()
      co_state:sync()
    end,
  })

  Logger:configure(opts.logger)

  if opts.model then
    assert(type(opts.model) == "string", "opts.model is not a string")
    co_state.model = opts.model
  else
    co_state.model = Provider.default_model()
  end

  if opts.tmp_dir then
    assert(type(opts.tmp_dir) == "string", "opts.tmp_dir must be a string")
  end
  co_state.__tmp_dir = opts.tmp_dir

  co_state.display_errors = opts.display_errors or false

  local sw = StatusWindow.new(co_state, opts.in_flight_options)
  sw:start()
end

function M.__debug()
  Logger:configure({
    path = nil,
    level = Level.DEBUG,
  })
end

return M
