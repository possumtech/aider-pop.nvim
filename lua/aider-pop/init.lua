local M = {}

M.config = {
	binary = "aider",
	args = { "--no-gitignore", "--yes-always", "--no-pretty" },
	ui = { 
		width = 0.8, height = 0.8, border = "rounded", terminal_name = "xterm-256color",
		statusline = false 
	},
}

M.job_id, M.buffer, M.window, M.is_blocked, M.is_idle, M.last_read_line = nil, nil, nil, false, false, 0
M.command_queue = {}
M.last_answer = ""
M.expect_popup = false
M.last_command_line = 0
M.is_busy = false

function M.strip_ansi(text)
	if not text then return "" end
	return text
		:gsub("\27%[[0-9;]*m", "")
		:gsub("\27%[[0-9;]*[A-K]", "")
		:gsub("\27%[[0-9;]*[mG]", "")
		:gsub("\r", "")
end

function M.capture_answer()
	if not M.buffer or not vim.api.nvim_buf_is_valid(M.buffer) then return end
	local lines = vim.api.nvim_buf_get_lines(M.buffer, M.last_command_line, -1, false)

	-- 1. Identify the last line of output (ignoring trailing whitespace)
	local last_idx = 0
	for i = #lines, 1, -1 do
		if M.strip_ansi(lines[i]):gsub("%s+$", "") ~= "" then
			last_idx = i
			break
		end
	end

	if last_idx <= 1 then return end

	-- 2. Walk backwards until there's a (truly) empty line
	local empty_idx = 0
	for i = last_idx - 1, 1, -1 do
		if M.strip_ansi(lines[i]):gsub("%s+$", "") == "" then
			empty_idx = i
			break
		end
	end

	-- 3. Walk backwards one more line
	if empty_idx > 1 then
		-- 4. That is the answer
		local line = M.strip_ansi(lines[empty_idx - 1]):gsub("^%s*", ""):gsub("%s*$", "")
		if line ~= "" then
			M.last_answer = line
		end
	end
end

function M.get_last_content_line()
	if not M.buffer or not vim.api.nvim_buf_is_valid(M.buffer) then return 0 end
	local lines = vim.api.nvim_buf_get_lines(M.buffer, 0, -1, false)
	for i = #lines, 1, -1 do
		if M.strip_ansi(lines[i]):gsub("%s+$", "") ~= "" then return i end
	end
	return 0
end

