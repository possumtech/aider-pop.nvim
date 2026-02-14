#!/bin/bash
nvim --headless -u NONE \
    --cmd "set runtimepath+=." \
    -c "lua require('aider-pop').setup()" \
    -c "lua if not require('aider-pop').is_running() then os.exit(1) end" \
    -c "qa!"
