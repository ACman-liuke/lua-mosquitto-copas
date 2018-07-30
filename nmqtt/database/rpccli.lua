local js = require("cjson.safe")

local strip = false
local method = {}
local mt = {__index = method}

-- 第一次不发送代码，对端可能有缓存（减少通信量，注意，调试时，需要清理缓存 - 重启database）
-- 第一次miss后，再次发生代码
function method:fetch(name, f, arg)
	assert(name and type(f) == "string")
	local data = {cmd = "rpc", k = name, p = arg} 		
	local r, e = self.proxy:query(self.topic, data)
	if e then
		return nil, e
	end

	local r, e = js.decode(r)
	if not r then
		return nil, e
	end

	if not r.e then
		return r.d
	end

	if r.d ~= "miss" then
		return nil, r.d
	end

	local data = {cmd = "rpc", k = name, p = arg, f = f}
	local r, e = self.proxy:query(self.topic, data)
	if e then
		return nil, e
	end

	local r, e = js.decode(r)
	if not r then
		return nil, e
	end

	if not r.e then
		return r.d
	end

	return nil, r.d
end

--simplesql的arg三个参数 param, isexec(execute or select), memo

function method:once(f, arg, timeout) 			--f是function, arg是参数 -isshe
	assert(type(f) == "string")
	local data = {cmd = "rpc", p = arg, f = f, r = 1} --r表示需要回复
	local r, e = self.proxy:query(self.topic, data, timeout)
	if e then
		return nil, e
	end

	local r, e = js.decode(r)
	if not r then
		return nil, e
	end

	if not r.e then
		return r.d
	end

	return nil, r.d
end

function method:exec(f, arg)
	assert(type(bt) == "string")
	local data = {pld = {cmd = "rpc", p = arg, f = f}} -- -- 不需要回复
	self.proxy:publish(self.topic, js.encode(data))
	return true
end

local function new(proxy, topic)
	local obj = {proxy = proxy, cache = {}, topic = topic}
	setmetatable(obj, mt)
	return obj
end

return {new = new}
