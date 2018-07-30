-- reference http://luaposix.github.io/luaposix
local unistd = require("posix.unistd")
local fcntl = require("posix.fcntl")
local sys_stat = require("posix.sys.stat")
local stdio = require("posix.stdio")
local bit = require("bit")


local function open(path, flags, mode)
	local fd, err = fcntl.open(path, flags, mode)
	if not fd then
		return nil, "open failed"
	end
	return fd
end

local function stat(path)
	local map = sys_stat.stat(path)
	if type(map) ~= "table" then
		return nil, map
	end
	return map
end

-- mode = [r,w,x,f];f means existence test
local function access(path, mode)
	local r, e = unistd.access(path, mode or "f")
	if not r then
		return nil, e
	end

	return r
end

local function rmdir(dir)
	local r, e = unistd.rmdir(dir)
	if not r then
		return nil, e
	end

	return r
end

local function mkdir(dir, mode)
	local r, err = sys_stat.mkdir(dir, mode or 511)
	if not r then
		return nil, err
	end

	return r
end

local function unlink(path)
	local r, e = unistd.unlink(path)
	if not r then
		return nil, e
	end

	return r
end

local function rename(old, new)
	local r, e = stdio.rename(old, new)
	if not r then
		return nil, e
	end
	return r
end

local function readfile(path)
	local fd, e = open(path, fcntl.O_RDONLY)
	if not fd then
		return nil, e
	end

	local content, rerr = nil, nil

	while true do
		local r, err, errno = unistd.read(fd, 4096)
		rerr = err
		if not (r and #r > 0) then
			break
		end
		content = content or {}
		table.insert(content, r)
	end

	 unistd.close(fd)

	 if not content then
	 	return nil, rerr
	 end

	 return table.concat(content)
end

local function writefile(path, data)
	local fd, e = open(path, bit.bor(fcntl.O_CREAT, fcntl.O_RDWR))
	if not fd then
		return nil, e
	end

	local r, e = unistd.write(fd, data)
	if not r then
		return nil, e
	end

	local r, e = unistd.close(fd)
	if not r then
		return nil, e
	end

	return rc
end


local function writefile_safe(path, data)
	local tmp = path .. ".tmp"
	local r, e = writefile(tmp, data)
	if e then
		return nil, e
	end

	return rename(tmp, path)
end

return {
	open = open,
	stat = stat,
	access = access,
	scandir = scandir,
	rmdir = rmdir,
	mkdir = mkdir,
	unlink = unlink,
	rename = rename,
	readfile = readfile,
	writefile = writefile,
	writefile_safe = writefile_safe,
}