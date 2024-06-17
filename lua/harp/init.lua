local M = {}

---@param cmd table
---@return vim.SystemCompleted
local function shell(cmd) return vim.system(cmd, { text = true }):wait() end

--- Get a character from the user, unless they press escape, in which case return nil, usually to cancel whatever action the user wanted to do.
--- You'll see this function get used throughout most, if not all, default mappings. The reason for it to exist is simply so we don't have to make a billion different mappings per every key.
---@param prompt string what text to show when asking the user for the character.
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
---@param string string
---@return table lines
function M.split_by_newlines(string)
	return vim.fn.split(string, '\n')
end

--- Returns the full path of the current buffer.
--- However, if it's in your home directory, /home/username will instead be displayed as ~
--- /home/username/programming/dotfiles/colors.css → ~/programming/dotfiles/colors.css
---@return string path
function M.path_get_full_buffer() return vim.fn.expand('%:~') end

--- Returns your current working directory.
--- If it has /home/username, that will be replaced with ~
--- /home/username/prog/dotfiles → ~/prog/dotfiles
---@return string cwd
function M.path_get_cwd() return vim.fn.fnamemodify(vim.fn.getcwd(), ':~') end

--- Returns the path to the current buffer.
--- If it's inside of cwd, it will be relative to cwd.
--- But if it's not, it's a full path that replaces /home/username with ~
--- So, if your cwd is ~/prog/dotfiles and the buffer's path is /home/username/prog/dotfiles/awesome/keys.lua,
--- it will be turned into awesome/keys.lua
--- If the buffer's path was /home/username/backup/kitty/kitty.conf (notice, it's not in dotfiles anymore),
--- it will be turned into ~/backup/kitty/kitty.conf
---@return string buffer_path
function M.path_get_relative_buffer() return vim.fn.expand('%:~:.') end

--- Get the path to a default (global) harp, located in the `harps` section.
---@param register string
---@return string? path `nil`, if it doesn't exist in the register.
function M.default_get_path(register)
	local result = shell({ 'harp', 'get', 'harps', register, '--path' })
	if result.code == 0 then
		return result.stdout
	else
		return nil
	end
end

--- Get a character from the user, and consider it the register;
--- `:edit` the path stored in the register.
--- If the register doesn't exist / have a path, show a notification with an error message instead.
function M.default_get()
	local register = M.get_char('get harp: ')
	-- this effectively means that you can press <Esc> to cancel out of this entire function
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
		vim.notify('harp ' .. register .. ' is empty')
	end
end

--- Set the path of a default (global) harp, stored in the `harps` section.
---@param register string
---@param path string
---@return boolean success
function M.default_set_path(register, path)
	return shell({ 'harp', 'update', 'harps', register, '--path', '--', path }).code == 0
end

--- Get a character from the user, and consider it the register;
--- Set the path of that register to be the path to the current buffer.
--- The path is a full path, with /home/username replaced with ~
--- You can conveniently get a path like that by using `require('harp').path_get_full_buffer()`
--- Weirdo "buffers" like manpages work too.
function M.default_set()
	local register = M.get_char('set harp: ')
	if register == nil then return end
	local path = M.path_get_full_buffer()
	local success = M.default_set_path(register, path)
	if success then vim.notify('set harp ' .. register) end
end

--- Get the path of a harp, that's relative to a directory.
--- The section the register will belong to, is made by concatenating 'cwd_harps_' and the directory you pass.
---@param register string
---@param directory string that the register is relative to.
---@return string? path of the specified register, or nil if it doesn't exist.
function M.percwd_get_path(register, directory)
	-- the way this works, is that we create a new harp section per every different cwd
	-- so if you make a percwd harp while your cwd is ~/prog/dotfiles (you can check by :pwd),
	-- you now have a section called cwd_harps_~/prog/dotfiles
	local result = shell({ 'harp', 'get', 'cwd_harps_' .. directory, register, '--path' })
	if result.code == 0 then
		return result.stdout
	else
		return nil
	end
end

--- Get a character from the user, and consider it the register;
--- `:edit` the path stored in the register.
--- The section the register will belong to, is made by concatenating 'cwd_harps_' and your current working directory.
--- You can conveniently get your current working directory by using `require('harp').path_get_cwd()`
--- If the register doesn't exist / have a path, show a notification with an error message instead.
--- This is different from `default_get` in that the register is relative to the current working directory, rather than global.
function M.percwd_get()
	local register = M.get_char('get local harp: ')
	if register == nil then return end
	local cwd = M.path_get_cwd()
	local output = M.percwd_get_path(register, cwd)
	if output then
		vim.cmd.edit(output)
	else
		vim.notify('local harp ' .. register .. ' is empty')
	end
