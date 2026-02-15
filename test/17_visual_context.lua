local M = require('aider-pop')
local mock_bin = './aider_mock_17.sh'
local log_file = './aider_17.log'

-- Global timeout
vim.defer_fn(function() 
    print("❌ Test timed out after 15s")
    os.exit(1) 
end, 15000)

-- Create mock binary
local f = io.open(mock_bin, "w")
f:write("#!/bin/bash\n")
f:write("while read line; do echo \"$line\" >> " .. log_file .. "; done\n")
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ binary = mock_bin })

-- Create a dummy buffer with text
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Line 1", "Line 2", "Line 3" })
vim.api.nvim_set_current_buf(buf)

-- Simulate :2,3AI explain
vim.cmd("2,3AI explain")

-- Wait for output in log
local ok = vim.wait(5000, function()
    local lf = io.open(log_file, "r")
    if not lf then return false end
    local content = lf:read("*a")
    lf:close()
    return content:match("explain") and content:match("Line 2") and content:match("Line 3")
end)

M.stop()
os.remove(mock_bin)
if io.open(log_file, "r") then os.remove(log_file) end

if ok then
    print("✅ Milestone 17 passed")
    os.exit(0)
else
    print("❌ Visual context not received correctly")
    os.exit(1)
end
