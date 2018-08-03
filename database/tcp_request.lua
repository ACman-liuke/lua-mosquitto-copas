local copas = require("copas")
local js = require("cjson.safe")

local client_method = {}
local client_mt = {__index = client_method}

copas.autoclose = false

function client_method:reply_close(un)
	local cli = self.cli
	if un then
		local s = type(un) == "table" and js.encode(un) or un
		cli:send(#s .. "\r\n" .. s)
	end

	cli:close()
	self.cli = nil
end

function client_method:readlen()
	local cli = self.cli
	local l, e = cli:receive("*l")

	if not l then
		return nil, e
	end
	return tonumber(l)
end

function client_method:readdata(expect)
	local cli, s = self.cli
	local s, e = cli:receive(expect)
	if not s then
		return nil, e
	end

	return s
end

function client_method:handle()
	local len, e = self:readlen()
	if not len then
		print("fetch len failed ", e)
		return self:reply_close({e = 1, d = e})
	end

	local data, e = self:readdata(len)

	if not data then
		print("fetch len failed ", err)
		return self:reply_close({e = 1, d = e})
	end

	self:reply_close(self.cb(data))
end

function client_method:run()
	return self:handle()
end

local function new_client(cli, cb)
	local obj = {cli = cli, cb = cb, buff = ""}
	setmetatable(obj, client_mt)
	return obj
end

return {new =  new_client}