--[[
	Note:
	1.线程创建：由lanes创建/启动的线程是真正意义上的线程，不是协程coroutine；
	2.不支持嵌套使用lanes:即通过lanes创建的线程，不可以再通过lanes创建线程；
	3.协程创建：协程coroutine由copas.addthread创建并自动执行；由lanes间接启用的协程需要require对应模块
	4.copas和lua-mosquitto分别采用独立的事件循环机制
	5.copas的缺陷： 没有socket+sleep事件 且 timeout= nil时，copas.step会卡死[select会卡死(block indefinitely)]
--]]

local fnil = function(pld, cmd, ip, port) print("unsupported", cmd)  return false, "unsupported cmd" end

local function fill_cmd_cb(modules, cmd_class, cmd, single)
	local cbs
	for _, mod in pairs(modules) do
		local f = mod[cmd_class]
		if f then
			local cb = f(cmd)
			if cb then
				print("add new cb for ", cmd, cb)
				assert(type(cb) == "function", "must be a function")
				if single then
					return cb --单例模式，直接返回首个cb
				end
				cbs = cbs or {}
				table.insert(cbs, cb)
			end
		end
	end
	return cbs
end



local function start_tcp_server()
	local js = require("cjson.safe")
	local copas = require("copas")
	local limit = require("copas.limit")
	local modport = require("modport")
	local new_req = require("tcp_request").new
	local log = require("nlog")

	local block_intval = 3 -- i/o block time


	local function error_handler(err, co, skt)
	 	print("tcp routine error: %s", err)
	 	log.fatal("tcp routine error: %s", err) 
	end
	-- coroutine发生错误时，统一由ErrorHandler处理
	copas.setErrorHandler(error_handler)

	local srv_port = modport.getport("acmgr")

	local modules = {
		dbevent = require("dbevent"),
		aclog 	= require("aclog"),
	}

	local handlers = {}
	local on_cmd = function(cmd)	
		if not handlers[cmd] then
			handlers[cmd] = fill_cmd_cb(modules, "dispatch_tcp", cmd, true) or fnil
		end
		return handlers[cmd]
	end


	local tcp_handler = function(skt)
		local dispatch = function(data)
			local m = js.decode(data)
			print("tcp dispatch:", data)
			if not (m and m.cmd and m.pld) then
				return {status = 1, data = "invalid cmd"}
			end
			local r, e = on_cmd(m.cmd)(m.pld, m.cmd)
			return r and {status = 0, data = r} or {status = 1, data = e}
		end

		skt = copas.wrap(skt)
		skt:settimeout(block_intval)
		new_req(skt, dispatch):run()
	end
	
	local server = socket.bind("127.0.0.1", srv_port or 0) assert(server)
	copas.addserver(server, tcp_handler)
	for name, mod in pairs(modules) do
		print(name, mod)
		local _ = mod.init and mod.init(nil, nil, server) 
	end
end

local function start_udp_server()
	local js = require("cjson.safe")
	local copas = require("copas")
	local limit = require("copas.limit")
	local modport = require("modport")
	local log = require("nlog")

	local function error_handler(err, co, skt)
	 	print("udp routine error: %s", err)
	 	log.fatal("udp routine error: %s", err) 
	end
	-- coroutine发生错误时，统一由ErrorHandler处理
	copas.setErrorHandler(error_handler)
	
	local srv_port = modport.getport("acmgr")
	-- local limitset = limit.new(50)

	local modules = {
		dbevent = require("dbevent"),
		aclog 	= require("aclog"),
	}

	local handlers = {}
	local on_cmd = function(cmd)	
		if not handlers[cmd] then
			handlers[cmd] = fill_cmd_cb(modules, "dispatch_udp", cmd, true) or fnil
		end
		return handlers[cmd]
	end

	local udp_handler = function(skt)
		local skt = copas.wrap(skt)
		while true do
			local r, ip, port  = skt:receivefrom()
			if r and ip and port then
				local m = js.decode(r)
				if m and m.cmd and m.pld then
					--on_cmd(m.cmd)(m.pld, m.cmd, skt, ip, port)
					local f = on_cmd(m.cmd)
					copas.addthread(f, m.pld, m.cmd, skt, ip, port)
				end
			end
		end
	end

	local server = socket.udp()
	local r, e = server:setsockname("127.0.0.1" , srv_port)
	if not r then
		return r, e
	end

	copas.addserver(server, udp_handler)
	for name, mod in pairs(modules) do
		local _ = mod.init and mod.init(nil, server, nil) 
	end
