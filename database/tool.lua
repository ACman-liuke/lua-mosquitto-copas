local js = require("cjson.safe")
local rpccli = require("rpccli")
local simplesql = require("simplesql")
local mqttproxy = require("mqttproxy")

local function start_sand_server()
	local unique = "a/ac/dump_client"
	local numb = function(...)
		print(...)
	end
	local args = {
		log = 1,
		unique = unique,
		clitopic = {unique},
		on_message = numb,
		on_disconnect = numb,
		srvtopic = {unique .. "_srv"},
	}
	proxy = mqttproxy.run_new(args)
	return proxy
end

local function start_mqtt_client()
	local unique = "a/ac/dump_client"
	local copas = require("copas")
	local limit = require("copas.limit")
	local mqtt = require("mqttproxy")
	local log = require("nlog")
	local js = require("cjson.safe")

	local limitset = limit.new(10)

	-- payload = {cmd =xxx, pld = xxx}
	local on_message = function(...)
		print(...)
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
			for name, mod in pairs(modules) do
				local _ = mod.init and mod.init(mqtt_cli)
			end
		end) assert(mqtt_cli, err)

	return mqtt_cli
end

local function rpc()
	local dbrpc = rpccli.new(start_sand_server(), "a/ac/database_srv")
	return simplesql.new(dbrpc), dbrpc
end

local cmd_map = {}
function cmd_map.r(sql)
	assert(sql)
	local r = rpc():select2(sql)
	for i, v in ipairs(r) do print(i, js.encode(v)) end
end

function cmd_map.w(sql)
	assert(sql, "sql")
	rpc():execute2(sql)
end

function cmd_map.backup()
	local code = [[
		local ins = require("mgr").ins()
		ins.ud:backup()
		return true
	]]
	local _, dbrpc = rpc()
	local r, e = dbrpc:once(code)
	if e then io.stderr:write("error ", e, "\n") os.exit(-1) end
	print(r)
end

local function main(cmd, ...)
	cmd_map[cmd](...)
	os.exit(0)
end

main()
