local M = {}

-- Side effect: Resumes session if conditions are met
function M.maybe_resume(job, chat_files)
	if not job.config.resume_session or job.has_resumed then return end
	
	-- Pick first file
	local candidate = next(chat_files)
	if not candidate then return end

	vim.schedule(function()
		local cur_buf = vim.api.nvim_get_current_buf()
		local is_blank = vim.api.nvim_buf_get_name(cur_buf) == "" 
			and vim.api.nvim_buf_get_option(cur_buf, "modified") == false
			and vim.fn.argc() == 0
		
		if is_blank then
			vim.cmd("edit " .. vim.fn.fnameescape(candidate))
		end
	end)
	job.has_resumed = true
end

-- Side effect: Opens/Closes Neovim buffers to match Aider state
function M.reconcile(job, new_state)
	-- 1. Session Resumption
	M.maybe_resume(job, new_state.chat)

	-- 2. Update Whitelist
	for k, v in pairs(new_state.repo) do job.repo_files[k] = v end
	for k, v in pairs(new_state.chat) do job.repo_files[k] = v end

	-- Clear pending adds for any files that Aider now officially reports as in chat
	for path, _ in pairs(new_state.chat) do
		job.pending_adds[path] = nil
	end

	-- 3. Capture OLD chat state for the deletion loop
	local old_chat_files = job.chat_files
	-- UPDATE STATE
	job.chat_files = new_state.chat

	-- 4. Buffer Management (Optional)
	if job.config.sync_buffers then
		vim.schedule(function()
			-- (1) Addition: Ensure all files Aider says are in chat are open in Nvim
			for path, _ in pairs(new_state.chat) do
				if vim.fn.bufexists(path) == 0 then
					local bufnr = vim.fn.bufadd(path)
					vim.fn.bufload(bufnr)
					vim.fn.setbufvar(bufnr, "&buflisted", 1)
				end
			end

			-- (2) Deletion: Only close if it WAS in chat and is now GONE from Aider's report
			for _, b in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_option(b, "buflisted") then
					local name = vim.api.nvim_buf_get_name(b)
					local b_real = vim.loop.fs_realpath(name)
					if b_real and old_chat_files[b_real] and not new_state.chat[b_real] then
						vim.api.nvim_buf_delete(b, { force = true })
					end
				end
			end

			-- (3) Catch-up Addition: Project file open in Nvim but not in Chat
			for _, b in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_option(b, "buflisted") then
					local name = vim.api.nvim_buf_get_name(b)
					local b_real = vim.loop.fs_realpath(name)
					if b_real and job.repo_files[b_real] and not new_state.chat[b_real] and not job.pending_adds[b_real] then
						job.pending_adds[b_real] = true
						require('aider-pop').send("/add " .. vim.fn.fnamemodify(b_real, ":."))
					end
				end
			end

			job.is_syncing = false
		end)
	else
		job.is_syncing = false
	end
end

function M.maybe_add(job, real_path)
	if not job.repo_files[real_path] or job.chat_files[real_path] or job.pending_adds[real_path] then return end
	local rel = vim.fn.fnamemodify(real_path, ":.")
	job.pending_adds[real_path] = true
	require('aider-pop').send("/add " .. rel)
end

function M.maybe_drop(job, real_path)
	local rel = vim.fn.fnamemodify(real_path, ":.")
	require('aider-pop').send("/drop " .. rel)
end

return M
