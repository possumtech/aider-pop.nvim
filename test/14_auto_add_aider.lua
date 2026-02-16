local M = require('aider-pop')
local mock_bin = './aider_mock_14.sh'

-- Create mock binary that outputs a /add command
local f = io.open(mock_bin, "w")
f:write([=[#!/bin/bash
printf "architect> "
while read line; do
  if [[ "$line" == *"/ls"* ]]; then
    echo "Readonly: "
    echo "Editable: file.lua"
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

-- Create dummy file.lua
local tf = io.open("file.lua", "w")
tf:write("-- test")
tf:close()

-- Wait for initial idle
vim.wait(5000, function() return M.is_idle end)

-- Trigger the /add from aider (simulating user action)
M.send("/add file.lua")

-- Verify that Neovim opened file.lua
local ok = vim.wait(10000, function()
    local buffers = vim.api.nvim_list_bufs()
    for _, b in ipairs(buffers) do
        local name = vim.api.nvim_buf_get_name(b)
        if name:match("file.lua") then return true end
    end
    return false
end, 200)

M.stop()
os.remove(mock_bin)
os.remove("file.lua")

if ok then
    print("✅ Milestone 14 passed")
    os.exit(0)
else
    print("❌ Failed: Neovim did not open file.lua after aider /add")
    os.exit(1)
end