end

--- Set the path of a harp, that's relative to `directory` (rather than a global harp).
---@param register string
---@param directory string that the register is relative to
---@param path string
---@return boolean success
function M.percwd_set_path(register, directory, path)
	-- we only store a relative path because we are *already* relative to the correct directory when we call percwd_get, so there's no need to have the full file path (:edit accepts either a full path, or a path relative to cwd )
	-- so we need to store less characters this way
	return shell({ 'harp', 'update', 'cwd_harps_' .. directory, register, '--path', path }).code == 0
end

--- Get a character from the user, and consider it the register;
--- Set the path of that register.
--- Different from `default_set` in that the registers are relative to current working directory, rather than being global.
--- Current working directory is gotten by calling `require('harp').path_get_cwd()`
--- The path set to the register is the path to the current buffer, gotten by calling `require('harp').path_get_relative_buffer()`
function M.percwd_set()
	local register = M.get_char('set local harp: ')
	if register == nil then return end
	local cwd = M.path_get_cwd()
	local path = M.path_get_relative_buffer()
	local success = M.percwd_set_path(register, cwd, path)
	if success then vim.notify('set local harp ' .. register) end
end

--- Get the path of a register in a section (called `cd_harps`) that holds directory paths (rather than file paths).
---@param register string? `nil` if register doesn't exist / doesn't have the path set.
function M.cd_get_path(register)
	local result = shell({ 'harp', 'get', 'cd_harps', register, '--path' })
	if result.code == 0 then
		return result.stdout
	else
		return nil
	end
end

--- Get a character from the user, and consider it the register;
--- Get the path of that register in the `cd_harps` section, and `:tcd` into it.
--- If the register doesn't exist / have a path, show a notification with an error message instead.
function M.cd_get()
	local register = M.get_char('get cd harp: ')
	if register == nil then return end
	local output = M.cd_get_path(register)
	if output then
		-- we change cwd only for the current tab, so you can easily have a bunch of tabs with diferent cwd
		-- don't confuse tabs and buffers
		vim.cmd.tcd(output)
	else
		vim.notify('cd harp ' .. register .. ' is empty')
	end
end

--- Set the path of a register located in the `cd_harps` section, that stores directory paths, rather than file paths.
---@param register string
---@param directory string
---@return boolean success
function M.cd_set_path(register, directory)
	return shell({ 'harp', 'update', 'cd_harps', register, '--path', directory }).code == 0
end

--- Get a character from the user, and consider it the register;
--- Set the path of that register in the `cd_harps` section to be your current working directory.
--- Current working directory is gotten by calling `require('harp').path_get_cwd()`
--- If everything went correctly, display a notification with a success message.
function M.cd_set()
	local register = M.get_char('set cd harp: ')
	if register == nil then return end
	local cwd = M.path_get_cwd()
	local success = M.cd_set_path(register, cwd)
	if success then vim.notify('set cd harp ' .. register) end
end

--- Get the line and column of a register in the section, that is relative to `path`
---@param register string
---@param path string path to the file, that becomes a part of the section name.
---@return table? location with properties line, column. `nil` if section doesn't exist.
function M.perbuffer_mark_get_location(register, path)
	-- since these registers are per *buffer* locations, we don't need to go to any other file when we call this function
	-- all we need to do is move the cursor to the correct line and column
	-- that means that we don't need to store the filepath in the register, only in the section
	local result = shell({ 'harp', 'get', 'local_marks_' .. path, register, '--line', '--column' })
	-- we could instead just call harp twice and not have to split the output by newlines, but that would be slower
	-- probably not noticeably slower, but technically bad
	if result.code == 0 then
		local lines = M.split_by_newlines(result.stdout)
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
	local path = M.path_get_full_buffer()
	local output = M.perbuffer_mark_get_location(register, path)
	if output then
		-- whenever you see `vim.fn`, that means that you can search for the documentation for the next word (in this case, `cursor`) like `:help cursor()`
		-- for `vim.cmd`, same idea, but it'd be `:help :cursor` instead
		vim.fn.cursor({ output.line, output.column })
	else
		vim.notify('local mark ' .. register .. ' is empty')
	end
