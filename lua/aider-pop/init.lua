local M = {}
local job = require('aider-pop.job')
local ui = require('aider-pop.ui')

M.config = {
	binary = "aider",
	args = { "--no-gitignore", "--yes-always", "--no-pretty" },
	ui = { 
		width = 0.8, height = 0.8, border = "rounded", terminal_name = "xterm-256color",
		statusline = false 
	},
	sync = {
		active_buffers = false,
	}
}

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
			
			if query == "" then
				if char == "?" then query = "Please explain this selection:"
				elseif char == ":" then query = "Please review this selection:"
				else query = "Selection:" end
			end
			query = query .. "\n\n```\n" .. selection .. "\n```"
		end
		
		local final_text = has_prefix and (char .. " " .. query) or query
		M.send(final_text)
	end, { nargs = "*", range = true })

	vim.api.nvim_create_user_command("AiderPopToggle", function() M.toggle_modal() end, {})

	vim.cmd([[
		cnoreabbrev <expr> AI: (getcmdtype() == ':' && getcmdline() ==# 'AI:') ? 'AI :' : 'AI:'
		cnoreabbrev <expr> AI? (getcmdtype() == ':' && getcmdline() ==# 'AI?') ? 'AI ?' : 'AI?'
		cnoreabbrev <expr> AI! (getcmdtype() == ':' && getcmdline() ==# 'AI!') ? 'AI !' : 'AI!'
		cnoreabbrev <expr> AI/ (getcmdtype() == ':' && getcmdline() ==# 'AI/') ? 'AI /' : 'AI/'
	]])

	if M.config.ui.statusline then
		vim.o.statusline = vim.o.statusline .. " %{v:lua.require('aider-pop').status()}"
	end

	local group = vim.api.nvim_create_augroup("AiderPopSync", { clear = true })
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = group,
		callback = function(ev)
			if not M.config.sync.active_buffers then return end
			local bufnr = ev.buf
			if vim.api.nvim_buf_get_option(bufnr, "buftype") ~= "" then return end
			local file = vim.api.nvim_buf_get_name(bufnr)
			if file == "" or file:match("^aider%-pop://") then return end
			
			local real = vim.loop.fs_realpath(file)
			if not real then return end
			
			file = vim.fn.fnamemodify(real, ":.")
			
			-- Don't add Aider's own buffer
			if job.buffer and bufnr == job.buffer then return end
			
			M.send("/add " .. file)
		end
	})

	vim.api.nvim_create_autocmd("BufDelete", {
		group = group,
		callback = function(ev)
			if not M.config.sync.active_buffers then return end
			local bufnr = ev.buf
			
			local bt = vim.api.nvim_buf_get_option(bufnr, "buftype")
			if bt ~= "" then return end
			
			local file = vim.api.nvim_buf_get_name(bufnr)
			if file == "" or file:match("^aider%-pop://") then return end
			if file == "" then file = ev.file end
			if file == "" then return end
			
			file = vim.fn.fnamemodify(file, ":.")
			if job.buffer and bufnr == job.buffer then return end
			
			M.send("/drop " .. file)
		end
	})
end

function M.start()
	job.start(M.config, function()
		if job.is_blocked and not (ui.window and vim.api.nvim_win_is_valid(ui.window)) then
			M.toggle_modal()
			vim.cmd("startinsert")
		end
		vim.cmd("redrawstatus")
	end)
end

function M.send(text)
	M.start()
	if not job.job_id then return end
	
	local char = text:sub(1, 1)
	local map = { ["?"] = "/ask ", ["!"] = "/run ", [":"] = "/architect ", ["/"] = "/" }
	local prefix = map[char] or ""
	local msg = prefix ~= "" and text:sub(2):gsub("^%s+", "") or text
	if char == "/" then prefix, msg = "", text:gsub("^/%s+", "/") end
	
	local payload = prefix .. msg
	if msg:find("\n") then payload = "{\n" .. payload .. "\n}" end
	
	if job.is_idle and not job.is_blocked then 
		job.send_raw(payload) 
		-- If it was a sync command, follow up with /ls
		if payload:match("^/add") or payload:match("^/drop") then
			job.send_raw("/ls")
		end
	else 
		table.insert(job.command_queue, payload) 
	end
end

function M.status() return ui.status(job) end
function M.toggle_modal() 
	if not (job.job_id and job.job_id > 0) then M.start() end
	ui.toggle_modal(job, M.config) 
end
function M.stop() job.stop() end
function M.is_running() return job.job_id ~= nil and job.job_id > 0 end

-- Proxy some job properties for tests
setmetatable(M, {
	__index = function(_, key)
		if key == "is_idle" then return job.is_idle end
		if key == "is_blocked" then return job.is_blocked end
		if key == "buffer" then return job.buffer end
		if key == "job_id" then return job.job_id end
		if key == "window" then return ui.window end
	end
})

return M
