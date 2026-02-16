local M = require('aider-pop')
local mock_bin = './aider_mock_11.sh'
local log_file = './aider_input_11.log'

-- Create mock binary
local f = io.open(mock_bin, "w")
local script = string.format([=[#!/bin/bash
MODE="architect"
printf "%s> " "$MODE"
while read line; do 
    echo "$line" >> %s
    printf "%s> " "$MODE"
done
]=], "%s", log_file, "%s")
f:write(script)
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ binary = mock_bin })

-- Wait for initial idle
vim.wait(2000, function() return not M.is_blocked end)

-- Test direct slash command
M.send("/ tokens")
-- Test AI/ prefix (which should also result in a slash command)
M.send("/ add file.txt")

local function check_log()
  local lf = io.open(log_file, 'r')
  if not lf then return false end
  local content = lf:read('*a')
  lf:close()
  return content and content:find("/tokens", 1, true) and content:find("/add file.txt", 1, true)
end

local ok = vim.wait(5000, check_log, 100)

M.stop()
os.remove(mock_bin)
if io.open(log_file, "r") then os.remove(log_file) end

if ok then
  print("✅ Milestone 11 passed")
  os.exit(0)
else
  print("❌ Slash command routing failed")
  os.exit(1)
end
