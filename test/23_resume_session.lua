local M = require('aider-pop')
local job = require('aider-pop.job')
local mock_bin = './aider_mock_23.sh'

-- Create dummy file
local test_file = "resume_test.lua"
local tf = io.open(test_file, "w")
tf:write("-- resume test")
tf:close()

-- Create mock binary that reports the file in chat immediately
local f = io.open(mock_bin, "w")
f:write([=[#!/bin/bash
echo "Files in chat:"
echo "  resume_test.lua"
echo ""
printf "architect> "
while read line; do
  printf "architect> "
done
]=])
f:close()
os.execute("chmod +x " .. mock_bin)

-- We need to mock argc() because in headless test it might be different
-- but we can just ensure we are on a blank unnamed buffer.
vim.cmd("enew") 

M.setup({ 
    binary = mock_bin,
    resume_session = true
})

-- Wait for resumption
local abs_path = vim.loop.fs_realpath(test_file)
local ok = vim.wait(5000, function()
    return vim.api.nvim_buf_get_name(0) == abs_path
end)

M.stop()
os.remove(mock_bin)
os.remove(test_file)

if ok then
    print("✅ Milestone 23 passed (Session Resumption)")
    os.exit(0)
else
    print("❌ Failed: Plugin did not resume session. Current buffer: " .. vim.api.nvim_buf_get_name(0))
    os.exit(1)
end
