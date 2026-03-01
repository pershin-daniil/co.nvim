---@param buffer number
---@return string
local function get_file_contents(buffer)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  return table.concat(lines, "\n")
end

local prompts = {
  output_file = function()
    return [[
NEVER alter any file other than TEMP_FILE.
never provide the requested changes as conversational output. Return only the code.
ONLY provide requested changes by writing the change to TEMP_FILE
]]
  end,
  prompt = function(prompt, action, name)
    name = name or "Prompt"
    return string.format(
      [[
<Context>
%s
</Context>
<%s>
%s
</%s>
]],
      action,
      name,
      prompt,
      name
    )
  end,
  visual_selection = function(range)
    return string.format(
      [[
You receive a selection in neovim that you need to replace with new code.
The selection's contents may contain notes, incorporate the notes every time if there are some.
consider the context of the selection and what you are supposed to be implementing.
<SELECTION_LOCATION>
%s
</SELECTION_LOCATION>
<SELECTION_CONTENT>
%s
</SELECTION_CONTENT>
<FILE_CONTAINING_SELECTION>
%s
</FILE_CONTAINING_SELECTION>
]],
      range:to_string(),
      range:to_text(),
      get_file_contents(range.buffer)
    )
  end,
  read_tmp = function()
    return [[
never attempt to read TEMP_FILE.
It is purely for output.
Previous contents, which may not exist, can be written over without worry.
After writing TEMP_FILE once you should be done and end the session.
]]
  end,
}

local prompt_settings = {
  prompts = prompts,

  --- @param tmp_file string
  --- @return string
  tmp_file_location = function(tmp_file)
    return string.format("<TEMP_FILE>%s</TEMP_FILE>", tmp_file)
  end,

  --- @return string
  only_tmp_file_change = function()
    return string.format(
      "<MustObey>\n%s\n%s\n</MustObey>",
      prompts.output_file(),
      prompts.read_tmp()
    )
  end,

  --- @param full_path string
  --- @param range co.Range
  --- @return string
  get_file_location = function(full_path, range)
    return string.format(
      "<Location><File>%s</File><Function>%s</Function></Location>",
      full_path,
      range:to_string()
    )
  end,

  --- @param range co.Range
  --- @return string
  get_range_text = function(range)
    return string.format("<FunctionText>%s</FunctionText>", range:to_text())
  end,
}

return prompt_settings
