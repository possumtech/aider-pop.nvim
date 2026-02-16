local M = require('aider-pop')
local mock_bin = './aider_mock_16.sh'

-- Create mock binary that outputs a /drop command
local f = io.open(mock_bin, "w")
f:write([=[#!/bin/bash
printf "architect> "
while read line; do
  if [[ "$line" == *"/ls"* ]]; then
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
    sync = { active_buffers = true }
})

-- Create and open file.lua
local tf = io.open("file.lua", "w")
tf:write("-- test")
tf:close()
vim.cmd("edit file.lua")

-- Wait for initial idle
vim.wait(5000, function() return M.is_idle end)

-- Trigger the /drop from aider
M.send("/drop file.lua")

-- Verify that Neovim closed file.lua
local ok = vim.wait(10000, function()
    local buffers = vim.api.nvim_list_bufs()
    for _, b in ipairs(buffers) do
        local name = vim.api.nvim_buf_get_name(b)
        if name:match("file.lua") and vim.api.nvim_buf_is_valid(b) then 
            return false 
        end
    end
    return true
end, 200)

M.stop()
os.remove(mock_bin)
os.remove("file.lua")

if ok then
    print("✅ Milestone 16 passed")
    os.exit(0)
else
    print("❌ Failed: Neovim did not close file.lua after aider /drop")
    os.exit(1)
end
