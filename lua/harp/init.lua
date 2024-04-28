local M = {}
-- Don't take this example config at face value: it just contains the ideas that I was able to come up with and find useful,
-- the actual possibilities are limitless, so take inspiration from the ideas shown to make what *you* want out of harp in your neovim experience

-- You could, technically, just copy paste this entire file into your neovim config, however you probably don't want to do that.
-- Maybe you don't care about some features, or want to make your own; maybe the default mappings don't make sense for you and you want to change them.

-- You'll see this function get used throughout most, if not all, mappings. The reason for it to exist is simply so we don't have to make a billion different mappings per every key.

--- Get a character from the user, unless they press escape, in which case return nil, usually to cancel whatever action the user wanted to do.
--- @param prompt string What text to show when asking the user for the character
function M.get_char(prompt)
	prompt = prompt or ''
	vim.api.nvim_echo({ { prompt, 'Input' } }, true, {})
	local char = vim.fn.getcharstr()
	-- That's the escape character (`<Esc>`). Not sure how to specify it smarter
	-- In other words, if you pressed escape, we return nil
	---@diagnostic disable-next-line: cast-local-type
	if char == '' then char = nil end
	return char
end

--- Split input by lines, get an array-like table with each line.
--- @param string string
---@return table
function M.split_by_newlines(string)
	local lines = {}
	for line in string.gmatch(string, '([^\n]+)') do
		table.insert(lines, line)
	end
	return lines
end

--- Get the path to a default (global) harp.
--- `nil`, if it doesn't exist.
--- @param register string
--- @return string?
function M.default_get_path(register)
	local output = vim.fn.system('harp get harps ' .. register .. ' --path')
	-- vim.v.shell_error is set by calling vim.fn.system() — so basically, it's the exit status of the last called shell command
	if vim.v.shell_error == 0 and output then
		return output
	else
		return nil
	end
end

--- Get a character from the user, and `:edit` that register's path (the key the user presses is considered the register).
--- If the register doesn't exist / have a path, show a notification with an error message instead.
function M.default_get()
	-- when you'll press your remap to get (<Leader>s by default), you'll see "get harp: " in your statusline
	-- this is just a message to let you know the action you're doing
	-- you can remove it by specifying an empty string instead (''), or defining your own message that makes more sense to you
	local register = M.get_char('get harp: ')
	-- this effectively means that you can press <Escape> to cancel out of this entire function
	if register == nil then return end
	local path = M.default_get_path(register)
	if path then
		vim.cmd.edit(path) -- `:edit` automatically puts you in the last place you were in the file, so that's why we don't store or use the line and column properties ourselves
	else
		-- if something fucks up, we assume it's because the register is empty.
		-- this might not be the actual source of the error, but it's easier to assume than to do proper error handling.
		-- reasoning? — if something fucked up, your first instinct should be to go execute the same command in your shell to check the actual error message
		-- so it being handled in your neovim mappings ins't really needed, since the only case that *will*
		-- constantly happen and isn't considered wrong behavior, is if a harp is empty.
		-- Once again, feel free to change the message to one that makes more sense to you.
		vim.notify('harp ' .. register .. ' is empty')
	end
end

--- Set the path of a default (global) harp.
--- @param register string
--- @param path string
--- @return boolean success
function M.default_set_path(register, path)
	-- the actual command call will look something like:
	-- `harp update harps a --path '~/programming/dotfiles/colors.css'`
	-- the reason why I use single quotes for surrounding path, is so that no bash shell expansions happen
	-- so it's not just a style choice
	vim.fn.system("harp update harps '" .. register .. "' --path '" .. path .. "'")
	return vim.v.shell_error == 0
end

--- Get a character from the user, and use it as a register name;
--- Set the path of that register to be the path to the current buffer.
--- Weirdo "buffers" like manpages work too.
function M.default_set()
	local register = M.get_char('set harp: ')
	if register == nil then return end
	-- gets the full path of the current buffer.
	-- however, if it's in your home directory, /home/username will instead be displayed as ~
	-- /home/username/programming/dotfiles/colors.css → ~/programming/dotfiles/colors.css
	-- we save a few characters in storage this way
	local path = vim.fn.expand('%:~')
	local success = M.default_set_path(register, path)
	if success then vim.notify('set harp ' .. register) end
end

--- Get the path of a harp, that's relative to a directory.
--- @param register string
--- @param directory string directory, that the register is relative to.
--- @return string? path of the specified register, or nil if it doesn't exist.
function M.percwd_get_path(register, directory)
	-- the way this works, is that we create a new harp section per every different cwd
	-- so if you make a percwd harp while your cwd is ~/prog/dotfiles (you can check by :pwd),
	-- you now have a section called cwd_harps_~/prog/dotfiles
	-- the command call ends up looking something like this:
	-- `harp get 'cwd_harps_~/prog/dotfiles' a --path`
	local output = vim.fn.system("harp get 'cwd_harps_" .. directory .. "' " .. register .. ' --path')
	if vim.v.shell_error == 0 and output then
		return output
	else
		return nil
	end
