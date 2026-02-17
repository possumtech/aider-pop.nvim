local f = io.open("buffer_state.log", "w")
f:write("Monitoring Buffers...
")
f:close()

while true do
    local bufs = vim.api.nvim_list_bufs()
    local listed = {}
    for _, b in ipairs(bufs) do
        if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_option(b, "buflisted") then
            table.insert(listed, string.format("%d: %s", b, vim.api.nvim_buf_get_name(b)))
        end
    end
    
    local log = io.open("buffer_state.log", "a")
    if log then
        log:write("--- " .. os.date("%H:%M:%S") .. " ---
")
        log:write(table.concat(listed, "
") .. "
")
        log:close()
    end
    vim.wait(1000)
end
