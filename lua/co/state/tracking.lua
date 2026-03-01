local Prompt = require("co.prompt")

--- @class co.State.Tracking.Serialized
--- @field requests co.Prompt.Serialized[]

--- @class co.State.Tracking.Config.Options.Counts
--- @field search number | nil
--- @field visual number | nil

--- @class co.State.Tracking.Config.Options
--- @field serialize_counts co.State.Tracking.Config.Options.Counts | nil

--- @class co.State.Tracking
--- @field history co.Prompt[]
--- @field id_to_request table<number, co.Prompt>
local Tracking = {}
Tracking.__index = Tracking

--- @param co_state co.State
--- @param previous_state co.State.Tracking.Serialized | nil
--- @return co.State.Tracking
function Tracking.new(co_state, previous_state)
  local tracking = setmetatable({}, Tracking)

  tracking.history = {}
  tracking.id_to_request = {}

  if not previous_state then
    return tracking
  end

  for _, d in ipairs(previous_state.requests or {}) do
    local prompt = Prompt.deserialize(co_state, d)
    table.insert(tracking.history, prompt)
    tracking.id_to_request[prompt.xid] = prompt
  end

  return tracking
end

--- @param context co.Prompt
function Tracking:track(context)
  assert(context:valid(), "context is not valid")
  table.insert(self.history, context)
  self.id_to_request[context.xid] = context
end

function Tracking:stop_all_requests()
  for _, r in pairs(self:active()) do
    r:stop()
  end
end

--- @return co.Prompt[]
function Tracking:active()
  local out = {}
  for _, r in pairs(self.history) do
    if r.state == "requesting" then
      table.insert(out, r)
    end
  end
  return out
end

function Tracking:active_count()
  local count = 0
  for _, r in pairs(self.history) do
    if r.state == "requesting" then
      count = count + 1
    end
  end
  return count
end

--- @return co.Prompt[]
function Tracking:successful()
  local out = {}
  for _, r in ipairs(self.history) do
    if r.state == "success" then
      table.insert(out, r)
    end
  end
  return out
end

--- @return co.State.Tracking.Serialized
function Tracking:serialize()
  local sc = Tracking.__config.serialize_count

  --- @type table<co.Prompt.Operation, co.Prompt[]>
  local all_requests = {}
  for _, r in ipairs(self.history) do
    local op = r.operation
    all_requests[op] = all_requests[op] or {}
    if r.state == "success" and sc[op] > 0 then
      table.insert(all_requests[op], r)
    end
  end

  for op, _ in pairs(sc) do
    all_requests[op] = all_requests[op] or {}
    local requests_by_op = all_requests[op]
    table.sort(requests_by_op, function(a, b)
      return a.started_at > b.started_at
    end)
  end

  local requests = {}
  for op, max in pairs(sc) do
    local count = 0
    for _, request in ipairs(all_requests[op] or {}) do
      if count >= max then
        break
      end
      table.insert(requests, request)
      count = count + 1
    end
  end

  table.sort(requests, function(a, b)
    return a.started_at > b.started_at
  end)

  local serialized = {}
  for _, r in ipairs(requests) do
    table.insert(serialized, r:serialize())
  end

  return {
    requests = serialized,
  }
end

Tracking.__config = {
  serialize_count = {
    search = 3,
    visual = 0,
  },
}

--- @param opts co.State.Tracking.Config.Options
function Tracking.setup(opts)
  local config = Tracking.__config
  local opts_sa = opts.serialize_counts
  if opts_sa then
    local sa = config.serialize_count
    sa.search = opts_sa.search or sa.search
    sa.visual = opts_sa.visual or sa.visual
  end
end

return Tracking
