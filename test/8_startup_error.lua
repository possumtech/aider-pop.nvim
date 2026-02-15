local M = require('aider-pop')

_G.notified = false
vim.notify = function(msg)
    if msg:find('aider binary not found') then
        _G.notified = true
    end
end

M.setup({ binary = 'non-existent-binary' })

if _G.notified then
    os.exit(0)
else
    print("❌ Notification for missing binary not triggered")
    os.exit(1)
end
