--- @class co.Provider.Observer
--- @field on_stdout fun(line: string): nil
--- @field on_stderr fun(line: string): nil
--- @field on_complete fun(status: co.Prompt.EndingState, res: string): nil
--- @field on_start fun(): nil

local M = {}

--- @param fn fun(...: any): nil
--- @return fun(...: any): nil
local function once(fn)
  local called = false
  return function(...)
    if called then
      return
    end
    called = true
    fn(...)
  end
end

--- @return string
function M.default_model()
  return "gpt-5.3-codex"
end

--- @param context co.Prompt
--- @return boolean, string
local function retrieve_response(context)
  local logger = context.logger:set_area("CodexBackend")
  local tmp = context.tmp_file
  local success, result = pcall(function()
    return vim.fn.readfile(tmp)
  end)

  if not success then
    logger:error(
      "retrieve_results: failed to read file",
      "tmp_name",
      tmp,
      "error",
      result
    )
    return false, ""
  end

  local str = table.concat(result, "\n")
  logger:debug("retrieve_results", "results", str)

  return true, str
end

--- @param query string
--- @param context co.Prompt
--- @param observer co.Provider.Observer
function M.make_request(_, query, context, observer)
  observer.on_start()

  local logger = context.logger:set_area("CodexBackend")
  logger:debug("make_request", "tmp_file", context.tmp_file)

  local once_complete = once(
    --- @param status "success" | "failed" | "cancelled"
    --- @param text string
    function(status, text)
      observer.on_complete(status, text)
    end
  )

  local command = {
    "codex",
    "exec",
    "--full-auto",
    "--skip-git-repo-check",
    "--model",
    context.model,
    query,
  }

  logger:debug("make_request", "command", command)

  local proc = vim.system(
    command,
    {
      text = true,
      stdout = vim.schedule_wrap(function(err, data)
        if context:is_cancelled() then
          once_complete("cancelled", "")
          return
        end
        if err and err ~= "" then
          logger:debug("stdout#error", "err", err)
        end
        if not err and data then
          observer.on_stdout(data)
        end
      end),
      stderr = vim.schedule_wrap(function(err, data)
        if context:is_cancelled() then
          once_complete("cancelled", "")
          return
        end
        if err and err ~= "" then
          logger:debug("stderr#error", "err", err)
        end
        if not err and data then
          observer.on_stderr(data)
        end
      end),
    },
    vim.schedule_wrap(function(obj)
      if context:is_cancelled() then
        once_complete("cancelled", "")
        logger:debug("on_complete: request has been cancelled")
        return
      end

      if obj.code ~= 0 then
        local str =
          string.format("process exit code: %d\n%s", obj.code, vim.inspect(obj))
        once_complete("failed", str)
        logger:error("CodexBackend request failed", "obj from results", obj)
      else
        vim.schedule(function()
          local ok, res = retrieve_response(context)
          if ok then
            once_complete("success", res)
          else
            once_complete(
              "failed",
              "unable to retrieve response from temp file"
            )
          end
        end)
      end
    end)
  )

  context:_set_process(proc)
end

return M
