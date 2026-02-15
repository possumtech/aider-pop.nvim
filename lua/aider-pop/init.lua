local M = {}

M.config = {
	binary = "aider",
	args = { "--no-auto-commits" },
}

M.job_id = nil

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	if opts and opts.args then
		M.config.args = opts.args
	end
	M.start()

	vim.api.nvim_create_user_command("AI", function(cmd_opts)
		M.send(cmd_opts.args)
	end, { nargs = "*" })

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

	local cmd = { M.config.binary }
	for _, arg in ipairs(M.config.args) do
		table.insert(cmd, arg)
	end

	M.job_id = vim.fn.jobstart(cmd, {
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
	if text:sub(1, 1) == "?" then
		payload = "/ask " .. text:sub(2):gsub("^%s+", "")
	elseif text:sub(1, 1) == "!" then
		payload = "/run " .. text:sub(2):gsub("^%s+", "")
	elseif text:sub(1, 1) == "/" then
		payload = "/" .. text:sub(2):gsub("^%s+", "")
	elseif text:sub(1, 1) == ":" then
		payload = "/architect " .. text:sub(2):gsub("^%s+", "")
	end

	vim.fn.chansend(M.job_id, payload .. "\n")
end

function M.is_running()
	return M.job_id ~= nil and M.job_id > 0
end

function M.stop()
	if M.is_running() then
		vim.fn.jobstop(M.job_id)
		M.job_id = nil
	end
end

return M
