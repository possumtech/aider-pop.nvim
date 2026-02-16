local M = require('aider-pop')
local mock_bin = './aider_mock_10.sh'
local log_file = './aider_input_10.log'

-- Create mock binary
local f = io.open(mock_bin, "w")
local script = string.format([=[#!/bin/bash
MODE="architect"
printf "%s> " "$MODE"
while read line; do 
    echo "$line" >> %s
    if [[ "$line" == "/ask" ]]; then MODE="ask"
    elif [[ "$line" == "/run" ]]; then MODE="run"
    elif [[ "$line" == "/architect" ]]; then MODE="architect"
    fi
    printf "%s> " "$MODE"
done
]=], "%s", log_file, "%s")
f:write(script)
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ binary = mock_bin })

-- Wait for initial idle
vim.wait(2000, function() return not M.is_blocked end)

M.send("? how does this work?")
M.send("! ls -la")

local function check_log()
  local lf = io.open(log_file, 'r')
  if not lf then return false end
  local content = lf:read('*a')
  lf:close()
  return content and content:match("/ask") and content:match("how does this work?") and content:match("/run") and content:match("ls %-la")
end

local ok = vim.wait(10000, check_log, 100)

M.stop()
os.remove(mock_bin)
if io.open(log_file, "r") then os.remove(log_file) end

if ok then
  print("✅ Milestone 10 passed")
  os.exit(0)
else
  print("❌ Mode prefix routing failed")
  os.exit(1)
end
