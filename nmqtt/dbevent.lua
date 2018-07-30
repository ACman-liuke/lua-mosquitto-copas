local log = require("nlog")
local js = require("cjson.safe")
local aclib = require("aclib")

local mqtt_map = {}
local on_event_cb

local function init(mqtt, udpsrv, dbsrv)
end

mqtt_map["mqtt_topic1"] = function(p)
	print("mqtt_topic1 in dbevnet:",js.encode(p))
	return true
end

mqtt_map["mqtt_topic2"] = function(p)
	print("mqtt_topic2 in dbevnet:",js.encode(p))
	return true
end

return {init = init, dispatch_mqtt = aclib.gen_dispatch_mqtt(mqtt_map)}

