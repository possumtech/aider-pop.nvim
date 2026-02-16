# aider-pop.nvim

A minimalist, modal-first Neovim interface for [aider](https://aider.chat).

## Features

- **🚀 Instant Modal:** Toggle a floating Aider terminal with a single key.
- **🚦 Statusline Dashboard:** Minimalist, high-signal state tracking (Idle, Busy, Blocked, Unread) and chat file count.
- **🎭 Contextual Routing:** Use prefixes like `?` for questions or `!` for shell commands.
- **🎯 Visual Selection:** Send code snippets directly to Aider as context.
- **♻️ Bidirectional Sync:** Neovim and Aider keep their file lists in sync (optional).

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "possumtech/aider-pop.nvim",
  lazy = false,
  keys = {
    { "<leader>a", "<cmd>AiderPopToggle<cr>", desc = "Toggle Aider" },
  },
  opts = {
    statusline = true, -- Automatically add to your statusline
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
- `:AiderPopOnCompletionToggle`: Toggle whether to automatically pop up when Aider finishes a task.

### Visual Mode

Select code and type `:AI?` to ask about it, or `:AI:` to refactor it. The selection is automatically wrapped in a markdown block for Aider.

## Configuration

Default options:

```lua
require('aider-pop').setup({
  binary = "aider",
  args = { "--no-gitignore", "--yes-always", "--no-pretty" },
  width = 0.8,
  height = 0.8,
  border = "rounded",
  statusline = false,
  sync_buffers = false, -- Auto /add and /drop files as you open/close them in Neovim
  pop_on_completion = false, -- Automatically pop up when Aider finishes a task
  resume_session = true,     -- Automatically open a file from the chat on startup
  on_start = nil, -- Shell command to run when Aider starts
  on_stop = nil,  -- Shell command to run when Aider stops
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

### Events
The plugin fires `User` autocommands that you can hook into:
- `AiderStart`: Fired when the Aider process has successfully started.
- `AiderStop`: Fired when the Aider process has stopped.

Example:
```lua
vim.api.nvim_create_autocmd("User", {
    pattern = "AiderStart",
    callback = function()
        print("Aider is ready!")
    end
})
```
