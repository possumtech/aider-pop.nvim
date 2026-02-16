local M = require('aider-pop')
local job = require('aider-pop.job')
local mock_bin = './aider_mock_14.sh'

-- Create dummy file first
local test_file = "file.lua"
local tf = io.open(test_file, "w")
tf:write("-- test")
tf:close()

-- Create mock binary
local f = io.open(mock_bin, "w")
f:write([=[#!/bin/bash
# Startup info
echo "Repo files not in the chat:"
echo "  file.lua"
echo ""
printf "architect> "

while read -r line; do
  if [[ "$line" == *"/add file.lua"* ]]; then
    IN_CHAT=true
    echo "Readonly: "
    echo "Editable: file.lua"
    printf "architect> "
  elif [[ "$line" == *"/ls"* ]]; then
    if [ "$IN_CHAT" = true ]; then
      echo "Editable: file.lua"
    else
      echo "Repo files not in the chat:"
      echo "  file.lua"
    fi
    printf "architect> "
  else
    printf "architect> "
  fi
done
]=])
f:close()
os.execute("chmod +x " .. mock_bin)

M.setup({ 
    binary = mock_bin,
    sync = { active_buffers = true }
})

-- Wait for initial whitelist
vim.wait(10000, function() 
    return M.is_idle and next(job.repo_files) ~= nil 
end)

-- Trigger the /add
M.send("/add file.lua")

print("DEBUG: Whitelist size: " .. vim.tbl_count(job.repo_files))
local abs_target = vim.loop.fs_realpath("file.lua")
print("DEBUG: Absolute target path: " .. tostring(abs_target))

-- 4. Verify result
local ok = vim.wait(15000, function()
    return vim.fn.bufexists(abs_target) == 1
end, 200)

if not ok then
    print("Listing ALL buffers:")
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        print(string.format("  %d: '%s' listed=%s", b, vim.api.nvim_buf_get_name(b), tostring(vim.api.nvim_buf_get_option(b, "buflisted"))))
    end
end

M.stop()
os.remove(mock_bin)
os.remove(test_file)

if ok then
    print("✅ Milestone 14 passed")
    os.exit(0)
else
    print("❌ Failed: Neovim did not open file.lua after aider /add")
    print("Terminal Buffer Content:")
    local lines = vim.api.nvim_buf_get_lines(job.buffer, 0, -1, false)
    for i, line in ipairs(lines) do print(string.format("[%02d] %s", i, line)) end
    os.exit(1)
end
