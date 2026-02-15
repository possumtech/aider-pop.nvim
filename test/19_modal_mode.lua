local M = require('aider-pop')
local mock_bin = './aider_mock_19.sh'
local log_file = './aider_19.log'

-- Global timeout
vim.defer_fn(function() 
    print("❌ Test timed out after 15s")
    os.exit(1) 
end, 15000)

-- Create mock binary that starts with a prompt, then an idle prompt
local f = io.open(mock_bin, "w")
f:write("#!/bin/bash\n")
f:write("printf \"One-time setup? (y/n): \"\n")
f:write("read setup_ans\n")
f:write("echo \"Setup: $setup_ans\" > " .. log_file .. "\n")
f:write("printf \"> \"\n")
f:write("while read line; do echo \"Cmd: $line\" >> " .. log_file .. "; printf \"> \"; done\n")
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ binary = mock_bin })

-- 1. Verify auto-open on blocked setup prompt
-- We need to wait for stdout to trigger the state check timer
local ok = vim.wait(5000, function()
    return M.window and vim.api.nvim_win_is_valid(M.window) and M.is_blocked
end)

if not ok then
    print("❌ Failed to auto-open on blocked prompt. State: is_blocked=" .. tostring(M.is_blocked))
    M.stop()
    os.remove(mock_bin)
    os.exit(1)
end

-- 2. Send command while blocked (should be queued)
M.send("hello")
local lf = io.open(log_file, "r")
local content = lf and lf:read("*a") or ""
if lf then lf:close() end
if content:match("hello") then
    print("❌ Command was sent while blocked instead of queued")
    M.stop()
    os.remove(mock_bin)
    os.exit(1)
end

-- 3. Answer the prompt manually (simulating user interaction)
vim.api.nvim_chan_send(M.job_id, "y\n")

-- 4. Verify queue was processed once idle
ok = vim.wait(5000, function()
    local f2 = io.open(log_file, "r")
    if not f2 then return false end
    local c = f2:read("*a")
    f2:close()
    return c:match("Setup: y") and c:match("Cmd: hello")
end)

if ok then
    print("✅ Milestone 19 passed")
    M.stop()
    os.remove(mock_bin)
    if io.open(log_file, "r") then os.remove(log_file) end
    os.exit(0)
else
    print("❌ Queue failed to process after returning to idle")
    M.stop()
    os.remove(mock_bin)
    os.exit(1)
end
