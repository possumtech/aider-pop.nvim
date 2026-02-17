local M = {}

function M.strip_ansi(text)
	if not text then return "" end
	return text
		:gsub("\27%[[0-9;]*m", "")
		:gsub("\27%[[0-9;]*[A-K]", "")
		:gsub("\27%[[0-9;]*[mG]", "")
		:gsub("\r", "")
end

function M.resolve_path(p)
	if not p or p == "" then return nil end
	local clean = p:gsub("^@", "")
	return vim.loop.fs_realpath(clean)
end

function M.parse_output(lines)
	local chat_files = {}
	local repo_files = {}
	local found_sync_data = false
	local empty_list_detected = false
	
	local in_file_list, in_repo_list = false, false

	for _, line in ipairs(lines) do
		local l = M.strip_ansi(line):gsub("^%s*", ""):gsub("%s*$", "")
		local clean_l = l:gsub("^[^>]*>%s*", ""):gsub(">%s*$", ""):gsub("^%s*", ""):gsub("%s*$", "")
		
		if clean_l:match("^Read%-only files:") or clean_l:match("^Files in chat:") then
			chat_files = {} 
			in_file_list, in_repo_list = true, false
			found_sync_data = true
		elseif clean_l:match("^Repo files not in the chat:") then
			repo_files = {} 
			in_file_list, in_repo_list = false, true
			found_sync_data = true
		elseif clean_l:match("^No files in chat") then
			in_file_list, in_repo_list = false, false
			chat_files = {}
			empty_list_detected = true
			found_sync_data = true
		else
			local readonly_match = clean_l:match("Readonly:%s*(.*)")
			local editable_match = clean_l:match("Editable:%s*(.*)")
			
			if readonly_match or editable_match then
				found_sync_data = true
				if readonly_match then 
					chat_files = {} 
					for f in readonly_match:gmatch("%S+") do 
						local r = M.resolve_path(f)
						if r then chat_files[r] = true end
					end 
				end
				if editable_match then 
					if not readonly_match then chat_files = {} end
					for f in editable_match:gmatch("%S+") do 
						local r = M.resolve_path(f)
						if r then chat_files[r] = true end
					end 
				end
			elseif in_file_list or in_repo_list then
				local file = clean_l:gsub("^%s*", "")
				if file ~= "" and not file:match("^architect>") and not file:match("^/") then
					local r = M.resolve_path(file)
					if r then
						if in_file_list then chat_files[r] = true 
						else repo_files[r] = true end
					end
				elseif file:match("^architect>") then
					in_file_list, in_repo_list = false, false
				end
			end
		end
	end

	return {
		chat = chat_files,
		repo = repo_files,
		found_data = found_sync_data,
		is_empty = empty_list_detected
	}
end

return M
