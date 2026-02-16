local M = {}

M.window = nil

function M.toggle_modal(job, config)
	if M.window and vim.api.nvim_win_is_valid(M.window) then
		job.last_read_line = job.get_last_content_line()
		vim.api.nvim_win_close(M.window, true)
		M.window = nil
		vim.cmd("redrawstatus")
	elseif job.buffer and vim.api.nvim_buf_is_valid(job.buffer) then
		local w, h = math.floor(vim.o.columns * config.ui.width), math.floor(vim.o.lines * config.ui.height)
		M.window = vim.api.nvim_open_win(job.buffer, true, {
			relative = "editor", width = w, height = h, row = math.floor((vim.o.lines - h) / 2),
			col = math.floor((vim.o.columns - w) / 2), border = config.ui.border, style = "minimal", title = " 🤖 AIDER ", title_pos = "center",
		})
		vim.api.nvim_win_set_option(M.window, "winhighlight", "Normal:AiderNormal")
		
		local g = vim.api.nvim_create_augroup("AiderPopHighlights", { clear = true })
		vim.api.nvim_create_autocmd("TermEnter", { group = g, buffer = job.buffer, callback = function() if M.window then vim.api.nvim_win_set_option(M.window, "winhighlight", "Normal:AiderTerminal") end end })
		vim.api.nvim_create_autocmd("TermLeave", { group = g, buffer = job.buffer, callback = function() if M.window then vim.api.nvim_win_set_option(M.window, "winhighlight", "Normal:AiderNormal") end end })
		
		vim.api.nvim_buf_set_keymap(job.buffer, "t", "<Esc>", [[<C-\><C-n>]], { noremap = true, silent = true })
		vim.api.nvim_buf_set_keymap(job.buffer, "n", "<Esc>", [[<cmd>AiderPopToggle<cr>]], { noremap = true, silent = true })
		
		vim.cmd("stopinsert")
		vim.api.nvim_win_set_cursor(M.window, { math.max(1, job.get_last_content_line()), 0 })
	end
end

function M.status(job)
	if not job.job_id then return "💤" end
	if job.is_blocked then return "✋" end
	if job.is_busy or not job.is_idle then return "⏳" end
	
	if job.last_answer ~= "" then
		local clean = job.last_answer:gsub("%s+", " "):gsub("^%s*", ""):sub(1, 50)
		return "🤖 " .. clean .. (#job.last_answer > 50 and "..." or "")
	end

	local content_line = job.get_last_content_line()
	return content_line > job.last_read_line and "🤖" or ""
end

return M
