local M = require('aider-pop')
local mock_bin = './aider_mock_15.sh'
local log_file = './aider_input_15.log'

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
    sync_buffers = true
})

-- Wait for initial idle
vim.wait(5000, function() return M.is_idle end)

-- Create and open a file
local test_file = "test_drop_file.lua"
local tf = io.open(test_file, "w")
tf:write("-- test")
tf:close()
vim.cmd("edit " .. test_file)
local bufnr = vim.fn.bufnr(test_file)

-- Wait for /add to be processed so we have a clean state for /drop
vim.wait(2000, function() 
    local lf = io.open(log_file, "r")
    if not lf then return false end
    local content = lf:read("*a")
    lf:close()
    return content:match("/add " .. test_file)
end)

-- Now delete the buffer
vim.cmd("bdelete " .. bufnr)

-- Verify that /drop was sent
local ok = vim.wait(5000, function()
    local lf = io.open(log_file, "r")
    if not lf then return false end
    local content = lf:read("*a")
    lf:close()
    local found = content:match("/drop " .. test_file)
    if not found then
        print("State: idle=" .. tostring(M.is_idle) .. " queue_len=" .. #require('aider-pop.job').command_queue)
    end
    return found
end)

M.stop()
os.remove(mock_bin)
os.remove(test_file)
if io.open(log_file, "r") then os.remove(log_file) end

if ok then
    print("✅ Milestone 15 passed")
    vim.wait(500)
    M.stop()
    os.remove(mock_bin)
    os.remove(test_file)
    if io.open(log_file, "r") then os.remove(log_file) end
    os.exit(0)
else
    print("❌ Failed: /drop command was not sent for deleted buffer")
    local lf = io.open(log_file, "r")
    if lf then
        print("Log content: '" .. lf:read("*a") .. "'")
        lf:close()
    end
    M.stop()
    os.remove(mock_bin)
    os.remove(test_file)
    os.exit(1)
end
