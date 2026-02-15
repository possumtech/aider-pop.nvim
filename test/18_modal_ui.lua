local M = require('aider-pop')
local mock_bin = './aider_mock_18.sh'

-- Create mock binary that outputs something immediately
local f = io.open(mock_bin, "w")
f:write("#!/bin/bash\necho \"Hello from Aider\"\nwhile true; do sleep 0.1; done\n")
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ binary = mock_bin })

-- Wait for it to start and capture output
local ok = vim.wait(2000, function() 
    return M.buffer and vim.api.nvim_buf_is_valid(M.buffer) and vim.api.nvim_buf_line_count(M.buffer) > 1 
end)

if not ok then
    print("❌ Timed out waiting for buffer initialization")
    M.stop()
    os.remove(mock_bin)
    os.exit(1)
end

-- Initially window should be nil
if M.window then
    print("❌ Window should be nil initially")
    M.stop()
    os.remove(mock_bin)
    os.exit(1)
end

-- Toggle ON
vim.cmd("AiderPopToggle")

if not (M.window and vim.api.nvim_win_is_valid(M.window)) then
    print("❌ Window should be valid after toggle ON")
    M.stop()
    os.remove(mock_bin)
    os.exit(1)
end

-- Check buffer in window
local win_buf = vim.api.nvim_win_get_buf(M.window)
if win_buf ~= M.buffer then
    print("❌ Window buffer mismatch")
    M.stop()
    os.remove(mock_bin)
    os.exit(1)
end

-- Toggle OFF
vim.cmd("AiderPopToggle")

if M.window and vim.api.nvim_win_is_valid(M.window) then
    print("❌ Window should be invalid after toggle OFF")
    M.stop()
    os.remove(mock_bin)
    os.exit(1)
end

M.stop()
os.remove(mock_bin)
os.exit(0)
