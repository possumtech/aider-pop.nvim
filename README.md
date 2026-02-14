# aider-pop.nvim

**Stay in your code. Let Aider handle the rest.**

`aider-pop.nvim` is a minimalist, editor-first Neovim integration for [Aider](https://aider.chat). It runs a headless Aider session in the background, allowing you to refactor, ask questions, and sync context without ever leaving your buffer or switching tmux panes.

---

## ✨ Features

- **🥷 Headless Execution:** Aider runs in a hidden background buffer. No intrusive terminal windows.
- **🔄 Deep Context Sync:** Opening a buffer automatically `/add`s it to Aider. Running `/add` in the chat automatically opens the file in Neovim.
- **🧠 Mode-Specific Commands:** Native Neovim commands mapped directly to Aider's Architect, Ask, and Run modes.
- **💬 Passive Observation:** Toggle a floating modal to view Aider's output. The modal opens in **Normal Mode** by default, optimized for yanking code blocks and scrolling.
- **🖱️ Visual Selection Support:** Send code snippets directly as context or instructions from Visual Mode.
- **🚦 Statusline Integration:** Minimalist UI indicators for processing states and unread messages.

---

## 📦 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "possumtech/aider-pop.nvim",
    dependencies = { "nvim-lua/plenary.nvim" }, -- Optional: depending on implementation
    cmd = { "AiderPopToggle", "AI" },
    opts = {
        -- Your configuration here
    }
}
```

---

## ⚙️ Configuration

```lua
require("aider-pop").setup({
    -- The binary to run (defaults to "aider")
    binary = "aider",
    -- Default mode for the floating window
    modal_mode = "normal",
    -- Automatically add opened buffers to aider context
    auto_add_buffers = true,
    -- Floating window styling
    ui = {
        width = 0.8,
        height = 0.8,
        border = "rounded",
    }
})
```

---

## 🚀 Usage

### Commands

| Command | Mode | Action |
| :--- | :--- | :--- |
| `:AI: <msg>` | **Architect** | High-level refactoring and code generation (`/architect`). |
| `:AI? <msg>` | **Ask** | Questions about the codebase (`/ask`). |
| `:AI! <cmd>` | **Run** | Execute shell commands via Aider (`/run`). |
| `:AI/ <cmd>` | **Slash** | Direct slash commands (e.g., `:AI/drop`, `:AI/tokens`). |

> **Pro Tip:** In **Visual Mode**, these commands automatically include your selection as context.

### Keybindings

The plugin does not set default keybindings. We recommend mapping a primary toggle key:

```lua
-- Toggle the Aider message history modal
vim.keymap.set('n', '<C-a>', '<cmd>AiderPopToggle<cr>', { desc = "Toggle Aider Pop" })
```

---

## 🔗 Extensions & Hooks

`aider-pop.nvim` provides a robust event system to trigger internal Neovim actions or external system scripts (like playing music or updating hardware lights) during Aider sessions.

### Internal: User Autocommands
The plugin triggers `User` events `AiderStart` and `AiderStop` with a unique request ID.

```lua
vim.api.nvim_create_autocmd("User", {
    pattern = "AiderStart",
    callback = function(ev)
        print("Aider is working on request: " .. ev.data.id)
    end
})
```

### External: System Hooks
You can configure shell commands to run automatically in your `opts`:

```lua
require("aider-pop").setup({
    hooks = {
        on_start = "afplay ~/music/elevator.mp3 &",
        on_stop = "pkill afplay",
    }
})
```

---

## 🎨 UI Indicators

Access the Aider status via `require('aider-pop').status()` for your statusline:

- `🤖` (Blinking): Aider is thinking.
- `🤖` (Static): New information available in the modal.
- ` ` (Empty): Idle.

---

## 🛡️ Philosophy

The developer's home is the source code, not a chat interface. `aider-pop.nvim` aims to eliminate the "terminal tax" of LLM-assisted coding. By treating Aider as a headless engine rather than a destination, you maintain focus on the code while leveraging the most powerful AI coding tool available.

---

## 🤝 Contributing

Contributions are welcome! To maintain a clean and navigable history, this project follows:

- **[Conventional Commits](https://www.conventionalcommits.org/)**: Every commit message must follow the `type: #67 description` format (e.g., `feat: #67 add context sync`), associated with a github issue id that is constructed using the issue templates provided.
- **Conventional Branching**: Please name your branches based on their purpose:
    - `feat/67-...` for new features.
    - `fix/67-...` for bug fixes.
    - `docs/67-...` for documentation.
    - `refactor/67-...` for code cleanup.

---

## 📜 License

MIT
