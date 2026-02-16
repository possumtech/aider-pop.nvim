local M = require('aider-pop')
local job = require('aider-pop.job')
local mock_bin = './aider_mock_12.sh'
local log_file = './aider_input_12.log'

-- Create mock binary
local f = io.open(mock_bin, "w")
f:write([=[#!/bin/bash
echo "Repo files not in the chat:"
echo "  test_sync_file.lua"
echo ""
printf "architect> "
IN_CHAT=false
while read line; do
  if [[ "$line" == *"/add test_sync_file.lua"* ]]; then
    IN_CHAT=true
    echo "$line" >> ]=] .. log_file .. [=[
    printf "architect> "
  elif [[ "$line" == *"/ls"* ]]; then
    if [ "$IN_CHAT" = true ]; then
      echo "Editable: test_sync_file.lua"
    else
      echo "Repo files not in the chat:"
      echo "  test_sync_file.lua"
    fi
    printf "architect> "
  else
    echo "$line" >> ]=] .. log_file .. [=[
    printf "architect> "
  fi
done
]=])
f:close()
os.execute("chmod +x " .. mock_bin)

-- 1. Create dummy file first so it exists for /ls to find
local test_file = "test_sync_file.lua"
local tf = io.open(test_file, "w")
tf:write("-- test")
tf:close()

M.setup({ 
    binary = mock_bin,
    sync_buffers = true
})

-- 2. Wait for initial /ls to populate whitelist
vim.wait(10000, function() 
    return next(job.repo_files) ~= nil 
end)

-- 3. Simulate opening the file
vim.cmd("edit " .. test_file)

-- 3. Verify that /add was eventually sent
local ok = vim.wait(15000, function()
    local lf = io.open(log_file, "r")
    if not lf then return false end
    local content = lf:read("*a")
    lf:close()
    return content:match("/add " .. test_file)
end, 500)

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
