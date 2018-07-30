--[[
	author:tgb
	date:2016-08-25 1.0 add basic code
]]
local fp = require("fp")
local js = require("cjson.safe")
local log = require("nlog")
local queue = require("queue")
local aclib = require("aclib")
local copas = require("copas")

-- local rpccli 	= require("rpccli")
-- local simplesql = require("simplesql")

local reduce		
local ctrl_path 	= "/tmp/memfile/ctrllog.json"
local audit_path 	= "/tmp/memfile/auditlog.json"
local log_limit, ctrl_log,  audit_log = 300

-- fixme:a temporary method
local set_name_adapter = {
	MACWHITELIST	= "access_white_mac",
	IPWHITELIST		= "access_white_ip",
	MACBLACKLIST	= "access_black_mac",
	IPBLACKLIST		= "access_black_ip",
}

local mqtt, dbrpc, udpsrv
local first_init = true

--[[
	proto_map:{"3057439406"= proto_name /*b63cd2ae hex*/};
	rule_map:
	set_map:
]]
local proto_map, rule_map, set_map = {}, {}, {}

-- cmd map
local tcp_map, udp_map, mqtt_map = {}, {}, {}

local function log_limit_init()
	local memory = os.execute(" grep MemTotal /proc/meminfo |awk '{print $2}'")
	if not memory then
		return
	end

	local n = tonumber(memory)
	if not (n and type(n) == "number") then
		return
	end

	if n >= 1048576 then log_limit = 3000 return end
	if n >= 524288 then log_limit = 1500 return end
	if n >= 262144 then log_limit = 800 return end
	log_limit = 300

	return
end

-- cmd from webui
tcp_map["ctrllog_get"] = function (p, ip, port)
	print("ctrllog_get...")
	return  "resp from tcpsrv"..js.encode(p)
	-- local page, count, res = p.page, p.count, {}	assert(count > 0)
	-- local idx = page > 1 and ((page - 1) * count + 1)  or 1	assert(idx > 0)
	-- -- if not ctrl_log then
	-- -- 		ctrl_log = queue.new(ctrl_path, log_limit)
	-- -- end
	-- local arr = ctrl_log:all()	assert(arr)
	-- count = log_limit
	-- if idx <= #arr then
	-- 	local left = #arr - idx + 1
	-- 	local count = (count > left and left) or count
	-- 	count = count - 1

	-- 	for i = 0, count do
	-- 		table.insert(res, arr[i + idx])
	-- 	end
	-- end

	-- return res
end

-- cmd from ntrackd
udp_map["aclog_add"] = function(p,cmd, skt, ip, port)
   print("resp:", copas.sendto(skt, "response from srv", ip, port))
	-- local rulename, protoname
	-- if p.subtype == "RULE" then
	-- 	rulename = rule_map[tostring(p.rule.rule_id)] or "unknow rule"
	-- 	protoname = proto_map[tostring(p.rule.proto_id)] or "unknow proto"
	-- else
	-- 	local set_info = set_map[set_name_adapter[p.rule.set_name]]
	-- 	rulename = set_info and set_info.setdesc or "unknown"
	-- 	protoname = set_info and set_info.settype or "unknow"
	-- end

	-- local aclog = {
	-- 	user		= {ip = p.user.ip, mac = p.user.mac},
	-- 	rulename	= rulename,
	-- 	protoname	= protoname,
	-- 	tm			= os.date("%Y-%m-%d %H:%M:%S"),
	-- 	actions		= p.actions,
	-- 	--ext			= {flow = p.flow}
	-- 	hits		= p.hits
	-- }
	-- -- if not audit_log then
	-- -- 	audit_log = queue.new(audit_path, log_limit)
	-- -- end

	-- -- if not ctrl_log then
	-- -- 	ctrl_log = queue.new(ctrl_path, log_limit)
	-- -- end


	-- if p.ruletype == "CONTROL" then
	-- 	ctrl_log:push(aclog)
	-- 	ctrl_log:save()
	-- else
	-- 	audit_log:push(aclog)
	-- 	audit_log:save()
	-- end
	-- print("resp:", copas.send(skt, "response from srv"))
	return true
end

local function fetch_proto_map()
	-- local sql = string.format("select proto_id, proto_name from acproto where node_type = 'leaf'")
	-- local protos, err = simple:mysql_select(sql)
	-- local _ = protos or log.fatal("fetch proto ids failed:%s", err)

	-- proto_map = reduce(protos, function(t, r)
	-- 	return rawset(t, tostring(tonumber(r.proto_id, 16)), r.proto_name)
	-- end, {})

	-- local _ = log.real_enable() and log.real1("new proto map:%s", js.encode(proto_map))
end

local function fetch_rule_map()
	-- local sql = "select rulename, ruleid from acrule"
	-- local rules, err = simple:mysql_select(sql)
	-- local _ = rules or log.fatal("fetch rules failed:%s", err)

	-- rule_map = reduce(rules, function(t,r)
	-- 	return rawset(t, tostring(r.ruleid), r.rulename)
	-- end, {})

	-- local _ = log.real_enable() and log.real1("new rule map:%s", js.encode(rule_map))
end

local function fetch_set_map()
	-- local sql = "select setname, setdesc, settype from acset"
	-- local sets, err = simple:mysql_select(sql)
	-- local _ = sets or log.fatal("fetch sets failed:%s", err)

	-- set_map = reduce(sets, function(t,r)
	-- 	return rawset(t, r.setname, {setdesc = r.setdesc, settype = r.settype})
	-- end, {})

	-- local _ = log.real_enable() and log.real1("new set map:%s", js.encode(set_map))
end

-- cmd from mqtt
mqtt_map["mqtt_topic1"] = function(p)
	print("mqtt_topic1 in aclog:",socket.gettime(), js.encode(p))
	
	return true
end

mqtt_map["mqtt_topic2"] = function(p)
	print("mqtt_topic2 in aclog:",js.encode(p))
	
	return true
end

local function init(mq, udp, rpc)

	if not mqtt and mq then
		mqtt = mq
	end

	if not udpsrv and udp then
		udpsrv = udp
	end

	if not dbrpc and rpc then
		dbrpc = rpc
	end

	if first_init then
		first_init =  false
	else
		return
	end

 print("udp_map.aclog_add:", udp_map["aclog_add"])


	-- log_limit_init()
	ctrl_log = queue.new(ctrl_path, log_limit)
	audit_log = queue.new(audit_path, log_limit)
	-- dbrpc = rpccli.new(mqtt, "a/ac/database_srv")
	-- simple = simplesql.new(dbrpc)

	-- fetch_proto_map()
	-- fetch_set_map()
	-- fetch_rule_map()

end


return {
	init			= init,
	dispatch_tcp	= aclib.gen_dispatch_tcp(tcp_map),
	dispatch_udp	= aclib.gen_dispatch_udp(udp_map),
	dispatch_mqtt	= aclib.gen_dispatch_mqtt(mqtt_map),
}

-- dispath_tcp = function(cmd)
-- 	return tcp_map[cmd]
-- end