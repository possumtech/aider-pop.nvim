local M = require('aider-pop')
local job = require('aider-pop.job')

M.setup({
    sync_buffers = true,
    statusline = true
})

-- Reset log
local f = io.open("debug_state.log", "w")
f:write("Starting debug session...\n")
f:close()

-- Monitor state in background using a timer instead of a loop inside defer_fn
vim.fn.timer_start(2000, function()
    local bufs = vim.api.nvim_list_bufs()
    local listed = {}
    for _, b in ipairs(bufs) do
        if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_option(b, "buflisted") then
            table.insert(listed, string.format("%d: %s", b, vim.api.nvim_buf_get_name(b)))
        end
    end
    
    local log = io.open("debug_state.log", "a")
    if log then
        log:write(string.format("--- %s ---\n", os.date("%H:%M:%S")))
        log:write("Buffers:\n" .. table.concat(listed, "\n") .. "\n")
        log:write("Aider IDLE: " .. tostring(job.is_idle) .. "\n")
        log:write("Aider BUSY: " .. tostring(job.is_busy) .. "\n")
        log:close()
    end
end, {["repeat"] = -1})

-- Sequence of events
vim.defer_fn(function()
    print("Action: Sending /add README.md")
    M.send("/add README.md")
end, 5000)

vim.defer_fn(function()
    print("Action: Sending /drop README.md")
    M.send("/drop README.md")
end, 15000)

vim.defer_fn(function()
    print("Debug session finished.")
    vim.cmd("qall!")
end, 25000)