end


local function start_mqtt_client()	
	local unique = "a/ac/acmgr"
	local copas = require("copas")
	local limit = require("copas.limit")
	local mqtt = require("mqttproxy")
	local log = require("nlog")
	local js = require("cjson.safe")

	local limitset = limit.new(10)

	local modules = {
		dbevent = require("dbevent"),
		aclog 	= require("aclog"),
	}

	-- local function error_handler(err, co, skt)
	--  	print("mqtt routine error: %s", err)
	--  	log.fatal("mqtt routine error: %s", err) 
	-- end
	-- -- coroutine发生错误时，统一由ErrorHandler处理
	-- copas.setErrorHandler(error_handler)
	local handlers = {} -- 同一个mqtt cmd 支持多个模块处理
	local on_cmd = function(cmd)	
		if not handlers[cmd] then
			handlers[cmd] = fill_cmd_cb(modules, "dispatch_mqtt", cmd, false) or {fnil}
		end
		return handlers[cmd]
	end

	-- payload = {cmd =xxx, pld = xxx}
	local on_message = function(topic, payload)
		local map = js.decode(payload)
		if not (map and map.cmd and map.pld) then
			return
		end
		local funcs = on_cmd(map.cmd)
		for _, f in ipairs(funcs) do
			--local thread = limitset:addthread(f, pld, map.cmd) -- 参数cmd用于fnil打印信息之用
			copas.addthread(f, map.pld, map.cmd) -- 参数cmd用于fnil打印信息之用
			--f(map.pld, map.cmd)
		end
	end

	local args = {
		log = log,
		unique = unique,
		echo_topic = unique.."_echo", -- 用于消息回复
		sub_topics = {echo_topic, unique},
		on_message = on_message,
		on_disconnect = function(res, rc, err) log.fatal("disconnect %s %s", rc, err) end,
		conn = {host = "192.168.1.210", port = 5555, keepalive = 1},
		auth = {username = nil, passwd = nil},
		will = {topic = nil, payload = nil},
	}

	local mqtt_cli, err = mqtt.run_new(args, function(mqtt_cli)
			for name, mod in pairs(modules) do
				local _ = mod.init and mod.init(mqtt_cli) 
			end
		end) assert(mqtt_cli, err)
end

local function loop_check_debug()
	local nfs = require("nfs")
	local log = require("nlog")
	local copas = require("copas")

	local path = "/tmp/debug_acmgr"
	while true do
		if nfs.stat(path) then
			local s = read(path), fs.unlink(path)
			local _ = (#s == 0 and log.real_stop or log.real_start)(s)
		end
		copas.sleep(5)
	end
end

local function keepalive_lanes(connlinda)
	local copas = require("copas")
	while true do
		print("send rtr")
		connlinda:send("rtr", "rtr-value")
		copas.sleep(1)
	end
end

local function task_routine(connlinda, ...)
	local copas = require("copas")
	local loop_intval = 0.01 -- 主事件循环间隔（秒）
	copas.autoclose = false -- 关闭tcp连接自动关闭机制

	copas.addthread(start_tcp_server)
	copas.addthread(start_udp_server)
	copas.addthread(loop_check_debug)
	copas.addthread(start_mqtt_client)
	-- copas.addthread(keepalive_lanes, connlinda)
	
	copas.loop(0.01)
end


return {
	routine = task_routine,
}
