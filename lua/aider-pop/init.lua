local M = {}

M.config = {
	binary = "aider",
}

M.job_id = nil

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	M.start()
end

function M.start()
	if M.job_id then
		return
	end

	local cmd = { M.config.binary, "--no-auto-commits" }

	M.job_id = vim.fn.jobstart(cmd, {
		on_exit = function(_, exit_code)
			M.job_id = nil
		end,
	})
end

function M.is_running()
	return M.job_id ~= nil and M.job_id > 0
end

return M
