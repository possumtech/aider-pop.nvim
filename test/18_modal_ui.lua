local M = require('aider-pop')
local mock_bin = './aider_mock_18.sh'
local log_file = './aider_18.log'

-- Global timeout
vim.defer_fn(function() 
    print("❌ Test timed out after 15s")
    os.exit(1) 
end, 15000)

-- Create mock binary that prompts and then accepts commands
local f = io.open(mock_bin, "w")
f:write("#!/bin/bash\n")
f:write("printf \"Add .aider* to .gitignore? (Y)es/(N)o [Yes]: \"\n")
f:write("read answer\n")
f:write("echo \"Answer received: $answer\" > " .. log_file .. "\n")
f:write("printf \"architect> \"\n")
f:write("while read line; do echo \"Input: $line\" >> " .. log_file .. "; printf \"architect> \"; done\n")
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ binary = mock_bin })

-- 1. Verify toggle functionality
vim.cmd("AiderPopToggle")
if not (M.window and vim.api.nvim_win_is_valid(M.window)) then
    print("❌ Modal failed to open")
    os.exit(1)
end

-- 2. Verify ANSI-clean prompt appears in buffer
local ok = vim.wait(5000, function()
    local lines = vim.api.nvim_buf_get_lines(M.buffer, 0, -1, false)
    local content = table.concat(lines, " ")
    return content:match("gitignore")
end)

if not ok then
    print("❌ Prompt not found in buffer")
    os.exit(1)
end

-- 3. Verify interaction (answering a prompt)
vim.api.nvim_chan_send(M.job_id, "y\n")
ok = vim.wait(5000, function()
    local lf = io.open(log_file, "r")
    if not lf then return false end
    local content = lf:read("*a")
    lf:close()
    return content:match("Answer received: y")
end)

if not ok then
    print("❌ Failed to send answer to prompt")
    os.exit(1)
end

-- 4. Verify mode prefix routing after a prompt
M.send("? testing prefixes")
ok = vim.wait(5000, function()
    local lf = io.open(log_file, "r")
    if not lf then return false end
    local content = lf:read("*a")
    lf:close()
    return content:match("Input: /ask testing prefixes")
end)

if not ok then
    print("❌ Prefixed command failed or tangled after prompt")
    os.exit(1)
end

vim.cmd("AiderPopToggle")
M.stop()
os.remove(mock_bin)
if io.open(log_file, "r") then os.remove(log_file) end

print("✅ Milestone 18 passed")
os.exit(0)
