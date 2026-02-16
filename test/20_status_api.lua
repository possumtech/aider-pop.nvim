local M = require('aider-pop')
local job = require('aider-pop.job')
local mock_bin = './aider_mock_20.sh'

-- Global timeout
vim.defer_fn(function() 
    print("❌ Test timed out after 15s")
    os.exit(1) 
end, 15000)

-- Create mock binary
local f = io.open(mock_bin, "w")
f:write([=[#!/bin/bash
printf "architect> "
while read line; do
  if [[ "$line" == *"What is 2+2"* ]]; then
    echo "The answer is 4."
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

-- 1. Check Busy state
M.send("? What is 2+2?")
if not M.status():match("⏳") then
    print("❌ Status did not show busy icon. Got: '" .. M.status() .. "'")
    os.exit(1)
end

-- 2. Check Unread state (✨)
local ok = vim.wait(5000, function() 
    return M.status():match("✨")
end)

if not ok then
    print("❌ Status did not show unread icon (✨). Got: '" .. M.status() .. "'")
    os.exit(1)
end

-- 3. Check Idle/Read state (🤖) after opening modal
M.toggle_modal()
M.toggle_modal() -- Close it

if not M.status():match("🤖") then
    print("❌ Status did not show idle icon (🤖) after reading. Got: '" .. M.status() .. "'")
    os.exit(1)
end

print("✅ Milestone 20 passed (New dashboard status logic)")
M.stop()
os.remove(mock_bin)
os.exit(0)
