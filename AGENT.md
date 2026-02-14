# Implementation Roadmap

This document tracks the progress of `aider-pop.nvim`. Each milestone is considered complete only when its corresponding test in `/test` passes via `test.sh`.

## 🛠 Phase 1: Core Process & Communication
- [ ] **Background Job Initiation**: Aider starts headlessly on plugin load/command.
    - `test/01_process_spawn.lua`
- [ ] **Basic Command Routing**: `:AI:` sends raw text to the Aider process.
    - `test/02_command_routing.lua`
- [ ] **Mode Switching**: `:AI?` and `:AI!` correctly prefix messages with `/ask` and `/run`.
    - `test/03_mode_prefixes.lua`

## 🏗 Phase 2: Context Management
- [ ] **Auto-Add Buffers**: Opening a file triggers a `/add` command to Aider.
    - `test/04_auto_add.lua`
- [ ] **Visual Selection**: Visual mode commands include the selected text as context.
    - `test/05_visual_context.lua`

## 🖥 Phase 3: User Interface
- [ ] **The Modal Toggle**: `<C-a>` opens/closes a floating window showing the Aider buffer.
    - `test/06_modal_ui.lua`
- [ ] **Statusline Integration**: `require('aider-pop').status()` returns correct symbols based on process state.
    - `test/07_status_api.lua`

## 🔗 Phase 4: Extensions & Hooks
- [ ] **User Autocommands**: `AiderStart` and `AiderStop` fire with unique IDs.
    - `test/08_autocmd_events.lua`
- [ ] **System Hooks**: Configured shell commands execute on start/stop.
    - `test/09_system_hooks.lua`
