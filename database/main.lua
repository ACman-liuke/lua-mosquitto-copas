--[[
	author: liuke
	date : 2018-08-02 20:52
]]

local topas = require("topas")
local rttask = require("rttask")
local connlinda = topas.lanes.linda()

local function main()
	local rtr = topas.run(connlinda, rttask.routine)
	rtr:join()
end

main()