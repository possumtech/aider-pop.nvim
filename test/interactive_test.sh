#!/bin/bash

# Get the absolute path of the project root
REPO_ROOT=$(pwd)

# Create a temporary init.lua for the interactive session
# Use .lua extension to force nvim to treat it as lua config
TEMP_INIT=$(mktemp).lua

cat <<EOF > "$TEMP_INIT"
-- Add the plugin to runtimepath
vim.opt.runtimepath:append("$REPO_ROOT")

-- Setup the plugin with some default dev options
require('aider-pop').setup({
    args = { "--no-auto-commits", "--dark-mode" }
})

-- Suggest a keybinding for the user
-- Note: AiderPopToggle is not implemented yet in the code
vim.keymap.set('n', '<leader>a', function() 
    print("AiderPopToggle not implemented yet. Use :AI, :AI?, :AI!, :AI/ commands.")
end, { desc = "Toggle Aider Pop (Placeholder)" })

print("🚀 aider-pop.nvim loaded!")
print("Try commands: :AI hello, :AI? how are you, :AI! ls")
EOF

# Run Neovim with the temporary config
nvim -u "$TEMP_INIT"

# Cleanup
rm "$TEMP_INIT"
