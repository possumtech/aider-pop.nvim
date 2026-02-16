# Implementation Roadmap

This document tracks the progress of `aider-pop.nvim`. Each milestone is considered complete only when its corresponding test in `/test` passes via `test.sh`.

## 🛠 Phase 1: Core Process & Communication
- [x] **Background Job Initiation**: Aider starts headlessly on plugin load/command.
    - `test/6_process_spawn.lua`
- [x] **Startup Arguments**: Custom flags (e.g., `--model`, `--light-mode`) are correctly passed to the Aider process.
    - `test/7_startup_args.lua`
- [x] **Error Handling**: Plugin notifies user if `aider` binary is missing or fails to start.
    - `test/8_startup_error.lua`
- [x] **Basic Command Routing**: `:AI:` sends raw text to the Aider process.
    - `test/9_command_routing.lua`
- [x] **Mode Switching**: `:AI?` and `:AI!` correctly prefix messages with `/ask` and `/run`.
    - `test/10_mode_prefixes.lua`
- [x] **Slash Commands**: `:AI/` sends direct slash commands to Aider.
    - `test/11_slash_commands.lua`

## 🖥 Phase 2: User Interface
- [x] **The Modal Toggle**: `:AiderPopToggle` opens/closes a floating window showing the Aider buffer.
    - `test/18_modal_ui.lua`
- [x] **Modal Default Mode**: The modal opens in Normal mode by default (configurable). Handles auto-opening on prompts and idle/blocked state detection.
    - `test/19_modal_mode.lua`
- [x] **Statusline Integration**: `require('aider-pop').status()` returns correct symbols based on process state.
    - `test/20_status_api.lua`
- [x] **Visual Selection**: Visual mode commands include the selected text as context.
    - `test/17_visual_context.lua`

## 🏗 Phase 3: Bidirectional Context Sync
- [x] **Neovim -> Aider (/add)**: Creating or opening a buffer in Neovim triggers a `/add` command to Aider.
    - `test/12_auto_add_nvim.lua`
- [x] **Ignore Non-File Buffers**: Special buffers (e.g., help, quickfix, dashboard) do not trigger `/add`.
    - `test/13_ignore_special_buffers.lua`
- [x] **Aider -> Neovim (/add)**: Aider requesting a file via `/add` (parsed from output) creates or opens the corresponding buffer in Neovim.
    - `test/14_auto_add_aider.lua`
- [x] **Neovim -> Aider (/drop)**: Closing a buffer in Neovim triggers a `/drop` command to Aider.
    - `test/15_auto_drop_nvim.lua`
- [x] **Aider -> Neovim (/drop)**: Aider dropping a file via `/drop` (parsed from output) closes the corresponding buffer in Neovim.
    - `test/16_auto_drop_aider.lua`

## 🔗 Phase 4: Extensions & Hooks
- [ ] **User Autocommands**: `AiderStart` and `AiderStop` fire with unique IDs.
    - `test/21_autocmd_events.lua`
- [ ] **System Hooks**: Configured shell commands execute on start/stop.
    - `test/22_system_hooks.lua`
