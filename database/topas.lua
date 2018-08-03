
local lanes = require("lanes").configure({ demote_full_userdata= true})

local thread_method = {}
local thread_mt = {__index = thread_method}


function thread_method:run()
	return self.inst(self.linda, self.args)
end

--一般用于等待/关注线程返回结果的场景
function thread_method:join(...)
	return self.inst:join(...)
end

local function new_thread(connlinda, handler, ...)
	print("lanes:", lanes)
	local thread = {
		args = {...},
		linda = connlinda,
		--inst = lanes.gen("*", {required = {"copas"}, globals = {modules = modules}}, handler),
		inst = lanes.gen("*", handler),
	}
	setmetatable(thread, thread_mt)
	return thread
end

local function run(f, ...)
	local thread = new_thread(f, ...):run()
	return thread
end

local topas = {
	run	= run,
	lanes = lanes,
}



return topas
