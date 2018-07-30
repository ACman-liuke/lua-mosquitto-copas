local topas = require("topas")
local rttask = require("rttask")
local hctask = require("hctask")
local connlinda = topas.lanes.linda()

local function main()
	local rtr = topas.run(connlinda, rttask.routine)
	local htr = topas.run(connlinda, hctask.routine)
	-- while true do
	-- 	local k, v, err = connlinda:receive(5, "rtr") assert(k)
	-- 	local k, v, err = connlinda:receive(10, "htr") assert(k)
	-- end
	rtr:join()
	htr:join()
end


main()
