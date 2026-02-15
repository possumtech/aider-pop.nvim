local M = require('aider-pop')
local mock_bin = './aider_mock_09.sh'
local log_file = './aider_input_09.log'

-- Create mock binary
local f = io.open(mock_bin, "w")
f:write("#!/bin/bash\n")
f:write("while read line; do echo \"$line\" >> " .. log_file .. "; done\n")
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ binary = mock_bin })

local cases = {
    "hello from neovim",
    "multiline\ninput",
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

local ok = vim.wait(3000, check_all_present, 100)

M.stop()
os.remove(mock_bin)
os.remove(log_file)

if ok then
    os.exit(0)
else
    print("❌ Command routing failed to deliver all messages correctly")
    os.exit(1)
end
