-- luacheck: globals describe it assert
local co = require("co")
local test_utils = require("co.test.test_utils")
local eq = assert.are.same

describe("state", function()
  it("defaults treesitter to false", function()
    local provider = test_utils.TestProvider.new()
    co.setup(test_utils.get_test_setup_options({}, provider))
    local state = co.__get_state()

    eq(false, state.treesitter)
  end)

  it("sets treesitter from setup options", function()
    local provider = test_utils.TestProvider.new()
    co.setup(test_utils.get_test_setup_options({ treesitter = true }, provider))
    local state = co.__get_state()

    eq(true, state.treesitter)
  end)
end)
