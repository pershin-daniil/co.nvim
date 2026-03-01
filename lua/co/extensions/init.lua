local Files = require("co.extensions.files")
local Native = require("co.extensions.native")

return {
  --- @param co_state co.State
  init = function(co_state)
    Native.init(co_state)
  end,

  capture_project_root = function()
    local cwd = vim.fn.getcwd()
    local git_root = vim.fs.root(cwd, ".git")
    Files.set_project_root(git_root or cwd)
  end,

  --- @param co_state co.State
  setup_buffer = function(co_state)
    Native.init_for_buffer(co_state)
  end,

  --- @param co_state co.State
  refresh = function(co_state)
    Native.refresh_state(co_state)
  end,
}
