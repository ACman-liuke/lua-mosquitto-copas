local log = require("log")
local copas = require("copas")
local mqtt = require("mosquitto")
local npipe = require("npipe")
local js = require("cjson.safe")

local function numb()  end

local method = {}
local mt = {__index = method}

function method:login_set(username, passwd) 
	if username and passwd then
		return self.mqtt:login_set(username, passwd) 
	end
	return false, "invalid login pars"
end

function method:will_set(topic, payload, qos, retain)
	if topic and payload then
		return self.mqtt:will_set(topic, payload, qos, retain)
	end
	return true
end

function method:will_clear()
	return self.mqtt:will_clear()
end

function method:connect(host, port, keepalive) 
	if host and port then
		return self.mqtt:connect(host, port, keepalive or 60) 
	end
	return nil, "invalid connect pars"
end

-- function method:on_connect(func) return  end
-- function method:reconnect(...) return end
-- function method:disconnect() return  end
function method:on_disconnect(cb) self.on_disconnect = cb end

function method:publish(...) return self.mqtt:publish(...) end

function method:subscribe(sub_topics) 
	for _, topic in pairs(sub_topics) do
		local r, errno, strerr = self.mqtt:subscribe(topic) 
	end
end

-- function method:on_subscribe() return end

function method:unsubscribe(topics) 
	for _, topic in pairs(topics) do
		self.mqtt:unsubscribe(topic) 
	end
end

-- function method:on_unsubscrible(func) end

function method:loop() return self.mqtt:loop() end
function method:loop_forever() return self.mqtt:loop_forever() end

function method:on_message(cb) self.on_message = cb end
function method:proxy_topic_set(t) self.proxy_topic = t end


function method:query(topic, data, timeout)
	local pipe, err = npipe.new_pipe(timeout)
	if not pipe then
		return nil, err
	end

	local qwrap = { 
		seq = pipe:get_id(), 
		pld = data, 
		mod = self.echo_topic,
	}

	local s = js.encode(qwrap)
	local r, e =  self.mqtt:publish(topic, s)
	local r, e = pipe:read()	 						
	pipe:close()
	return r[1], r[2]
end

function method:query_r(topic, data, timeout)
	local pipe, err = npipe.new_pipe(timeout)
	if not pipe then
		return nil, err
	end

	local qwrap_r = {
		out_topic = topic,
		data = {mod = self.echo_topic, seq = pipe:get_id(), pld = data}
	}

	local s = js.encode(qwrap_r)
	local ret, err = self.mqtt:publish(self.proxy_topic, s)	 	
	local r, e = pipe:read()		 								
	pipe:close()
	return r[1], r[2]
end

function method:query_log(topic, data, timeout)
	local pipe, err = npipe.new_pipe(timeout)
	if not pipe then
		return nil, err
	end

	local qwrap_log = {
		mod = topic,
		pld = {cmd = topic, seq = pipe:get_id(),  pld = {cmd = "getlog", data = {seq = seq, mod = self.echo_topic, type = "current"}}},
	}

	local s = js.encode(qwrap_log)
	local r, e = self.mqtt:publish("a/ap/" .. data.devid, s)		
	local r, e = pipe:read()		 								
	pipe:close()
	if type(r[1]) == "string" then
		local len = string.len(r[1])
		if len >  4096 then
			r[1] = string.sub(r[1], len - 4096, -1)
		end
	end
	return r[1], r[2]
end

function method:publish_r(topic, data)
	local s = js.encode({out_topic = topic, data = {pld = data}})
	return self.mqtt:publish(self.proxy_topic, s)
end

function method:run()
	 copas.addthread(function() 
		--copas.step(0.1) -- 触发一次调度
		while true do
			self.mqtt:loop(10)
			copas.step(0.01)  --没有socket事件 且 timeout= nil时，select会卡死(block indefinitely)			
		end
	end)
end



local function numb()  end

local function new_mqtt(map, cb)
	local mqtt_cli = mqtt.new()
	if not mqtt_cli then
		return nil, "create mqtt client failed"
	end

	local obj = {
		mqtt = mqtt_cli,
		echo_topic = map.echo_topic, -- 用于消息回复
		on_message = map.on_message,
		on_disconnect = map.on_disconnect,
	}

	cb(mqtt_cli)

	local mqtt_on_message = function(mid, topic, payload, qos, retain)
		if topic ~= obj.echo_topic then
			return obj.on_message(topic, payload)
		end

		local map = js.decode(payload)
		if not (map and map.seq and map.pld) then
			return obj.on_message(topic, payload)
		end

		npipe.on_message(map)
	end

	local _ = obj.on_message and mqtt_cli:callback_set("ON_MESSAGE", mqtt_on_message)

	local _ = obj.on_disconnect and mqtt_cli:callback_set("ON_DISCONNECT", obj.on_disconnect)

	setmetatable(obj, mt)
	return obj
end

-- mqttproxy参数
-- local args = {
-- 	log = log,
-- 	unique = unique,
-- 	echo_topic = unique, -- 用于消息回复
-- 	sub_topics = {echo_topic, "a/ac/database_sync"},
-- 	on_message = on_message,
-- 	on_disconnect = function(res, rc, err) log.fatal("disconnect %d %s %s", res, rc, err) end,
-- 	conn = {host = "192.168.1.210", port = 5555, keepalive = 5}
-- 	auth = {username = nil, passwd = nil},
-- 	will = {topic = nil, payload = nil},
-- }

local function run_new(map, cb)
	assert(map and map.log and map.on_message and map.on_disconnect)
	
	local proxy = new_mqtt(map, cb)
	
	proxy:login_set(map.auth.username, map.auth.passwd)
	proxy:will_set(map.will.topic, map.will.payload)
	local r, e = proxy:connect(map.conn.host or "localhost", map.conn.port or "61886", map.conn.keepalive or 60) 
	-- local _ = r or map.log.fatal("connect fail %s", e)
	proxy:subscribe(map.sub_topics)
	proxy:run()
	return proxy
end

return {run_new = run_new}
