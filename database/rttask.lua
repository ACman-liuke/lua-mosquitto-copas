--[[
	Note:
	1.线程创建：由lanes创建/启动的线程是真正意义上的线程，不是协程coroutine；
	2.不支持嵌套使用lanes:即通过lanes创建的线程，不可以再通过lanes创建线程；
	3.协程创建：协程coroutine由copas.addthread创建并自动执行；由lanes间接启用的协程需要require对应模块
	4.copas和lua-mosquitto分别采用独立的事件循环机制
	5.copas的缺陷： 没有socket+sleep事件 且 timeout= nil时，copas.step会卡死[select会卡死(block indefinitely)]
--]]

local cmd_map = {}
function cmd_map.rpc(cmd, ctx)
	local log = require("nlog")
	local bklock = require("bklock")
	local sync = require("sync")

	-- try best to get lock in 10 seconds
	-- will write:disk.db + log.bin
	if not bklock.lock() then
		log.error("get lock failed for timeout")
		return
	end

	local r = dbrpc:execute(cmd)
	local change = sync.sync()
	bklock.unlock()

	local _ = r and proxy:publish(ctx.mod, js.encode({seq = ctx.seq, pld = r}))
end

local function start_mqtt_client()
	local unique = "a/ac/acmgr"
	local copas = require("copas")
	local limit = require("copas.limit")
	local mqtt = require("mqttproxy")
	local log = require("nlog")
	local js = require("cjson.safe")

	local limitset = limit.new(10)

	local handlers = {} -- 同一个mqtt cmd 支持多个模块处理
	local on_cmd = function(cmd)
		if not handlers[cmd] then
			handlers[cmd] = cmd_map[cmd] or {fnil}
		end
		return handlers[cmd]
	end

	-- payload = {cmd =xxx, pld = xxx}
	local on_message = function(topic, payload)
		local map = js.decode(payload)
		if not (map and map.cmd and map.pld) then
			return
		end
		local func = on_cmd(map.cmd)
		copas.addthread(func, map.pld, map)
	end

	local args = {
		log = log,
		unique = unique,
		echo_topic = unique.."_echo", -- 用于消息回复
		sub_topics = {echo_topic, unique},
		on_message = on_message,
		on_disconnect = function(res, rc, err) log.fatal("disconnect %s %s", rc, err) end,
		conn = {host = nil, port = nil, keepalive = 1},
		auth = {username = nil, passwd = nil},
		will = {topic = nil, payload = nil},
	}

	local mqtt_cli, err = mqtt.run_new(args, function(mqtt_cli)
		end) assert(mqtt_cli, err)
end

local function loop_check_debug()
	local nfs = require("nfs")
	local log = require("nlog")
	local copas = require("copas")

	local path = "/tmp/debug_database"
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

local function init_config()
	local log = require("nlog")
	local config = require("config")

	local cfg, err = config.ins()
	local _ = cfg or log.fatal("load config fail %s", err)
	return cfg
end

local function connect_mysql()
	local mysql = require("mysql")
	local db = mysql.new()
	local r, e = db:connect({}) 		assert(r, e)
   	return db
end

local function database_init()
	local mgr = require("mgr")
	local sync = require("sync")
	local dc = require("dbcommon")
	local config = require("config")
	local rpcserv = require("rpcserv")
	local updatelog = require("updatelog")

	local cfg = init_config()
	local ud = updatelog.new(cfg)
	ud:prepare()
	local conn = dc.new(cfg:get_workdb(), {{path = cfg:get_memodb(), alias = "memo"}})
	local myconn = connect_mysql()
	mgr.new(conn, myconn, ud, cfg)

	local change = sync.sync()

	dbrpc = rpcserv.new(proxy)
	-- nta.set_conn(conn)
	-- nta.set_ud(ud)
	-- nta.update_ops()
end

local function task_routine(connlinda, ...)
	local copas = require("copas")
	local loop_intval = 0.01 -- 主事件循环间隔（秒）
	copas.autoclose = false -- 关闭tcp连接自动关闭机制

	copas.addthread(loop_check_debug)
	copas.addthread(start_mqtt_client)
	-- copas.addthread(database_init)

	copas.loop(loop_intval)
end

return {
	routine = task_routine,
}
