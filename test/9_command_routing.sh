#!/bin/bash
# Test that :AI sends raw text to the Aider process

MOCK_BIN="./aider_mock_9.sh"
LOG_FILE="aider_input_9.log"

cat <<EOF > "$MOCK_BIN"
#!/bin/bash
read line
echo "\$line" >> "$LOG_FILE"
EOF
chmod +x "$MOCK_BIN"

MOCK_BIN_ABS=$(pwd)/aider_mock_9.sh

nvim --headless -n -u NONE \
    --cmd "set runtimepath+=." \
    -c "lua require('aider-pop').setup({ binary = '$MOCK_BIN_ABS' })" \
    -c "AI : hello from neovim" \
    -c "lua vim.wait(500)" \
    -c "qa!"

if [ -f "$LOG_FILE" ] && grep -q "hello from neovim" "$LOG_FILE"; then
    echo "✅ Test passed: Command routed to Aider."
    rm "$MOCK_BIN" "$LOG_FILE"
    exit 0
else
    echo "❌ Test failed: Command not routed to Aider."
    [ -f "$LOG_FILE" ] && echo "Log content: $(cat "$LOG_FILE")" || echo "Log file not found."
    rm -f "$MOCK_BIN" "$LOG_FILE"
    exit 1
fi
