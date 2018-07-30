local pipe = require("npipe")
local copas = require("copas")

local function query()
	local pipe, err = pipe.new_pipe(5)
	if not pipe then
		return nil, err
	end
	print("new pipe:", pipe:read())
	pipe:close()
end

local function pipe_routine()
	for id = 1,10 do
		copas.addthread(query)
		pipe.display()
		copas.sleep(0.5)
	end
end

local function pipe_message()
	local count = 0
	while true do
		
		for id, pipe in pairs(pipe.pipe_list()) do
			if pipe.timeout < socket.gettime() and id > 1 and id%2 == 0 then
				pipe:write({true, string.format("test%d", id)})
			end
		end
	copas.sleep(0.5)
	end
end


local function main( ... )
	--copas.addthread(pipe_gc_routine)
	copas.addthread(pipe_message)
	copas.addthread(pipe_routine)
	copas.loop()
end


main()