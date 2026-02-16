#!/bin/bash

# Get the absolute path of the project root
REPO_ROOT=$(pwd)

# Create a temporary init.lua for the interactive session
TEMP_INIT=$(mktemp).lua

cat <<EOF > "$TEMP_INIT"
-- Add the plugin to runtimepath
vim.opt.runtimepath:append("$REPO_ROOT")

-- Setup the plugin
require('aider-pop').setup({
    args = { "--no-gitignore" },
    ui = { statusline = true },
    sync_buffers = true
})

vim.o.laststatus = 2

-- Map leader-a to toggle
vim.keymap.set('n', '<leader>a', '<cmd>AiderPopToggle<cr>', { desc = "Toggle Aider Pop" })

print("🚀 aider-pop.nvim loaded with --no-gitignore!")
EOF

# Run Neovim with the temporary config
nvim -u "$TEMP_INIT"

# Cleanup
rm "$TEMP_INIT"