end

--- Set the line and column in a register, that's in a section relative to the `path`.
--- Essentially, set a local (perbuffer) mark.
---@param register string
---@param path string the file path ends up being part of the name of a new section
---@param line number
---@param column number
---@return boolean success
function M.perbuffer_mark_set_location(register, path, line, column)
	return shell({
		'harp',
		'update',
		'local_marks_' .. path,
		register,
		'--line',
		tostring(line),
		'--column',
		tostring(column),
	}).code == 0
end

--- Get a character from the user, and consider it the register;
--- Set the line and column properties of the register, to be your current cursor position.
--- In other words, set a local (perbuffer) mark.
--- The section the register is in is created by concatenating `local_marks_` with the buffer path.
--- So the section name ends up looking something like `local_marks_~/prog/dotfiles/colors.css`
--- The buffer path is gotten by calling `require('harp').path_get_full_buffer()`
function M.perbuffer_mark_set()
	local register = M.get_char('set local mark: ')
	if register == nil then return end
	local path = M.path_get_full_buffer()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1]
	local column = cursor[2]
	local success = M.perbuffer_mark_set_location(register, path, line, column)
	if success then vim.notify('set local mark ' .. register) end
end

--- Get the location (path, line, column) of a global mark, stored as a register in the `global_marks` section.
---@param register string
---@return table? location with properties path, line, column. Or `nil` if register doesn't exist.
function M.global_mark_get_location(register)
	local result = shell({ 'harp', 'get', 'global_marks', register, '--path', '--line', '--column' })
	if result.code == 0 then
		local lines = M.split_by_newlines(result.stdout)
		local path = lines[1]
		local line = lines[2]
		local column = lines[3]
		return { path = path, line = line, column = column }
	else
		return nil
	end
end

--- Get a character from the user, and consider it the register;
--- Go to the position (path, line, column) contained in the register (you "go" by `:edit`ing the file path, and moving the cursor to the correct line and column).
--- If register doesn't exist, show a notification with the error message.
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
	return shell({
		'harp',
		'update',
		'global_marks',
		register,
		'--path',
		path,
		'--line',
		tostring(line),
		'--column',
		tostring(column),
	}).code == 0
end

--- Get a character from the user, and consider it the register;
--- Set a global mark, located in that register.
--- When setting a global mark, the current buffer path is used,
--- it is gotten by calling `require('harp').path_get_full_buffer()`
--- Also, the current line and column are used.
--- If mark was successfully set, display a notification.
function M.global_mark_set()
	local register = M.get_char('set global mark: ')
	if register == nil then return end
	local path = M.path_get_full_buffer()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1]
	local column = cursor[2]
	local success = M.global_mark_set_location(register, path, line, column)
	if success then vim.notify('set global mark ' .. register) end
end

--- Get the path of a harp stored in the `positional_harps` section.
---@param register string
---@return string? path of the specified register, or nil if it doesn't exist.
function M.positional_get_path(register)
	local result = shell({ 'harp', 'get', 'positional_harps', register, '--path' })
	if result.code == 0 then
		return result.stdout
	else
		return nil
	end
end

