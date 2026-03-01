local helpers = require("co.extensions.agents.helpers")
local M = {}

--- @class co.Agents.Rule
--- @docs included
--- @field name string
--- @field path string
--- @field absolute_path string?

--- @class co.Agents.Rules
--- @field custom co.Agents.Rule[]
--- @field by_name table<string, co.Agents.Rule[]>

--- @class co.Agents.Agent
--- @field rules co.Agents.Rules

--- @param map table<string, co.Agents.Rule[]>
--- @param rules co.Agents.Rule[]
local function add_rule_by_name(map, rules)
  for _, r in ipairs(rules) do
    if map[r.name] == nil then
      map[r.name] = {}
    end
    table.insert(map[r.name], r)
  end
end

--- @param co co.State
--- @return co.Agents.Rules
function M.rules(co)
  local custom = {}
  for _, path in ipairs(co.completion.custom_rules or {}) do
    local custom_rules = helpers.ls(path)
    for _, r in ipairs(custom_rules) do
      table.insert(custom, r)
    end
  end

  local by_name = {}
  add_rule_by_name(by_name, custom)
  return {
    by_name = by_name,
    custom = custom,
  }
end

--- @param rules co.Agents.Rules
--- @return co.Agents.Rule[]
function M.rules_to_items(rules)
  local items = {}
  for _, rule in ipairs(rules.custom or {}) do
    table.insert(items, rule)
  end
  return items
end

--- @param rules co.Agents.Rules
--- @param path string
--- @return co.Agents.Rule | nil
function M.get_rule_by_path(rules, path)
  for _, rule in ipairs(rules.custom or {}) do
    if rule.path == path then
      return rule
    end
  end
  return nil
end

--- @param rules co.Agents.Rules
--- @param token string
--- @return boolean
function M.is_rule(rules, token)
  for _, rule in ipairs(rules.custom or {}) do
    if rule.path == token or rule.name == token then
      return true
    end
  end
  return false
end

--- @param rules co.Agents.Rules
--- @param prompt string
--- @return {names: string[], rules: co.Agents.Rules[]}
function M.by_name(rules, prompt)
  --- @type table<string, boolean>
  local found = {}

  --- @type string[]
  local names = {}

  --- @type co.Agents.Rule[]
  local out_rules = {}
  for word in prompt:gmatch("%S+") do
    if word:sub(1, 1) == "#" then
      local w = word:sub(2)
      local rules_by_name = rules.by_name[w]
      if rules_by_name and found[w] == nil then
        for _, r in ipairs(rules_by_name) do
          table.insert(out_rules, r)
        end
        table.insert(names, w)
        found[w] = true
      end
    end
  end

  return {
    names = names,
    rules = out_rules,
  }
end

--- @param rule co.Agents.Rule
--- @return string | nil
function M.get_rule_content(rule)
  local file_path = rule.absolute_path or rule.path
  local ok, file = pcall(io.open, file_path, "r")
  if not ok or not file then
    return nil
  end
  local ok_read, content = pcall(file.read, file, "*a")
  if not ok_read then
    return nil
  end

  pcall(file.close, file)
  return string.format("<%s>\n%s\n</%s>", rule.name, content, rule.name)
end

--- @param co co.State
--- @return co.CompletionProvider
function M.completion_provider(co)
  return {
    trigger = "#",
    name = "rules",
    get_items = function()
      local agent_rules = M.rules_to_items(co.rules)
      local items = {}
      for _, rule in ipairs(agent_rules) do
        local docs = helpers.head(rule.absolute_path or rule.path)
        table.insert(items, {
          label = rule.name,
          insertText = "#" .. rule.path,
          filterText = "#" .. rule.name,
          kind = 12, -- LSP CompletionItemKind.Value
          documentation = { kind = "markdown", value = docs },
          detail = "Rule: " .. rule.path,
        })
      end
      return items
    end,
    is_valid = function(token)
      return M.is_rule(co.rules, token)
    end,
    resolve = function(token)
      local rule = M.get_rule_by_path(co.rules, token)
      if not rule then
        return nil
      end
      return M.get_rule_content(rule)
    end,
  }
end

return M
