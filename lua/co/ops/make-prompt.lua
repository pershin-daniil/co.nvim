--- @param context co.Prompt
--- @param prompt string
--- @param opts co.ops.Opts
--- @return string, co.Reference[]
return function(context, prompt, opts)
  local user_prompt = opts.additional_prompt
  assert(
    user_prompt and type(user_prompt) == "string" and #user_prompt > 0,
    "you must add a prompt to you request"
  )

  local full_prompt = prompt
  full_prompt = context.co.prompts.prompts.prompt(user_prompt, full_prompt)
  return full_prompt, {}
end