--- Get a character from the user, and consider it the register;
--- `:edit` the path stored in the register.
--- Positional harps just store the relative path, and don't care about your current working directory (unlike percwd harps).
--- The effect that gives you, is that you can open the same *position* in the file structure of any project, without having to set all your registers again for the new project (which you'd have to do with percwd harps).
--- The most useful example of using this, is putting `.gitignore` in a register, to be able to open any project's `.gitignore` quickly in the future.
--- If the register doesn't exist / have a path, show a notification with an error message instead.
--- The section that the register will belong to is `positional_harps`.
function M.positional_get()
	local register = M.get_char('get positional harp: ')
	if register == nil then return end
	local output = M.positional_get_path(register)
	if output then
		vim.cmd.edit(output)
	else
		vim.notify('positional harp ' .. register .. ' is empty')
	end
end

--- Set the path of a harp, that is stored in the `positional_harps` section.
---@param register string
---@param path string
---@return boolean success
function M.positional_set_path(register, path)
	return shell({ 'harp', 'update', 'positional_harps', register, '--path', path }).code == 0
end

--- Get a character from the user, and consider it the register;
--- Set the path of that register.
--- The register is stored in the `positional_harps` section.
--- See comment of `require('harp').positional_get()` to understand how positional harps are different from percwd harps.
--- The path set to the register is the path to the current buffer, gotten by calling `require('harp').path_get_relative_buffer()`
function M.positional_set()
	local register = M.get_char('set positional harp: ')
	if register == nil then return end
	local relative_path = M.path_get_relative_buffer()
	local output = M.positional_set_path(register, relative_path)
	if output then vim.notify('set positional harp ' .. register) end
end

--- Get the search pattern of a register in the section, that is relative to `path`
---@param register string
---@param path string path to the file, that becomes a part of the section name.
---@return string? pattern `nil` if section doesn't exist.
function M.perbuffer_search_get_pattern(register, path)
	local result = shell({ 'harp', 'get', 'local_search_' .. path, register, '--path' })
	if result.code == 0 then
		return result.stdout
	else
		return nil
	end
end

--- Get a character from the user, and consider it the register;
--- Search for the pattern stored in the register, that is in a section that's relative to the current buffer.
--- If the register / section is empty, displays an error message.
---@param assume boolean? if the pattern ends with `/e` or `?e`, set the `at_end` flag automatically (and remove the).
---@param from_start boolean? search from the start of the buffer, rather than from the current cursor position. this will move you to the start of the file, regardless of whether the pattern matches (but won't if the register / section doesn't exist). this is useful for when you want to use search harps as smarter local marks, rather than as registers for search patterns.
---@param restore boolean? after using the search pattern, restore the previous one. say you searched for 'alisa', then used a search harp. with the flag off, when you press `n`, you would continue searching for the pattern in the search harp. with this flag on, you would continue searching for 'alisa'.
---@param backwards boolean? specify `true` to search backwards, instead of forwards. you don't have to pass this argument at all, if you want to search forwards (in other words, it's the default behavior).
---@param at_end boolean? when searching, put the cursor at the end of the match, rather than at the start. this is like using the `/e` / `?e` search offset (:h search-offset / https://youtu.be/GP722zVGYAk for a tutorial on them)
function M.perbuffer_search_get(assume, from_start, restore, backwards, at_end)
	local register = M.get_char('get local search harp: ')
	if register == nil then return end
	local cur_buf_path = M.path_get_full_buffer()
	local pattern = M.perbuffer_search_get_pattern(register, cur_buf_path)
	if pattern then
		local flags = ''
		if backwards then flags = flags .. 'b' end

		function ends_with(string, substring) return string:sub(-#substring + 1) == substring end
		local search_offset = (assume and (ends_with(pattern, '/e') or ends_with(pattern, '?e')))
		if search_offset then
			local function trim_offset(string) return string:sub(1, -3) end
			pattern = trim_offset(pattern)
		end

		if at_end or search_offset then flags = flags .. 'e' end

		local prev_search = nil
		if restore then prev_search = vim.fn.getreg('/') end
		if from_start then vim.fn.cursor(0, 0) end
		vim.fn.search(pattern, flags)
		if restore then vim.fn.setreg('/', prev_search) end
	end
end

--- Set the pattern in a register, that's in a section relative to the `path`
--- In other words, a search harp.
---@param register string
---@param path string the file path ends up being part of the name of a new section.
---@param pattern string a vim pattern, that you would use in `/` or `:s` etc. it is later used in vim.fn.search(), so take that into account when adding patterns using this function.
---@return boolean success
function M.perbuffer_search_set_pattern(register, path, pattern)
	return shell({ 'harp', 'update', 'local_search_' .. path, register, '--path', pattern }).code == 0
end

--- Get a character from the user, and consider it the register;
--- Set the path property of the register, to be the last search pattern (it's stored in your `/` vim register)
--- The section that the register is in is created by concatenating `local_search_` with the buffer path.
--- So the section name ends up looking something like `local_search_~/prog/dotfiles/colors.css`
--- The buffer path is gotten by calling `require('harp').path_get_full_buffer()`
function M.perbuffer_search_set()
	local register = M.get_char('set local search harp: ')
	if register == nil then return end
	local path = M.path_get_full_buffer()
	local pattern = vim.fn.getreg('/')
	local success = M.perbuffer_search_set_pattern(register, path, pattern)
	if success then vim.notify('set local search harp ' .. register) end
end

function M.setup()
	if vim.fn.executable('harp') ~= 1 then
		vim.notify('harp-nvim: harp was not found in your path', 2) -- this *should* display as an ERROR
		return
	end
end

return M