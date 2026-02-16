local M = require('aider-pop')
local mock_bin = './aider_mock_13.sh'
local log_file = './aider_input_13.log'

-- Create mock binary
local f = io.open(mock_bin, "w")
f:write([=[#!/bin/bash
printf "architect> "
while read line; do
  echo "$line" >> ]=] .. log_file .. [=[
  echo ""
  printf "architect> "
done
]=])
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ 
    binary = mock_bin,
    sync = { active_buffers = true }
})

-- Wait for initial idle
vim.wait(5000, function() return M.is_idle end)

-- Open a help buffer (buftype=help)
vim.cmd("help")

-- Verify that /add was NOT sent
vim.wait(2000) -- give it a moment
local lf = io.open(log_file, "r")
local content = lf and lf:read("*a") or ""
if lf then lf:close() end

M.stop()
os.remove(mock_bin)
if io.open(log_file, "r") then os.remove(log_file) end

if content:match("/add") then
    print("❌ Failed: Special buffer triggered /add. Content: '" .. content .. "'")
    os.exit(1)
else
    print("✅ Milestone 13 passed")
    os.exit(0)
end
