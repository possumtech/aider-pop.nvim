local M = {}

M.config = {
	binary = "aider",
	args = { "--no-gitignore", "--yes-always", "--no-pretty" },
	ui = { width = 0.8, height = 0.8, border = "rounded", terminal_name = "xterm-256color" },
}

M.job_id, M.buffer, M.window, M.is_blocked, M.is_idle, M.last_read_line = nil, nil, nil, false, false, 0
M.command_queue = {}
M.last_answer = ""
M.expect_popup = false
M.last_prompt_line = 0

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
	local lines = vim.api.nvim_buf_get_lines(M.buffer, M.last_prompt_line, -1, false)
	local text = table.concat(lines, " ")
	text = M.strip_ansi(text)
	-- Remove the prompt itself and any trailing garbage/tokens info
	text = text:gsub("[%w%-]*>%s*$", ""):gsub("Tokens:.*$", ""):gsub("^%s*", "")
	if text ~= "" then
		M.last_answer = text
	end
end

function M.check_state()
	if not M.buffer or not vim.api.nvim_buf_is_valid(M.buffer) then return end
	local lines = vim.api.nvim_buf_get_lines(M.buffer, 0, -1, false)
	local last = ""
	local last_idx = 0
	for i = #lines, 1, -1 do
		local clean = M.strip_ansi(lines[i]):gsub("%s+$", "")
		if clean ~= "" then
			last, last_idx = clean, i
			break
		end
	end

	if last:match(">%s*$") then
		if not M.is_idle then
			M.capture_answer()
			M.last_prompt_line = last_idx
			if M.expect_popup then
				M.expect_popup = false
				if not (M.window and vim.api.nvim_win_is_valid(M.window)) then M.toggle_modal() end
			end
		end
		M.is_idle, M.is_blocked = true, false
		if #M.command_queue > 0 then M.send_raw(table.remove(M.command_queue, 1)) end
	elseif last:match("%[.*%]:%s*$") or last:match("%(.-%):%s*$") or last:match("%(Y%)es/%(N%)o") then
		M.is_blocked, M.is_idle = true, false
		if not (M.window and vim.api.nvim_win_is_valid(M.window)) then M.toggle_modal() end
		vim.cmd("startinsert")
	else
		M.is_idle = false
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
		local text = c.args
		if c.range > 0 then
			local selection = table.concat(vim.api.nvim_buf_get_lines(0, c.line1 - 1, c.line2, false), "\n")
			text = text .. "\n\nContext:\n```\n" .. selection .. "\n```"
		end
		M.send(text)
	end, { nargs = "*", range = true })
	vim.api.nvim_create_user_command("AiderPopToggle", function() M.toggle_modal() end, {})
	vim.cmd([[
		cnoreabbrev <expr> AI: (getcmdtype() == ':' && getcmdline() ==# 'AI:') ? 'AI :' : 'AI:'
		cnoreabbrev <expr> AI? (getcmdtype() == ':' && getcmdline() ==# 'AI?') ? 'AI ?' : 'AI?'
		cnoreabbrev <expr> AI! (getcmdtype() == ':' && getcmdline() ==# 'AI!') ? 'AI !' : 'AI!'
		cnoreabbrev <expr> AI/ (getcmdtype() == ':' && getcmdline() ==# 'AI/') ? 'AI /' : 'AI/'
	]])
end

function M.start()
	if M.job_id then return end
	if vim.fn.executable(M.config.binary) ~= 1 then return end
	M.buffer = M.buffer or vim.api.nvim_create_buf(false, true)
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
	M.is_idle = false
	vim.fn.chansend(M.job_id, p .. "\n")
end

function M.send(text)
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
		M.last_read_line = vim.api.nvim_buf_line_count(M.buffer)
		vim.api.nvim_win_close(M.window, true)
		M.window = nil
	elseif M.buffer and vim.api.nvim_buf_is_valid(M.buffer) then
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
		vim.api.nvim_win_set_cursor(M.window, { vim.api.nvim_buf_line_count(M.buffer), 0 })
	end
end

function M.status()
	if not M.job_id then return "💤" end
	if M.is_blocked then return "✋" end
	if not M.is_idle then return "⏳ Running..." end
	if M.last_answer ~= "" then
		local clean = M.last_answer:gsub("%s+", " "):sub(1, 50)
		return "🤖 " .. clean .. (#M.last_answer > 50 and "..." or "")
	end
	return ""
end

function M.stop() if M.job_id then vim.fn.jobstop(M.job_id) end end

return M
