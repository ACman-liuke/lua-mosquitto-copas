local function do_loop()
	local copas = require("copas")
	local count = 0
	while true do
		count = count + 1
		print("hvloop:", count)
		copas.sleep(1)
	end
end

local function do_loop_ext()
	local copas = require("copas")
	local count = 0
	while true do
		count = count + 1
		print("loop ext:", count)
		copas.sleep(2)
	end
end


local function heavy_ext_routine()
	local copas = require("copas")
	copas.addthread(do_loop_ext)
	copas.loop()
end

local function keepalive_lanes(connlinda)
	local copas = require("copas")
	while true do
		print("send htr")
		connlinda:send("htr", "htr-value")
		copas.sleep(1)
	end
end

local function task_routine(connlinda, ...)
	--local topas = require("topas")
	local copas = require("copas")
	copas.setErrorHandler(function() print("-----task routine") os.exit(-1) end)

	--local extr = topas.run(heavy_ext_routine)
	copas.addthread(do_loop)
	--copas.addthread(keepalive_lanes, connlinda)
	copas.loop()
	--extr:join()
end

return {routine = task_routine}