end

--- Get a character from the user, and `:edit` that register's path (the key the user presses is considered the register).
--- If the register doesn't exist / have a path, show a notification with an error message instead.
--- This is different from `default_get` in that the register is relative to the current working directory, rather than global.
function M.percwd_get()
	local register = M.get_char('get local harp: ')
	if register == nil then return end
	local cwd = vim.fn.getcwd()
	-- if `cwd` has /home/username, that will be replaced with ~
	-- /home/username/prog/dotfiles → ~/prog/dotfiles
	cwd = vim.fn.fnamemodify(cwd, ':~')
	local output = M.percwd_get_path(register, cwd)
	if output then
		vim.cmd.edit(output)
	else
		vim.notify('local harp ' .. register .. ' is empty')
	end
end

--- Set the path of a harp, that's relative to `directory` (rather than a global harp).
--- @param register string
--- @param directory string that the register is relative to
--- @param path string
--- @return boolean success
function M.percwd_set_path(register, directory, path)
	-- the command call ends up looking something like: `harp update 'cwd_harps_~/programming/dotfiles' a --path "astro/lua/lazy_setup.lua"`
	-- we only store a relative path because we are *already* relative to the correct directory when we call percwd_get, so there's no need to have the full file path (:edit accepts either a full path, or a path relative to cwd )
	-- so we need to store less characters this way
	vim.fn.system("harp update 'cwd_harps_" .. cwd .. "' " .. register .. " --path '" .. path .. "'")
	return vim.v.shell_error == 0
end

--- Get a character from the user, and use it as a register name;
--- Set the path of that register.
--- Different from `default_set` in that the registers are relative to current working directory, rather than being global.
function M.percwd_set()
	local register = M.get_char('set local harp: ')
	if register == nil then return end
	local cwd = vim.fn.getcwd()
	cwd = vim.fn.fnamemodify(cwd, ':~')
	-- this will get us the buffer's path.
	-- if it's inside of cwd, it will be relative to cwd
	-- but if it's not, it's a full path that replaces /home/username with ~
	-- so, if your cwd is ~/prog/dotfiles and the buffer's path is /home/username/dotfiles/awesome/keys.lua
	-- it will be turned into awesome/keys.lua
	-- if the buffer's path was /home/username/backup/kitty/kitty.conf (notice, it's not in dotfiles anymore)
	-- it will be turned into ~/backup/kitty/kitty.conf
	-- this lets you save storage space in the data file while retaining the ability to store any buffer path
	local path = vim.fn.expand('%:~:.')
	local success = M.percwd_set_path(register, cwd, path)
	if success then vim.notify('set local harp ' .. register) end
end

--- Get the path of a register in a section that holds directory paths (rather than file paths).
--- @param register string? `nil` if register doesn't exist / doesn't have the path set.
function M.cd_get_path(register)
	-- `harp get 'cd_harps' a --path`
	-- I'm a fish shell user, but `system` still calls commands in bash (if not sh 🤔) fwiw.
	-- It doesn't particularly matter here, just thought it was useful information.
	local output = vim.fn.system("harp get 'cd_harps' " .. register .. ' --path')
	if vim.v.shell_error == 0 and output then
		return output
	else
		return nil
	end
end

--- Get a character from the user, and consider it the register;
--- Get the path of that register in the `cd` section, and `:tcd` into it.
--- If the register doesn't exist / have a path, show a notification with an error message instead.
function M.cd_get()
	local register = M.get_char('get cd harp: ')
	if register == nil then return end
	if output then
		-- we change cwd only for the current tab, so you can easily have a bunch of tabs with diferent cwd
		-- don't confuse tabs and buffers
		vim.cmd.tcd(output)
	else
		vim.notify('cd harp ' .. register .. ' is empty')
	end
end

--- Set the path of a `cd` harp, that stores directory paths, rather than file paths.
--- @param register string
--- @param directory string
--- @return boolean success
function M.cd_set_path(register, directory)
	-- `harp update 'cd_harps' a --path '~/prog/dotfiles'`
	vim.fn.system("harp update 'cd_harps' " .. register .. " --path '" .. directory .. "'")
	if vim.v.shell_error == 0 then
		return true
	else
		return false
	end
end

--- Get a character from the user, and use it as a register name;
--- Set the path of that register in the `cd` section to be your current working directory.
--- If everything went correctly, display a notification with a success message.
function M.cd_set()
	local register = M.get_char('set cd harp: ')
	if register == nil then return end
	local cwd = vim.fn.getcwd()
	cwd = vim.fn.fnamemodify(cwd, ':~')
	local success = M.cd_set_path(register, cwd)
	if success then vim.notify('set cd harp ' .. register) end
end

