local copas = require("copas")
local rrqueue = require("rrqueue")

local pipe_id, pipe_size, pipe_pool = 0, 5, {}
local queue = rrqueue.new(pipe_size)
for i = 1, pipe_size do
	queue:push(i)
end

-- print("load new_pipe size:",queue, queue:size())
-- local function display()
-- 	for id, pipe in pairs(pipe_pool) do
-- 		print("display:",id, pipe)
-- 	end
-- end

local pipe_timeout = {nil, "timeout"}
local pipe_method = {}
local pipe_mt = {__index = pipe_method}


function pipe_method:write(data)
	if not self.active then
		return nil, "close"
	end

	self.data = data
end

function pipe_method:read()
	if not self.active then
		return nil, "close"
	end

	while self.active and (not self.data) do
		if self.timeout < socket.gettime() then
			self:write(pipe_timeout)
			break
		end
		copas.sleep(0.1)
	end
	return self.data
end

function pipe_method:get_id()
	return self.pipe_id
end

function pipe_method:close()
	pipe_pool[self.pipe_id] = nil
	queue:push(self.pipe_id)
	self.active, self.timeout, self.pipe_id, self.data = nil, nil, nil, nil
end

local function on_message(map)
	if not (map and map.seq and map.pld) then		
		return nil, "invalid message"
	end

	local pipe = pipe_pool[map.seq]
	if not pipe then
		return nil, "miss pipe"
	end
	print("pipe on_message:", map.pld)
	pipe:write({map.pld})
end

local function new_pipe(timeout)
	local id, err =  queue:pop()
	if not id then
		return nil, err
	end
	local pipe = {timeout = (timeout or 1) + socket.gettime(), pipe_id = id, active = true}
	setmetatable(pipe, pipe_mt)
	pipe_pool[pipe.pipe_id] = pipe
	return pipe
end


local function pipe_list()
	return pipe_pool
end

return {
	new_pipe = new_pipe,
	on_message = on_message,
	display = display,
	pipe_list = pipe_list,
}