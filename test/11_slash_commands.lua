local M = require('aider-pop')
local mock_bin = './aider_mock_11.sh'
local log_file = './aider_input_11.log'

-- Create mock binary
local f = io.open(mock_bin, "w")
f:write("#!/bin/bash\n")
f:write("while read line; do echo \"$line\" >> " .. log_file .. "; done\n")
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ binary = mock_bin })

-- Test direct slash command
M.send("/tokens")
-- Test AI/ prefix (which should also result in a slash command)
M.send("/ add file.txt")

local function check_log()
  local lf = io.open(log_file, 'r')
  if not lf then return false end
  local content = lf:read('*a')
  lf:close()
  return content and content:find("/tokens", 1, true) and content:find("/add file.txt", 1, true)
end

local ok = vim.wait(2000, check_log, 100)

M.stop()
os.remove(mock_bin)
os.remove(log_file)

if ok then
  os.exit(0)
else
  print("❌ Slash command routing failed")
  os.exit(1)
end
