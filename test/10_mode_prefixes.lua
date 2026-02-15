local M = require('aider-pop')
local mock_bin = './aider_mock_10.sh'
local log_file = './aider_input_10.log'

-- Create mock binary
local f = io.open(mock_bin, "w")
f:write("#!/bin/bash\n")
f:write("while read line; do echo \"$line\" >> " .. log_file .. "; done\n")
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ binary = mock_bin })

M.send("? how does this work?")
M.send("! ls -la")

local function check_log()
  local lf = io.open(log_file, 'r')
  if not lf then return false end
  local content = lf:read('*a')
  lf:close()
  return content and content:match('/ask how does this work?') and content:match('/run ls %-la')
end

local ok = vim.wait(2000, check_log, 100)

M.stop()
os.remove(mock_bin)
os.remove(log_file)

if ok then
  os.exit(0)
else
  print("❌ Mode prefix routing failed")
  os.exit(1)
end
