local M = require('aider-pop')
local mock_bin = './aider_mock_07.sh'
local log_file = './aider_args_07.log'

-- Create mock binary
local f = io.open(mock_bin, "w")
f:write("#!/bin/bash\n")
f:write("echo \"$@\" > " .. log_file .. "\n")
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ 
    binary = mock_bin, 
    args = { '--dark-mode', '--no-git' } 
})

-- Wait for the log file to be written
local ok = vim.wait(2000, function() 
    return vim.fn.filereadable(log_file) == 1 
end)

if ok then
    local lf = io.open(log_file, "r")
    local content = lf:read("*a")
    lf:close()
    print("DEBUG: Content is '" .. content .. "'")
    -- Providing args should replace the default --no-auto-commits
    if content:find("--dark-mode", 1, true) and content:find("--no-git", 1, true) and not content:find("--no-auto-commits", 1, true) then
        ok = true
    else
        print("❌ Arguments not correctly passed: " .. content)
        ok = false
    end
end

M.stop()
os.remove(mock_bin)
os.remove(log_file)

if ok then
    os.exit(0)
else
    os.exit(1)
end
