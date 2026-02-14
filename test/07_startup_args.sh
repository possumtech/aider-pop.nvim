#!/bin/bash
# Mock aider binary to capture arguments
MOCK_BIN="./aider_mock.sh"
LOG_FILE="aider_args.log"

cat <<EOF > "$MOCK_BIN"
#!/bin/bash
echo "\$@" > "$LOG_FILE"
EOF
chmod +x "$MOCK_BIN"

# Run Neovim to trigger aider-pop setup
# We use an absolute path for MOCK_BIN to ensure it's found regardless of where nvim is started
MOCK_BIN_ABS=$(pwd)/aider_mock.sh

nvim --headless -u NONE \
    --cmd "set runtimepath+=." \
    -c "lua require('aider-pop').setup({ binary = '$MOCK_BIN_ABS', args = { '--dark-mode', '--no-git' } })" \
    -c "lua vim.wait(2000, function() return vim.fn.filereadable('$LOG_FILE') == 1 end)" \
    -c "qa!"

# Verify the log file contains the expected arguments
if [ -f "$LOG_FILE" ] && grep -q -- "--dark-mode --no-git" "$LOG_FILE"; then
    rm "$MOCK_BIN" "$LOG_FILE"
    exit 0
else
    echo "Test failed: Arguments not correctly passed."
    [ -f "$LOG_FILE" ] && echo "Log content: $(cat "$LOG_FILE")" || echo "Log file not found."
    rm -f "$MOCK_BIN" "$LOG_FILE"
    exit 1
fi
