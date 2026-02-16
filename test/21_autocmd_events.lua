local M = require('aider-pop')
local job = require('aider-pop.job')

local start_fired = false
local stop_fired = false

vim.api.nvim_create_autocmd("User", {
    pattern = "AiderStart",
    callback = function()
        start_fired = true
    end
})

vim.api.nvim_create_autocmd("User", {
    pattern = "AiderStop",
    callback = function()
        stop_fired = true
    end
})

-- 1. Test Start
-- Ensure we are in a git root for the start to actually happen
-- (The test is run from project root, so .git exists)
M.start()

local ok_start = vim.wait(5000, function() return start_fired end)
if not ok_start then
    print("❌ Failed: AiderStart event did not fire")
    os.exit(1)
end

-- 2. Test Stop
M.stop()
local ok_stop = vim.wait(5000, function() return stop_fired end)
if not ok_stop then
    print("❌ Failed: AiderStop event did not fire")
    os.exit(1)
end

print("✅ Milestone 21 passed (User Autocommands)")
os.exit(0)
