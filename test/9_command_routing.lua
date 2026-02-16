local M = require('aider-pop')
local mock_bin = './aider_mock_09.sh'
local log_file = './aider_input_09.log'

-- Create mock binary
local f = io.open(mock_bin, "w")
local script = string.format([=[#!/bin/bash
MODE="architect"
printf "%s> " "$MODE"
while read line; do 
    echo "$line" >> %s
    printf "%s> " "$MODE"
done
]=], "%s", log_file, "%s")
f:write(script)
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ binary = mock_bin })

-- Wait for initial idle
vim.wait(2000, function() return not M.is_blocked end)

local cases = {
    "hello from neovim",
    "with 'quotes' and \"double quotes\"",
    "with `backticks` and ; semicolons"
}

for _, cmd in ipairs(cases) do
    M.send(cmd)
end

local function check_all_present()
    local lf = io.open(log_file, 'r')
    if not lf then return false end
    local content = lf:read('*a')
    lf:close()
    for _, pattern in ipairs(cases) do
        if not content:find(pattern, 1, true) then return false end
    end
    return true
end

local ok = vim.wait(5000, check_all_present, 100)

M.stop()
os.remove(mock_bin)
if io.open(log_file, "r") then os.remove(log_file) end

if ok then
    os.exit(0)
else
    print("❌ Command routing failed to deliver all messages correctly")
    os.exit(1)
end