--- Get the line and column of a register in the section, that is relative to a buffer.
---@param register string
---@param path string path to the file, that becomes a part of the section name.
---@return table? location with properties line, column. `nil` if section doesn't exist.
function M.perbuffer_mark_get_location(register, path)
	-- `harp get 'local_marks_~/prog/dotfiles/colors.css' a --line --column`
	-- since these registers are per *buffer* locations, we don't need to go to any other file when we call this function
	-- all we need to do is move the cursor to the correct line and column
	-- that means that we don't need to store the filepath in the register, only in the section
	local output = vim.fn.system("harp get 'local_marks_" .. path .. "' " .. register .. ' --line --column')
	-- we could instead just call harp twice and not have to split the output by newlines, but that would be slower
	-- probably not noticeably slower, but technically bad
	if vim.v.shell_error == 0 and output then
		local lines = M.split_by_newlines(output)
		local line = lines[1]
		local column = lines[2]
		return { line = line, column = column }
	else
		return nil
	end
end

--- Get a character from the user, and consider it the register;
--- Move to the line and column specified in the register, in a section that's relative to the current buffer.
--- This is effectively a reimplementation of builtin local marks.
--- If mark is not set, displays a notification with the error message.
function M.perbuffer_mark_get()
	local register = M.get_char('get local mark: ')
	if register == nil then return end
	local path = vim.fn.expand('%:~')
	local output = M.perbuffer_mark_get_location(register, path)
	if output then
		-- whenever you see `vim.fn`, that means that you can search for the documentation for the next word (in this case, `cursor`) like `:help cursor()`
		-- for `vim.cmd`, same idea, but it'd be `:help :cursor` instead
		vim.fn.cursor({ output.line, output.column })
	else
		vim.notify('local mark ' .. register .. ' is empty')
	end
end

--- Set the line and column in a register, that's in a section relative to `path`
--- Essentially, set a local (perbuffer) mark.
---@param register string
---@param path string the file path ends up being part of the name of a new section
---@param line number
---@param column number
---@return boolean success
function M.perbuffer_mark_set_location(register, path, line, column)
	-- `harp update 'local_marks_~/prog/dotfiles/colors.css' a --line 23 --column 46`
	vim.fn.system(
		"harp update 'local_marks_"
			.. path
			.. "' "
			.. register
			.. ' --line '
			.. tostring(line)
			.. ' --column '
			.. tostring(column)
	)
	if vim.v.shell_error == 0 then
		return true
	else
		return false
	end
end

--- Get a character from the user, and consider it the register name;
--- Set the line and column properties of the register, to be your current cursor position.
--- This register is in a section, relative to the current buffer.
--- In other words, set a local (perbuffer) mark.
function M.perbuffer_mark_set()
	local register = M.get_char('set local mark: ')
	if register == nil then return end
	local path = vim.fn.expand('%:~')
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1]
	local column = cursor[2]
	local success = M.perbuffer_mark_set_location(register, path, line, column)
	if success then vim.notify('set local mark ' .. register) end
end

--- Get the location (path, line, column) of a global mark.
---@param register string
---@return table? location with properties path, line, column. Or `nil` if register doesn't exist.
function M.global_mark_get_location(register)
	-- `harp get 'global_marks' a --path --line --column`
	local output = vim.fn.system("harp get 'global_marks' '" .. register .. "' --path --line --column")
	if vim.v.shell_error == 0 and output then
		local lines = M.split_by_newlines(output)
		local path = lines[1]
		local line = lines[2]
		local column = lines[3]
		return { path = path, line = line, column = column }
	else
		return nil
	end
end

--- Get a character from the user, and consider it the register name;
--- Go to the position (path, line, column), contained in the register (you "go" by `:edit`ing the file path, and moving the cursor to the correct line and column).
--- If register doesn't exist, show notification with the error message.
--- This is effectively a reimplementation of builtin global marks.
function M.global_mark_get()
	local register = M.get_char('get global mark: ')
	if register == nil then return end
	local output = M.global_mark_get_location(register)
	if output then
		vim.cmd.edit(output.path)
		vim.fn.cursor({ output.line, output.column })
	else
		vim.notify('global mark ' .. register .. ' is empty')
	end
end

--- Set the path, line, and column of a register in the `global_marks` section.
---@param register string
---@param path string
---@param line number
---@param column number
---@return boolean success
function M.global_mark_set_location(register, path, line, column)
	-- `harp update 'global_marks' a --path '~/prog/dotfiles/colors.css' --line 23 --column 46`
	vim.fn.system(
		"harp update 'global_marks' "
			.. register
			.. " --path '"
			.. path
			.. "' --line "
			.. tostring(line)
			.. ' --column '
			.. tostring(column)
	)
	if vim.v.shell_error == 0 then
		return true
	else
		return false
	end
end

--- Get a character from the user, and set a global mark, located in that character's register.
--- If mark was successfully set, display a notification.
function M.global_mark_set()
	local register = M.get_char('set global mark: ')
	if register == nil then return end
	local path = vim.fn.expand('%:~')
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1]
	local column = cursor[2]
	local success = M.global_mark_set_location(register, path, line, column)
	if success then vim.notify('set global mark ' .. register) end
end

function M.setup()
	if vim.fn.executable('harp') ~= 1 then
		print('harp-nvim: harp was not found in your path')
		return
	end
end

return M
