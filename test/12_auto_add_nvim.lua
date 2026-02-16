local M = require('aider-pop')
local mock_bin = './aider_mock_12.sh'
local log_file = './aider_input_12.log'

-- Create mock binary
local f = io.open(mock_bin, "w")
f:write([=[#!/bin/bash
printf "architect> "
while read line; do
  echo "$line" >> ]=] .. log_file .. [=[
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

-- Simulate opening a file
local test_file = "test_sync_file.lua"
local tf = io.open(test_file, "w")
tf:write("-- test")
tf:close()

vim.cmd("edit " .. test_file)

-- Verify that /add was sent
local ok = vim.wait(5000, function()
    local lf = io.open(log_file, "r")
    if not lf then return false end
    local content = lf:read("*a")
    lf:close()
    return content:match("/add " .. test_file)
end)

M.stop()
os.remove(mock_bin)
os.remove(test_file)
if io.open(log_file, "r") then os.remove(log_file) end

if ok then
    print("✅ Milestone 12 passed")
    os.exit(0)
else
    print("❌ Failed: /add command was not sent for opened buffer")
    os.exit(1)
end