function M.check_state()
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

	if last:match(">%s*$") then
		local is_genuine_prompt = not M.is_busy or last_idx > M.last_command_line
		if is_genuine_prompt then
			if M.is_busy then
				M.capture_answer()
				M.is_busy = false
				if M.expect_popup then
					M.expect_popup = false
					if not (M.window and vim.api.nvim_win_is_valid(M.window)) then M.toggle_modal() end
				end
			end
			M.is_idle, M.is_blocked = true, false
			if #M.command_queue > 0 then M.send_raw(table.remove(M.command_queue, 1)) end
		end
	elseif last:match("%[.*%]:%s*$") or last:match("%(.-%):%s*$") or last:match("%(Y%)es/%(N%)o") then
		M.is_blocked, M.is_idle, M.is_busy = true, false, false
		if not (M.window and vim.api.nvim_win_is_valid(M.window)) then M.toggle_modal() end
		vim.cmd("startinsert")
	else
		M.is_idle = false
	end

	if was_busy ~= M.is_busy or was_idle ~= M.is_idle then
		vim.cmd("redrawstatus")
	end
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	M.start()
	vim.cmd([[
		highlight default AiderNormal guibg=#000080 guifg=#ffffff
		highlight default AiderTerminal guibg=NONE guifg=NONE
	]])
	vim.api.nvim_create_user_command("AI", function(c)
		local args = c.args
		local char = args:sub(1, 1)
		local has_prefix = (char == "?" or char == "!" or char == ":" or char == "/")
		local query = has_prefix and args:sub(2):gsub("^%s+", "") or args
		
		if c.range > 0 then
			local lines = vim.api.nvim_buf_get_lines(0, c.line1 - 1, c.line2, false)
			local selection = table.concat(lines, "\n")
			local ft = vim.bo.filetype
			
			if query == "" then
				if char == "?" then query = "Please explain this selection:"
				elseif char == ":" then query = "Please review this selection:"
				else query = "Selection:" end
			end
			
			query = query .. "\n\n```" .. ft .. "\n" .. selection .. "\n```"
		end
		
		local final_text = has_prefix and (char .. " " .. query) or query
		M.send(final_text)
	end, { nargs = "*", range = true })
	vim.api.nvim_create_user_command("AiderPopToggle", function() M.toggle_modal() end, {})
	vim.api.nvim_create_user_command("AiderPopStatus", function() print("Aider Status: '" .. M.status() .. "'") end, {})
	vim.cmd([[
		cnoreabbrev <expr> AI: (getcmdtype() == ':' && getcmdline() ==# 'AI:') ? 'AI :' : 'AI:'
		cnoreabbrev <expr> AI? (getcmdtype() == ':' && getcmdline() ==# 'AI?') ? 'AI ?' : 'AI?'
		cnoreabbrev <expr> AI! (getcmdtype() == ':' && getcmdline() ==# 'AI!') ? 'AI !' : 'AI!'
		cnoreabbrev <expr> AI/ (getcmdtype() == ':' && getcmdline() ==# 'AI/') ? 'AI /' : 'AI/'
	]])

	if M.config.ui.statusline then
		vim.o.statusline = vim.o.statusline .. " %{v:lua.require('aider-pop').status()}"
	end
end

function M.start()
	if M.job_id then return end
	if vim.fn.executable(M.config.binary) ~= 1 then
		vim.notify("aider binary not found: " .. M.config.binary, vim.log.levels.ERROR)
		return
	end
	if M.buffer and vim.api.nvim_buf_is_valid(M.buffer) then
		vim.api.nvim_buf_delete(M.buffer, { force = true })
	end
	M.buffer = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(M.buffer, "aider-pop-terminal")
	vim.api.nvim_buf_call(M.buffer, function()
		M.job_id = vim.fn.termopen({ M.config.binary, unpack(M.config.args) }, {
			env = { TERM = M.config.ui.terminal_name },
			on_exit = function() M.job_id, M.is_idle = nil, false end,
		})
	end)
	M.timer = vim.fn.timer_start(200, function() pcall(M.check_state) end, { ["repeat"] = -1 })
end

function M.send_raw(p)
	M.is_idle, M.is_busy = false, true
	M.last_answer = ""
	M.last_command_line = M.get_last_content_line()
	vim.fn.chansend(M.job_id, p .. "\n")
	vim.cmd("redrawstatus")
end

function M.send(text)
	M.start()
	if not M.is_running() then return end
	local map = { ["?"] = "/ask ", ["!"] = "/run ", [":"] = "/architect ", ["/"] = "/" }
	local char = text:sub(1, 1)
	local prefix = map[char] or ""
	local msg = prefix ~= "" and text:sub(2):gsub("^%s+", "") or text
	if char == "/" then prefix, msg = "", text:gsub("^/%s+", "/") end
	
	if char == "?" or prefix == "/ask " then M.expect_popup = true end

	local payload = prefix .. msg
	if msg:find("\n") then payload = "{\n" .. payload .. "\n}" end
	if M.is_idle and not M.is_blocked then M.send_raw(payload) else table.insert(M.command_queue, payload) end
end

function M.is_running() return M.job_id ~= nil and M.job_id > 0 end

function M.toggle_modal()
	if M.window and vim.api.nvim_win_is_valid(M.window) then
		M.last_read_line = M.get_last_content_line()
		vim.api.nvim_win_close(M.window, true)
		M.window = nil
		vim.cmd("redrawstatus")
	elseif M.buffer and vim.api.nvim_buf_is_valid(M.buffer) then
		if not M.is_running() then M.start() end
		local w, h = math.floor(vim.o.columns * M.config.ui.width), math.floor(vim.o.lines * M.config.ui.height)
		M.window = vim.api.nvim_open_win(M.buffer, true, {
			relative = "editor", width = w, height = h, row = math.floor((vim.o.lines - h) / 2),
			col = math.floor((vim.o.columns - w) / 2), border = M.config.ui.border, style = "minimal", title = " 🤖 AIDER ", title_pos = "center",
		})
		vim.api.nvim_win_set_option(M.window, "winhighlight", "Normal:AiderNormal")
		local g = vim.api.nvim_create_augroup("AiderPopHighlights", { clear = true })
		vim.api.nvim_create_autocmd("TermEnter", { group = g, buffer = M.buffer, callback = function() if M.window then vim.api.nvim_win_set_option(M.window, "winhighlight", "Normal:AiderTerminal") end end })
		vim.api.nvim_create_autocmd("TermLeave", { group = g, buffer = M.buffer, callback = function() if M.window then vim.api.nvim_win_set_option(M.window, "winhighlight", "Normal:AiderNormal") end end })
		vim.api.nvim_buf_set_keymap(M.buffer, "t", "<Esc>", [[<C-\><C-n>]], { noremap = true, silent = true })
		vim.api.nvim_buf_set_keymap(M.buffer, "n", "<Esc>", [[<cmd>AiderPopToggle<cr>]], { noremap = true, silent = true })
		vim.cmd("stopinsert")
		vim.api.nvim_win_set_cursor(M.window, { math.max(1, M.get_last_content_line()), 0 })
	end
end

function M.status()
	if not M.job_id then return "💤" end
	if M.is_blocked then return "✋" end
	if M.is_busy or not M.is_idle then return "⏳" end
	
	if M.last_answer ~= "" then
		local clean = M.last_answer:gsub("%s+", " "):gsub("^%s*", ""):sub(1, 50)
		return "🤖 " .. clean .. (#M.last_answer > 50 and "..." or "")
	end

	local content_line = M.get_last_content_line()
	return content_line > M.last_read_line and "🤖" or ""
end

function M.stop() if M.job_id then vim.fn.jobstop(M.job_id) end end

return M
