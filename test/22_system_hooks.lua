local M = require('aider-pop')
local job = require('aider-pop.job')

local start_hook_file = "start_hook.txt"
local stop_hook_file = "stop_hook.txt"

-- Cleanup
os.remove(start_hook_file)
os.remove(stop_hook_file)

M.setup({
    on_start = "touch " .. start_hook_file,
    on_stop = "touch " .. stop_hook_file,
})

-- 1. Verify Start Hook
M.start()
vim.wait(2000, function() return vim.fn.filereadable(start_hook_file) == 1 end)

if vim.fn.filereadable(start_hook_file) ~= 1 then
    print("❌ Failed: on_start hook command did not execute")
    os.exit(1)
end

-- 2. Verify Stop Hook
M.stop()
vim.wait(2000, function() return vim.fn.filereadable(stop_hook_file) == 1 end)

if vim.fn.filereadable(stop_hook_file) ~= 1 then
    print("❌ Failed: on_stop hook command did not execute")
    os.exit(1)
end

os.remove(start_hook_file)
os.remove(stop_hook_file)
print("✅ Milestone 22 passed (System Hooks)")
os.exit(0)
