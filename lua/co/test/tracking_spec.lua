-- luacheck: globals describe it assert
local co = require("co")
local Tracking = require("co.state.tracking")
local test_utils = require("co.test.test_utils")
local Prompt = require("co.prompt")
local eq = assert.are.same

--- @param state co.State
--- @param prompt string
--- @param started_at number
--- @param status co.Prompt.State
local function tracked_visual(state, prompt, started_at, status)
  local request = Prompt.deserialize(state, {
    user_prompt = prompt,
    data = {
      type = "visual",
      buffer = 1,
      file_type = "lua",
      range = {
        buffer = 1,
        start = { row = 1, col = 1 },
        ["end"] = { row = 1, col = 1 },
      },
    },
  })
  request.started_at = started_at
  request.state = status
  return request
end

describe("tracking", function()
  it("serializes visual requests based on configured counts", function()
    local previous_counts = vim.deepcopy(Tracking.__config.serialize_count)
    Tracking.setup({
      serialize_counts = {
        search = 0,
        visual = 1,
      },
    })

    local provider = test_utils.TestProvider.new()
    co.setup(test_utils.get_test_setup_options({
      in_flight_options = { enable = false },
    }, provider))
    local state = co.__get_state()
    local tracking = state.tracking

    tracking:track(tracked_visual(state, "visual one", 100, "success"))
    tracking:track(tracked_visual(state, "visual two", 200, "success"))
    tracking:track(tracked_visual(state, "visual failed", 300, "failed"))

    local serialized = tracking:serialize()
    eq(1, #serialized.requests)
    eq("visual", serialized.requests[1].data.type)
    eq("visual two", serialized.requests[1].user_prompt)

    Tracking.__config.serialize_count = previous_counts
  end)
end)
