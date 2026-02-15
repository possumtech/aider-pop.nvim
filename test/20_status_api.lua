local M = require('aider-pop')
local mock_bin = './aider_mock_20.sh'

-- Global timeout
vim.defer_fn(function() 
    print("❌ Test timed out after 15s")
    os.exit(1) 
end, 15000)

-- Create mock binary
local f = io.open(mock_bin, "w")
f:write("#!/bin/bash\n")
f:write("sleep 0.1\n")
f:write("echo \"Initial output\"\n")
f:write("sleep 1\n")
f:write("echo \"More output\"\n")
f:write("while true; do sleep 0.1; done\n")
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ binary = mock_bin })

-- 1. Initially should be empty or bot (depending on how fast it starts)
-- Wait for first output
local ok = vim.wait(5000, function() return M.status() == "🤖" end)

if not ok then
    print("❌ Status should be 🤖 when there is unread output")
    M.stop()
    os.remove(mock_bin)
    os.exit(1)
end

-- 2. Toggle modal ON -> should remain bot (and update last_read_line)
M.toggle_modal()
if M.status() ~= "🤖" then
    print("❌ Status should be 🤖 when modal is open")
    M.stop()
    os.remove(mock_bin)
    os.exit(1)
end

-- 3. Toggle modal OFF -> should be empty (all caught up)
M.toggle_modal()
if M.status() ~= "" then
    print("❌ Status should be empty when all output is read. Got: '" .. M.status() .. "'")
    M.stop()
    os.remove(mock_bin)
    os.exit(1)
end

-- 4. Wait for more output from mock
ok = vim.wait(5000, function() return M.status() == "🤖" end)

if not ok then
    print("❌ Status should be 🤖 again after new output arrives")
    M.stop()
    os.remove(mock_bin)
    os.exit(1)
end

M.stop()
os.remove(mock_bin)
print("✅ Milestone 20 passed")
os.exit(0)
