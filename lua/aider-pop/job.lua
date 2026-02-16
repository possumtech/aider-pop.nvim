local M = {}

M.job_id = nil
M.buffer = nil
M.is_blocked = false
M.is_idle = false
M.is_busy = false
M.last_read_line = 0
M.last_command_line = 0
M.last_sync_line = 0
M.last_seen_line = 0
M.command_queue = {}
M.config = {}
M.repo_files = {} -- Whitelist of files in the project
M.chat_files = {} -- Files currently in the chat (Editable or Readonly)

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

M.is_syncing = false
M.last_sync_content = ""
M.has_resumed = false

function M.resolve_path(p)
	if not p or p == "" then return nil end
	-- Strip leading @ if present
	local clean = p:gsub("^@", "")
	-- Try direct resolution first (handles relative paths from Aider)
	local r = vim.loop.fs_realpath(clean)
	if r then return r end
	-- If that fails, Aider might be giving paths relative to repo root but we are in a subdir
	-- However, usually Aider runs in repo root. 
	return nil
end

function M.capture_sync(force)
	if M.is_syncing then return end
	if not M.buffer or not vim.api.nvim_buf_is_valid(M.buffer) then return end
	
	-- Only sync if we are idle (saw a prompt recently) OR forced
	if not M.is_idle and not force then return end

	local lines = vim.api.nvim_buf_get_lines(M.buffer, 0, -1, false)
	if #lines == 0 then return end
	
	local current_content = table.concat(lines, "\n")
	if current_content == M.last_sync_content then return end
	M.last_sync_content = current_content

	M.is_syncing = true

	local in_file_list = false
	local in_repo_list = false
	local empty_list_detected = false
	local current_chat_files = {}
	local current_repo_files = {}
	local editable_candidates = {}
	local readonly_candidates = {}
	local found_sync_data = false

	for _, line in ipairs(lines) do
		local l = M.strip_ansi(line):gsub("^%s*", ""):gsub("%s*$", "")
		local clean_l = l:gsub("^[^>]*>%s*", ""):gsub(">%s*$", ""):gsub("^%s*", ""):gsub("%s*$", "")
		
		if clean_l:match("^Read%-only files:") or clean_l:match("^Files in chat:") then
			current_chat_files = {} 
			in_file_list, in_repo_list = true, false
			found_sync_data = true
		elseif clean_l:match("^Repo files not in the chat:") then
			current_repo_files = {} 
			in_file_list, in_repo_list = false, true
			found_sync_data = true
		elseif clean_l:match("^No files in chat") then
			in_file_list, in_repo_list = false, false
			current_chat_files = {}
			empty_list_detected = true
			found_sync_data = true
		else
			local readonly_match = clean_l:match("Readonly:%s*(.*)")
			local editable_match = clean_l:match("Editable:%s*(.*)")
			
			if readonly_match or editable_match then
				found_sync_data = true
				if readonly_match then 
					current_chat_files = {} 
					for f in readonly_match:gmatch("%S+") do 
						local r = M.resolve_path(f)
						if r then 
							current_chat_files[r] = true 
							table.insert(readonly_candidates, r)
						end
					end 
				end
				if editable_match then 
					if not readonly_match then current_chat_files = {} end
					for f in editable_match:gmatch("%S+") do 
						local r = M.resolve_path(f)
						if r then 
							current_chat_files[r] = true 
							table.insert(editable_candidates, r)
						end
					end 
				end
			elseif in_file_list or in_repo_list then
				local file = clean_l:gsub("^%s*", "")
				if file ~= "" and not file:match("^architect>") and not file:match("^/") then
					local r = M.resolve_path(file)
					if r then
						if in_file_list then 
							current_chat_files[r] = true 
							-- We don't know if list-style is editable or readonly easily here
							-- but usually it's editable in recent Aider versions
							table.insert(editable_candidates, r)
						else 
							current_repo_files[r] = true 
						end
					end
				elseif file:match("^architect>") then
					in_file_list, in_repo_list = false, false
				end
			end
		end
	end

	-- Session Resumption Logic
	if M.config.resume_session and not M.has_resumed then
		local candidate = editable_candidates[1] or readonly_candidates[1]
		if candidate then
			vim.schedule(function()
				local cur_buf = vim.api.nvim_get_current_buf()
				local name = vim.api.nvim_buf_get_name(cur_buf)
				local modified = vim.api.nvim_buf_get_option(cur_buf, "modified")
				local argc = vim.fn.argc()
				
				if name == "" and not modified and argc == 0 then
					vim.cmd("edit " .. vim.fn.fnameescape(candidate))
				end
			end)
			M.has_resumed = true
		end
	end

	-- Update global state
	M.chat_files = current_chat_files
	-- repo_files should be a superset of everything we've seen in the project
	for k, v in pairs(current_repo_files) do M.repo_files[k] = v end
	for k, v in pairs(current_chat_files) do M.repo_files[k] = v end

	if M.config.sync and M.config.sync.active_buffers then
		if found_sync_data or empty_list_detected or next(current_chat_files) ~= nil then
			vim.schedule(function()
				for real_path, _ in pairs(current_chat_files) do
					local is_open = false
					for _, b in ipairs(vim.api.nvim_list_bufs()) do
						if vim.api.nvim_buf_is_valid(b) then
							local b_name = vim.api.nvim_buf_get_name(b)
							if b_name ~= "" then
								local b_real = vim.loop.fs_realpath(b_name)
								if b_real == real_path then
									is_open = true break
								end
							end
						end
					end
					if not is_open then 
						local bufnr = vim.fn.bufadd(real_path)
						vim.fn.bufload(bufnr)
						vim.fn.setbufvar(bufnr, "&buflisted", 1)
					end
				end

				for _, b in ipairs(vim.api.nvim_list_bufs()) do
					if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_option(b, "buflisted") then
						local bt = vim.api.nvim_buf_get_option(b, "buftype")
						local name = vim.api.nvim_buf_get_name(b)
						if bt == "" and name ~= "" and not name:match("^aider%-pop://") then
							local b_real = vim.loop.fs_realpath(name)
							if b_real and not current_chat_files[b_real] then
								vim.api.nvim_buf_delete(b, { force = true })
							end
						end
					end
				end
				M.is_syncing = false
			end)
		else
			M.is_syncing = false
		end
	else
		M.is_syncing = false
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
				M.is_busy = false
			end
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
	M.last_sync_line = 0
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
			env = { TERM = config.ui.terminal_name },
			on_stdout = function()
				if M.is_idle then M.capture_sync() end
			end,
			on_exit = function() M.job_id, M.is_idle = nil, false end,
		})
	end)
	M.capture_sync(true)
	if M.config.hooks and M.config.hooks.on_start then
		os.execute(M.config.hooks.on_start)
	end
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
	if M.config.hooks and M.config.hooks.on_stop then
		os.execute(M.config.hooks.on_stop)
	end
	vim.api.nvim_exec_autocmds("User", { pattern = "AiderStop", modeline = false })
end

return M
