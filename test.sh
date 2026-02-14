#!/bin/bash

# Aider Pop Test Runner
# Runs all Lua tests in /test using headless Neovim

set -e

FAILED=0
TOTAL=0

echo "🚀 Starting aider-pop.nvim test suite..."
echo "---------------------------------------"

for test_file in test/*.lua; do
    if [ -f "$test_file" ]; then
        ((TOTAL++))
        echo -n "Running $(basename "$test_file")... "
        
        # Run Neovim headlessly, add current dir to runtimepath, and run the test file
        if nvim --headless -u NONE \
            --cmd "set runtimepath+=." \
            -c "luafile $test_file" \
            -c "qa!" 2>/dev/null; then
            echo "✅ PASS"
        else
            echo "❌ FAIL"
            FAILED=$((FAILED + 1))
        fi
    fi
done

echo "---------------------------------------"
if [ $FAILED -eq 0 ]; then
    echo "🎉 All $TOTAL tests passed!"
    exit 0
else
    echo "⚠️ $FAILED/$TOTAL tests failed."
    exit 1
fi
