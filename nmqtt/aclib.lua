--[[
	author:tgb
	date:2016-08-25 1.0 add basic code
]]


local function gen_dispatch_tcp(tcp_map)
	return function(cmd)
		return tcp_map[cmd]
	end
	
end

local function gen_dispatch_udp(udp_map)
	return function(cmd)
		return udp_map[cmd]
	end


end

local function gen_dispatch_mqtt(mqtt_map)
	return function(cmd)
		return mqtt_map[cmd]
	end

end

return {
	gen_dispatch_tcp	= gen_dispatch_tcp,
	gen_dispatch_udp	= gen_dispatch_udp,
	gen_dispatch_mqtt	= gen_dispatch_mqtt,
}
