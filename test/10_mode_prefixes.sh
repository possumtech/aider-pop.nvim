#!/bin/bash
# Test that :AI? and :AI! send correct prefixes

set -e

MOCK_BIN="./aider_mock_10.sh"
LOG_FILE="aider_input_10.log"

# Create mock binary that logs all input
cat <<EOF > "$MOCK_BIN"
#!/bin/bash
while read line; do
  echo "\$line" >> "$LOG_FILE"
done
EOF
chmod +x "$MOCK_BIN"

MOCK_BIN_ABS=$(pwd)/aider_mock_10.sh

# Run nvim to test both modes in one go
nvim --headless -n -u NONE \
    --cmd "set runtimepath+=." \
    -c "lua require('aider-pop').setup({ binary = '$MOCK_BIN_ABS' })" \
    -c "AI ? how does this work?" \
    -c "AI ! ls -la" \
    -c "lua vim.wait(1000)" \
    -c "qa!"

# Check output
FAIL=0
if ! grep -q "/ask how does this work?" "$LOG_FILE"; then
    echo "❌ Ask mode failed."
    FAIL=1
fi

if ! grep -q "/run ls -la" "$LOG_FILE"; then
    echo "❌ Run mode failed."
    FAIL=1
fi

if [ $FAIL -eq 1 ]; then
    echo "Log content:"
    cat "$LOG_FILE"
    rm -f "$MOCK_BIN" "$LOG_FILE"
    exit 1
fi

rm -f "$MOCK_BIN" "$LOG_FILE"
exit 0
