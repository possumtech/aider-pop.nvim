local M = {}

M.job_id = nil
M.buffer = nil
M.is_blocked = false
M.is_idle = false
M.is_busy = false
M.last_read_line = 0
M.last_command_line = 0
M.last_sync_line = 0
M.last_answer = ""
M.command_queue = {}
M.config = {}

function M.strip_ansi(text)
	if not text then return "" end
	return text
		:gsub("\27%[[0-9;]*m", "")
		:gsub("\27%[[0-9;]*[A-K]", "")
		:gsub("\27%[[0-9;]*[mG]", "")
		:gsub("\r", "")
end

function M.get_last_content_line()
	if not M.buffer or not vim.api.nvim_buf_is_valid(M.buffer) then return 0 end
	local lines = vim.api.nvim_buf_get_lines(M.buffer, 0, -1, false)
	for i = #lines, 1, -1 do
		if M.strip_ansi(lines[i]):gsub("%s+$", "") ~= "" then return i end
	end
	return 0
end

function M.capture_answer()
	if not M.buffer or not vim.api.nvim_buf_is_valid(M.buffer) then return end
	local lines = vim.api.nvim_buf_get_lines(M.buffer, M.last_command_line, -1, false)

	local last_idx = 0
	for i = #lines, 1, -1 do
		if M.strip_ansi(lines[i]):gsub("%s+$", "") ~= "" then
			last_idx = i
			break
		end
	end

	if last_idx <= 1 then return end

	local empty_idx = 0
	for i = last_idx - 1, 1, -1 do
		if M.strip_ansi(lines[i]):gsub("%s+$", "") == "" then
			empty_idx = i
			break
		end
	end

	if empty_idx > 1 then
		local line = M.strip_ansi(lines[empty_idx - 1]):gsub("^%s*", ""):gsub("%s*$", "")
		if line ~= "" then
			M.last_answer = line
		end
	end
end

function M.capture_sync()
	if not M.buffer or not vim.api.nvim_buf_is_valid(M.buffer) then return end
	if not M.config or not M.config.sync or not M.config.sync.active_buffers then return end
	
	-- We look at the last 10 lines of the buffer to find the state summary
	local line_count = vim.api.nvim_buf_line_count(M.buffer)
	local start_line = math.max(0, line_count - 10)
	local lines = vim.api.nvim_buf_get_lines(M.buffer, start_line, -1, false)
	
	local current_files = {}
	local found_state = false

	for _, line in ipairs(lines) do
		local l = M.strip_ansi(line):gsub("^%s*", ""):gsub("%s*$", "")
		
		-- Aider prints state like:
		-- Readonly: file1.py file2.py
		-- Editable: main.py
		local readonly = l:match("^Readonly:%s+(.+)")
		local editable = l:match("^Editable:%s+(.+)")
		
		if readonly or editable then
			found_state = true
			local files = readonly or editable
			for f_path in files:gmatch("%S+") do
				-- Clean aider path junk
				local clean_f = f_path:gsub("^%.%.%/[%.%.%/]*", ""):gsub("^%/", "")
				local real = vim.loop.fs_realpath(clean_f)
				if real then
					current_files[real] = true
				end
			end
		end
	end

	-- Only reconcile if we actually found a state summary line
	if found_state then
		vim.schedule(function()
			-- 1. Ensure all files in Aider are open in Neovim
			for real_path, _ in pairs(current_files) do
				local is_open = false
				for _, b in ipairs(vim.api.nvim_list_bufs()) do
					if vim.api.nvim_buf_is_valid(b) then
						local b_name = vim.api.nvim_buf_get_name(b)
						if b_name ~= "" and vim.loop.fs_realpath(b_name) == real_path then
							is_open = true break
						end
					end
				end
				if not is_open then 
					vim.cmd("edit " .. vim.fn.fnameescape(real_path))
				end
			end

			-- 2. Drop any listed buffers that are NOT in Aider's list
			for _, b in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_option(b, "buflisted") then
					local bt = vim.api.nvim_buf_get_option(b, "buftype")
					local name = vim.api.nvim_buf_get_name(b)
					if bt == "" and name ~= "" and not name:match("^aider%-pop://") then
						local b_real = vim.loop.fs_realpath(name)
						if b_real and not current_files[b_real] then
							vim.api.nvim_buf_delete(b, { force = true })
						end
					end
				end
			end
		end)
	end
end

function M.check_state(on_state_change)
	if not M.buffer or not vim.api.nvim_buf_is_valid(M.buffer) then return end
	
	local lines = vim.api.nvim_buf_get_lines(M.buffer, 0, -1, false)
	local last = ""
	local last_idx = 0
	for i = #lines, 1, -1 do
		local clean = M.strip_ansi(lines[i]):gsub("%s+$", "")
		if clean ~= "" then 
			last = clean 
			last_idx = i
			break 
		end
	end

	local was_busy = M.is_busy
	local was_idle = M.is_idle
	local was_blocked = M.is_blocked

	if last:match(">%s*$") then
		local is_genuine_prompt = not M.is_busy or last_idx > M.last_command_line
		if is_genuine_prompt then
			if M.is_busy then
				M.capture_answer()
				M.is_busy = false
			end
			-- Always try to sync when we hit a prompt
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
			env = { TERM = config.ui.terminal_name },
			on_exit = function() M.job_id, M.is_idle = nil, false end,
		})
	end)
	M.timer = vim.fn.timer_start(200, function() pcall(M.check_state, on_state_change) end, { ["repeat"] = -1 })
end

function M.send_raw(p)
	M.is_idle, M.is_busy = false, true
	M.last_answer = ""
	M.last_command_line = M.get_last_content_line()
	vim.fn.chansend(M.job_id, p .. "\n")
	vim.cmd("redrawstatus")
end

function M.stop()
	if M.job_id then vim.fn.jobstop(M.job_id) end
	if M.timer then vim.fn.timer_stop(M.timer) end
end

return M
