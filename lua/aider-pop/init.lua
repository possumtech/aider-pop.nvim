local M = {}

M.config = {
	binary = "aider",
	args = { "--no-gitignore", "--yes-always" },
	ui = {
		width = 0.8,
		height = 0.8,
		border = "rounded",
		terminal_name = "xterm-256color",
	},
}

M.job_id = nil
M.buffer = nil
M.window = nil
M.is_blocked = false
M.command_queue = {}
M.liveness_timer = nil
M.last_read_line = 0

-- Define highlights for different modes
vim.cmd([[
	highlight default link AiderNormal Normal
	highlight default AiderTerminal guibg=#ff0000 guifg=#ffffff
]])

function M.check_state()
	if not M.buffer or not vim.api.nvim_buf_is_valid(M.buffer) then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(M.buffer)
	local last_non_empty = ""
	for i = line_count - 1, 0, -1 do
		local line = vim.api.nvim_buf_get_lines(M.buffer, i, i + 1, false)[1] or ""
		if line:gsub("%s+", "") ~= "" then
			last_non_empty = line
			break
		end
	end

	-- The standard Aider prompt in TERM=dumb usually ends with '> '
	local is_idle = last_non_empty:match(">%s*$")

	if is_idle then
		M.is_blocked = false
		M.process_queue()
	else
		-- Only auto-insert on actual blocking prompts, not conversational questions
		local is_blocking = last_non_empty:match("%(y/n%)")
			or last_non_empty:match("%[y/n%]")
			or last_non_empty:match("%(Y%)es/%(N%)o")
			or last_non_empty:match("%[Yes%]:")

		if is_blocking then
			M.is_blocked = true
			vim.schedule(function()
				if not (M.window and vim.api.nvim_win_is_valid(M.window)) then
					M.toggle_modal()
				end
				vim.cmd("startinsert")
			end)
		end
	end
end

function M.process_queue()
	if #M.command_queue > 0 and not M.is_blocked then
		local text = table.remove(M.command_queue, 1)
		M.send_raw(text)
	end
end

