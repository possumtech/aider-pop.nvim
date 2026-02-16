# aider-pop.nvim

A minimalist, modal-first Neovim interface for [aider](https://aider.chat).

## Features

- **🚀 Instant Modal:** Toggle a floating Aider terminal with a single key.
- **🚦 Statusline Dashboard:** Minimalist, high-signal state tracking (Idle, Busy, Blocked, Unread) and chat file count.
- **🎭 Contextual Routing:** Use prefixes like `?` for questions or `!` for shell commands.
- **🎯 Visual Selection:** Send code snippets directly to Aider as context.
- **♻️ Auto-Recovery:** Automatically relaunches Aider if it crashes or exits.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "aider-pop.nvim",
  keys = {
    { "<leader>a", "<cmd>AiderPopToggle<cr>", desc = "Toggle Aider" },
  },
  opts = {
    ui = {
      statusline = true, -- Automatically add to your statusline
    }
  }
}
```

## Usage

### Commands

- `:AI <message>`: Send a message to Aider.
- `:AI? <question>`: Ask a question (mapped to `/ask`).
- `:AI: <instruction>`: Architect mode (mapped to `/architect`).
- `:AI! <command>`: Run a shell command (mapped to `/run`).
- `:AI/ <cmd>`: Direct Aider slash command (e.g., `:AI/add file.lua`).
- `:AiderPopToggle`: Toggle the floating window.

### Visual Mode

Select code and type `:AI?` to ask about it, or `:AI:` to refactor it. The selection is automatically wrapped in a markdown block for Aider.

## Configuration

Default options:

```lua
require('aider-pop').setup({
  binary = "aider",
  args = { "--no-gitignore", "--yes-always", "--no-pretty" },
  ui = {
    width = 0.8,
    height = 0.8,
    border = "rounded",
    statusline = false,
  }
})
```

To manually add the status to your custom statusline:
`require('aider-pop').status()`

### Dashboard Indicators
The status component returns a string in the format `[Emoji] [Count]` (e.g., `🤖 3`):
- `🤖`: Aider is idle and ready.
- `⏳`: Aider is busy processing or generating.
- `✋`: Aider is blocked and waiting for user confirmation (Y/N).
- `✨`: New output has arrived since you last closed the modal.
- `💀`: The Aider background process is offline.

### Integration Examples

#### [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)
```lua
sections = {
  lualine_x = {
    { function() return require('aider-pop').status() end }
  }
}
```

#### Manual Statusline
```lua
vim.o.statusline = vim.o.statusline .. "%= %{v:lua.require('aider-pop').status()}"
```
