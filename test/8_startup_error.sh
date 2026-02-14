#!/bin/bash
# Test that aider-pop notifies the user when the binary is missing

nvim --headless -n -u NONE \
    --cmd "set runtimepath+=." \
    -c "lua _G.notified = false; vim.notify = function(msg) if msg:find('aider binary not found') then _G.notified = true end end" \
    -c "lua require('aider-pop').setup({ binary = 'non-existent-binary' })" \
    -c "lua if _G.notified then vim.cmd('qa!') else vim.cmd('cq!') end"
