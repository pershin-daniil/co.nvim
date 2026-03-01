local M = {}

--- @alias co.Providers.on_complete fun(status: co.Prompt.EndingState, response: string): nil
--- @class co.Providers.PartialObserver
--- @field on_complete co.Providers.on_complete
--- @field on_stdout? fun(line: string): nil
--- @field on_stderr? fun(line: string): nil
--- @field on_start? fun(): nil

--- @param clean_up fun(): nil
--- @param obs_or_fn co.Providers.PartialObserver | co.Providers.on_complete
--- @return co.Providers.Observer
M.make_observer = function(clean_up, obs_or_fn)
  --- @type co.Providers.PartialObserver
  local obs = type(obs_or_fn) == "table" and obs_or_fn
    or {
      on_complete = obs_or_fn,
    }
  return {
    on_start = function()
      if obs.on_start then
        obs.on_start()
      end
    end,
    on_complete = function(status, res)
      vim.schedule(clean_up)
      obs.on_complete(status, res)
    end,
    on_stderr = function(line)
      if obs.on_stderr then
        obs.on_stderr(line)
      end
    end,
    on_stdout = function(line)
      if obs.on_stdout then
        obs.on_stdout(line)
      end
    end,
  } --[[@as co.Providers.Observer ]]
end

---@param clean_up_fn fun(): nil
---@return fun(): nil
M.make_clean_up = function(clean_up_fn)
  local called = false
  local function clean_up()
    if called then
      return
    end
    called = true
    clean_up_fn()
  end
  return clean_up
end

return M