function M.setup(opts)
	local args = (opts and opts.args) and opts.args or M.config.args
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	M.config.args = args
	M.start()

	vim.api.nvim_create_user_command("AI", function(cmd_opts)
		local text = cmd_opts.args
		if cmd_opts.range > 0 then
			-- Get visual selection
			local start_line = cmd_opts.line1
			local end_line = cmd_opts.line2
			local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
			local selection = table.concat(lines, "\n")
			-- Wrap selection in clear delimiters and put instructions first
			text = text .. "\n\nContext from selection:\n```\n" .. selection .. "\n```"
		end
		M.send(text)
	end, { nargs = "*", range = true })

	vim.api.nvim_create_user_command("AiderPopToggle", function()
		M.toggle_modal()
	end, {})

	-- Abbreviations to support documented syntax: :AI: <msg>, :AI? <msg>, etc.
	vim.cmd([[
		cnoreabbrev <expr> AI: (getcmdtype() == ':' && getcmdline() ==# 'AI:') ? 'AI :' : 'AI:'
		cnoreabbrev <expr> AI? (getcmdtype() == ':' && getcmdline() ==# 'AI?') ? 'AI ?' : 'AI?'
		cnoreabbrev <expr> AI! (getcmdtype() == ':' && getcmdline() ==# 'AI!') ? 'AI !' : 'AI!'
		cnoreabbrev <expr> AI/ (getcmdtype() == ':' && getcmdline() ==# 'AI/') ? 'AI /' : 'AI/'
	]])
end

function M.start()
	if M.job_id then
		return
	end

	if vim.fn.executable(M.config.binary) ~= 1 then
		vim.notify("aider-pop: aider binary not found: " .. M.config.binary, vim.log.levels.ERROR)
		return
	end

	if not M.buffer or not vim.api.nvim_buf_is_valid(M.buffer) then
		M.buffer = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(M.buffer, "aider-pop-terminal")
	end

	local cmd = { M.config.binary }
	for _, arg in ipairs(M.config.args) do
		table.insert(cmd, arg)
	end

	-- Use termopen to handle terminal emulation and interactivity natively
	vim.api.nvim_buf_call(M.buffer, function()
		M.job_id = vim.fn.termopen(cmd, {
			env = { TERM = M.config.ui.terminal_name },
			on_stdout = function(_, data)
				if not data then
					return
				end

				-- Reset/Start liveness timer to detect when Aider has stopped printing
				if M.liveness_timer then
					vim.fn.timer_stop(M.liveness_timer)
				end

				M.liveness_timer = vim.fn.timer_start(200, function()
					M.check_state()
				end)
			end,
			on_exit = function(_, exit_code)
				M.job_id = nil
				if M.liveness_timer then
					vim.fn.timer_stop(M.liveness_timer)
				end
			end,
		})
	end)
end

function M.send_raw(payload)
	local final_payload = payload
	-- Only use bracketed paste for multiline messages to avoid confusing simple prompts/mocks
	if payload:match("\n") then
		final_payload = "\27[200~" .. payload .. "\27[201~"
	end
	vim.fn.chansend(M.job_id, final_payload .. "\n")
end

function M.send(text)
	if not M.is_running() then
		vim.notify("aider-pop: Aider is not running", vim.log.levels.ERROR)
		return
	end

	-- If blocked, queue the command instead of sending it
	if M.is_blocked then
		table.insert(M.command_queue, text)
		vim.notify("aider-pop: Aider is blocked, command queued", vim.log.levels.WARN)
		return
	end

	local payload = text
	local first_char = text:sub(1, 1)
	local second_char = text:sub(2, 2)

	-- Only treat as prefix if followed by space or it's the only char (for slash commands)
	if second_char == " " or second_char == "" then
		if first_char == "?" then
			payload = "/ask " .. text:sub(2):gsub("^%s+", "")
			-- Questions always open modal
			vim.schedule(function()
				if not (M.window and vim.api.nvim_win_is_valid(M.window)) then
					M.toggle_modal()
				end
			end)
		elseif first_char == "!" then
			payload = "/run " .. text:sub(2):gsub("^%s+", "")
			-- Runs always open modal
			vim.schedule(function()
				if not (M.window and vim.api.nvim_win_is_valid(M.window)) then
					M.toggle_modal()
				end
			end)
		elseif first_char == "/" then
			payload = "/" .. text:sub(2):gsub("^%s+", "")
		elseif first_char == ":" then
			payload = "/architect " .. text:sub(2):gsub("^%s+", "")
		end
	end

	M.send_raw(payload)
end

function M.is_running()
	return M.job_id ~= nil and M.job_id > 0
end

function M.status()
	if not M.is_running() then
		return ""
	end

	local line_count = 0
	if M.buffer and vim.api.nvim_buf_is_valid(M.buffer) then
		line_count = vim.api.nvim_buf_line_count(M.buffer)
	end

	-- If modal is open, we are "reading" it now
	if M.window and vim.api.nvim_win_is_valid(M.window) then
		M.last_read_line = line_count
		-- Return a "thinking" indicator if timer is active, or just static bot
		return "🤖"
	end

	if line_count > M.last_read_line then
		return "🤖"
	end

	return ""
end

function M.toggle_modal()
	if M.window and vim.api.nvim_win_is_valid(M.window) then
		if M.buffer and vim.api.nvim_buf_is_valid(M.buffer) then
			M.last_read_line = vim.api.nvim_buf_line_count(M.buffer)
		end
		vim.api.nvim_win_close(M.window, true)
		M.window = nil
	else
		if not M.buffer or not vim.api.nvim_buf_is_valid(M.buffer) then
			return
		end

		local width = math.floor(vim.o.columns * M.config.ui.width)
		local height = math.floor(vim.o.lines * M.config.ui.height)
		local row = math.floor((vim.o.lines - height) / 2)
		local col = math.floor((vim.o.columns - width) / 2)

		M.window = vim.api.nvim_open_win(M.buffer, true, {
			relative = "editor",
			width = width,
			height = height,
			row = row,
			col = col,
			border = M.config.ui.border,
			style = "minimal",
			title = " 🤖 AIDER (Normal) ",
			title_pos = "center",
		})

		-- Set initial highlight
		vim.api.nvim_win_set_option(M.window, "winhighlight", "Normal:AiderNormal")

		-- Map Esc to return to Normal mode specifically in the Aider terminal buffer
		vim.api.nvim_buf_set_keymap(M.buffer, "t", "<Esc>", [[<C-\><C-n>]], { noremap = true, silent = true })
		-- Map Esc to close the window when in Normal mode
		vim.api.nvim_buf_set_keymap(M.buffer, "n", "<Esc>", [[<cmd>AiderPopToggle<cr>]], { noremap = true, silent = true })

		-- Autocommands to change title and background on mode switch
		local group = vim.api.nvim_create_augroup("AiderPopMode", { clear = true })

		vim.api.nvim_create_autocmd("TermEnter", {
			group = group,
			buffer = M.buffer,
			callback = function()
				if M.window and vim.api.nvim_win_is_valid(M.window) then
					vim.api.nvim_win_set_config(M.window, { title = " ⌨️ AIDER (Terminal) ", title_pos = "center" })
					vim.api.nvim_win_set_option(M.window, "winhighlight", "Normal:AiderTerminal")
				end
			end,
		})

		vim.api.nvim_create_autocmd("TermLeave", {
			group = group,
			buffer = M.buffer,
			callback = function()
				if M.window and vim.api.nvim_win_is_valid(M.window) then
					vim.api.nvim_win_set_config(M.window, { title = " 🤖 AIDER (Normal) ", title_pos = "center" })
					vim.api.nvim_win_set_option(M.window, "winhighlight", "Normal:AiderNormal")
				end
			end,
		})

		-- Always open in Normal mode
		vim.cmd("stopinsert")

		-- Auto-scroll to bottom
		local line_count = vim.api.nvim_buf_line_count(M.buffer)
		vim.api.nvim_win_set_cursor(M.window, { line_count, 0 })
	end
end

function M.stop()
	if M.is_running() then
		vim.fn.jobstop(M.job_id)
		M.job_id = nil
	end
end

return M
