local M = {}
local parser = require('aider-pop.parser')
local reconciler = require('aider-pop.reconciler')

M.job_id = nil
M.buffer = nil
M.is_blocked = false
M.is_idle = false
M.is_busy = false
M.is_syncing = false
M.last_command_line = 0
M.last_seen_line = 0
M.last_read_line = 0
M.last_sync_content = ""
M.has_resumed = false
M.command_queue = {}
M.config = {}
M.repo_files = {} 
M.chat_files = {}
M.pending_adds = {}

function M.get_last_content_line()
	if not M.buffer or not vim.api.nvim_buf_is_valid(M.buffer) then return 0 end
	local lines = vim.api.nvim_buf_get_lines(M.buffer, 0, -1, false)
	for i = #lines, 1, -1 do
		if parser.strip_ansi(lines[i]):gsub("%s+$", "") ~= "" then return i end
	end
	return 0
end

function M.capture_sync(force)
	if M.is_syncing then return end
	if not M.buffer or not vim.api.nvim_buf_is_valid(M.buffer) then return end
	if not M.is_idle and not force then return end

	local lines = vim.api.nvim_buf_get_lines(M.buffer, 0, -1, false)
	if #lines == 0 then return end
	
	local current_content = table.concat(lines, "\n")
	if current_content == M.last_sync_content then return end
	M.last_sync_content = current_content

	M.is_syncing = true
	local new_state = parser.parse_output(lines)
	reconciler.reconcile(M, new_state)
	-- reconciler handles resetting M.is_syncing via schedules
end

function M.check_state(on_state_change)
	if not M.buffer or not vim.api.nvim_buf_is_valid(M.buffer) then return end
	local lines = vim.api.nvim_buf_get_lines(M.buffer, 0, -1, false)
	local last = ""
	local last_idx = 0
	for i = #lines, 1, -1 do
		local clean = parser.strip_ansi(lines[i]):gsub("%s+$", "")
		if clean ~= "" then 
			last, last_idx = clean, i
			break 
		end
	end

	local was_busy, was_idle, was_blocked = M.is_busy, M.is_idle, M.is_blocked
	if last:match(">%s*$") then
		local is_genuine_prompt = not M.is_busy or last_idx > M.last_command_line
		if is_genuine_prompt then
			M.is_busy = false
			M.capture_sync()
			M.is_idle, M.is_blocked = true, false
			if #M.command_queue > 0 then M.send_raw(table.remove(M.command_queue, 1)) end
		end
	elseif last:match("%[.*%]:%s*$") or last:match("%(.-%):%s*$") or last:match("%(Y%)es/%(N%)o") then
		M.is_blocked, M.is_idle, M.is_busy = true, false, false
	else
		M.is_idle = false
	end

	if (was_busy ~= M.is_busy or was_idle ~= M.is_idle or was_blocked ~= M.is_blocked) and on_state_change then
		on_state_change()
	end
end

function M.start(config, on_state_change)
	if M.job_id then return end
	M.config = config
	M.repo_files = {}
	if vim.fn.executable(config.binary) ~= 1 then
		vim.notify("aider binary not found: " .. config.binary, vim.log.levels.ERROR)
		return
	end
	if M.buffer and vim.api.nvim_buf_is_valid(M.buffer) then
		vim.api.nvim_buf_delete(M.buffer, { force = true })
	end
	M.buffer = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(M.buffer, "aider-pop://" .. config.binary)
	vim.api.nvim_buf_call(M.buffer, function()
		M.job_id = vim.fn.termopen({ config.binary, unpack(config.args) }, {
			env = { TERM = config.terminal_name },
			on_stdout = function() if M.is_idle then M.capture_sync() end end,
			on_exit = function() M.job_id, M.is_idle = nil, false end,
		})
	end)
	M.capture_sync(true)
	if M.config.on_start then os.execute(M.config.on_start) end
	vim.api.nvim_exec_autocmds("User", { pattern = "AiderStart", modeline = false })
	M.timer = vim.fn.timer_start(200, function() pcall(M.check_state, on_state_change) end, { ["repeat"] = -1 })
end

function M.send_raw(p)
	M.is_idle, M.is_busy = false, true
	M.last_command_line = M.get_last_content_line()
	vim.fn.chansend(M.job_id, p .. "\n")
	vim.cmd("redrawstatus")
end

function M.stop()
	if M.job_id then vim.fn.jobstop(M.job_id) end
	if M.timer then vim.fn.timer_stop(M.timer) end
	M.is_idle = false
	if M.config.on_stop then os.execute(M.config.on_stop) end
	vim.api.nvim_exec_autocmds("User", { pattern = "AiderStop", modeline = false })
end

return M
