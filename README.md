# co.nvim
A minimal Codex-first Neovim plugin for `visual` workflows.

## Scope
`co.nvim` is intentionally small:
- Codex CLI backend only (via `codex exec`)
- Public API: `setup`, `visual`
- Single workflow: select code in visual mode, type prompt, replace selection

Everything else from the legacy multi-provider surface was removed.

## Prerequisites (Arch Linux)
Install required tools:

```bash
sudo pacman -S --needed neovim make stylua luacheck openai-codex
```

`openai-codex` provides the `codex` CLI used by this plugin.

Verify install:

```bash
codex --version
nvim --version
```

## Installation
```lua
{
  "your-org/co.nvim",
  config = function()
    local co = require("co")

    co.setup({
      model = "gpt-5.3-codex", -- optional
      tmp_dir = "./tmp",       -- optional, defaults to ./tmp
      treesitter = false,      -- optional, defaults to false
    })
  end,
}
```

## Keymaps
```lua
local co = require("co")

vim.keymap.set("v", "<leader>cv", function()
  co.visual()
end)
```

## API
### `require("co").setup(opts?)`
Configures plugin state, status UI, and model.

Options:
- `model?: string` default: `"gpt-5.3-codex"`
- `tmp_dir?: string` default: `"./tmp"`
- `display_errors?: boolean` default: `false`
- `treesitter?: boolean` default: `false`
- `logger?` and `in_flight_options?` for logging/status window behavior

### `require("co").visual(opts?)`
Captures a prompt (or uses `opts.additional_prompt`) and replaces the selected range with Codex output.

Common `opts` for `visual`:
- `additional_prompt?: string`

Returns the request id (`number`).

## Prompt Context
`co.nvim` does not require rule/file tokens.
The request context is built from your visual selection, file content, and internal prompt safety rules.

## Testing
`make lua_test` runs tests via Plenary:

```bash
make lua_test
```

`make pr_ready` runs lint + tests + format check:

```bash
make pr_ready
```

If Plenary is not already available in your Neovim runtime path, one simple local setup is:

```bash
git clone https://github.com/nvim-lua/plenary.nvim.git ../plenary.nvim
```
