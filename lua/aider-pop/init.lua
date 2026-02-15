local M = {}

M.config = {
	binary = "aider",
	args = { "--no-gitignore", "--yes-always" },
	ui = {
		width = 0.8,
		height = 0.8,
		border = "rounded",
	},
}

M.job_id = nil
M.buffer = nil
M.term_id = nil
M.window = nil

function M.setup(opts)
	local args = (opts and opts.args) and opts.args or M.config.args
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	M.config.args = args
	M.start()

	vim.api.nvim_create_user_command("AI", function(cmd_opts)
		M.send(cmd_opts.args)
	end, { nargs = "*" })

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
		vim.api.nvim_buf_set_name(M.buffer, "aider-pop-output")
		
		-- Use nvim_open_term to handle ANSI/Terminal emulation in the buffer
		M.term_id = vim.api.nvim_open_term(M.buffer, {})
	end

	local cmd = { M.config.binary }
	for _, arg in ipairs(M.config.args) do
		table.insert(cmd, arg)
	end

	-- DEBUG
	local debug_file = io.open("aider_cmd_debug.log", "a")
	if debug_file then
		debug_file:write(os.date("%Y-%m-%d %H:%M:%S") .. " Starting: " .. table.concat(cmd, " ") .. "\n")
		debug_file:close()
	end

	M.job_id = vim.fn.jobstart(cmd, {
		pty = true,
		on_stdout = function(_, data)
			if data then
				-- Feed raw data into the terminal emulator
				local joined = table.concat(data, "\n")
				if joined ~= "" then
					vim.api.nvim_chan_send(M.term_id, joined)
				end
			end
		end,
		on_exit = function(_, exit_code)
			M.job_id = nil
		end,
	})
end

function M.send(text)
	if not M.is_running() then
		vim.notify("aider-pop: Aider is not running", vim.log.levels.ERROR)
		return
	end

	local payload = text
	local first_char = text:sub(1, 1)
	local second_char = text:sub(2, 2)

	-- Only treat as prefix if followed by space or it's the only char (for slash commands)
	if (second_char == " " or second_char == "") then
		if first_char == "?" then
			payload = "/ask " .. text:sub(2):gsub("^%s+", "")
			-- Auto-open modal for questions
			if not (M.window and vim.api.nvim_win_is_valid(M.window)) then
				M.toggle_modal()
			end
		elseif first_char == "!" then
			payload = "/run " .. text:sub(2):gsub("^%s+", "")
		elseif first_char == "/" then
			payload = "/" .. text:sub(2):gsub("^%s+", "")
		elseif first_char == ":" then
			payload = "/architect " .. text:sub(2):gsub("^%s+", "")
		end
	end

	vim.fn.chansend(M.job_id, payload .. "\n")
end

function M.is_running()
	return M.job_id ~= nil and M.job_id > 0
end

function M.toggle_modal()
	if M.window and vim.api.nvim_win_is_valid(M.window) then
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
		})
		
		-- Map Esc to return to Normal mode specifically in the Aider terminal buffer
		vim.api.nvim_buf_set_keymap(M.buffer, 't', '<Esc>', [[<C-\><C-n>]], {noremap = true, silent = true})

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
