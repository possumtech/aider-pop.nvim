local M = require('aider-pop')
local mock_bin = './aider_mock_20.sh'

-- Global timeout
vim.defer_fn(function() 
    print("❌ Test timed out after 15s")
    os.exit(1) 
end, 15000)

-- Create mock binary that simulates the answer structure
local f = io.open(mock_bin, "w")
f:write([=[#!/bin/bash
printf "architect> "
while read line; do
  if [[ "$line" == *"What is 2+2"* ]]; then
    echo "The answer is 4."
    echo ""
    echo "Tokens: 123"
    printf "architect> "
  else
    printf "architect> "
  fi
done
]=])
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ binary = mock_bin })

-- Wait for initial idle
vim.wait(5000, function() return M.is_idle end)

-- 1. Check for "🤖" when new output arrives
M.send("? What is 2+2?")

local ok = vim.wait(5000, function() 
    return M.status():match("The answer is 4")
end)

if ok then
    print("✅ Milestone 20 passed (Status shows answer via 4-step logic)")
    M.stop()
    os.remove(mock_bin)
    os.exit(0)
else
    print("❌ Status did not show answer. Got: '" .. M.status() .. "'")
    M.stop()
    os.remove(mock_bin)
    os.exit(1)
end
