#!/bin/bash

# Aider Pop Test Runner
# Runs all shell scripts in /test

set -e

FAILED=0
TOTAL=0

echo "🚀 Starting aider-pop.nvim test suite..."
echo "---------------------------------------"

for test_file in test/*.sh; do
    if [ -f "$test_file" ]; then
        ((TOTAL++))
        echo -n "Running $(basename "$test_file")... "
        
        if bash "$test_file"; then
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
