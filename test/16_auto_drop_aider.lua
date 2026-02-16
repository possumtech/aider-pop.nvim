local M = require('aider-pop')
local job = require('aider-pop.job')
local mock_bin = './aider_mock_16.sh'

-- Create file first
local test_file = "file.lua"
local tf = io.open(test_file, "w")
tf:write("-- test")
tf:close()

-- Create mock binary
local f = io.open(mock_bin, "w")
f:write([=[#!/bin/bash
# Startup: file is in chat
echo "Files in chat:"
echo "  file.lua"
echo ""
printf "architect> "

while read -r line; do
  if [[ "$line" == *"/drop file.lua"* ]]; then
    echo "Readonly: "
    echo "Editable: "
    printf "architect> "
  else
    printf "architect> "
  fi
done
]=])
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ 
    binary = mock_bin,
    sync_buffers = true
})

-- Wait for initial sync
vim.wait(10000, function() 
    return M.is_idle and next(job.repo_files) ~= nil 
end)

-- Ensure file is open
vim.cmd("edit " .. test_file)

-- Trigger /drop
M.send("/drop file.lua")

-- Verify closed
local ok = vim.wait(15000, function()
    local abs_path = vim.loop.fs_realpath(test_file)
    return vim.fn.bufexists(abs_path) == 0
end, 200)

M.stop()
os.remove(mock_bin)
os.remove(test_file)

if ok then
    print("✅ Milestone 16 passed")
    os.exit(0)
else
    print("❌ Failed: Neovim did not close file.lua after aider /drop")
    os.exit(1)
end
