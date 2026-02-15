local M = require('aider-pop')
local mock_bin = './aider_mock_06.sh'

-- Create mock binary
local f = io.open(mock_bin, "w")
f:write("#!/bin/bash\n")
f:write("while true; do sleep 0.1; done\n")
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ binary = mock_bin })

-- Give it a moment to start
local ok = vim.wait(2000, function() return M.is_running() end)

if not ok then
    print("❌ Process failed to start")
    os.remove(mock_bin)
    os.exit(1)
end

-- Call stop
M.stop()

-- Check that it is no longer running
ok = vim.wait(2000, function()
    return not M.is_running()
end, 100)

os.remove(mock_bin)

if ok then
    os.exit(0)
else
    print("❌ M.stop() did not terminate the process correctly")
    os.exit(1)
end
