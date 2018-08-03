#!/usr/bin/lua

package.path = "../?.lua;" .. package.path

local fp 	= require("fp")
local dc 	= require("dbcommon")
local common 	= require("common")
local js 		= require("cjson.safe")
local config 	= require("config")

local read, arr2map = common.read, common.arr2map
local shpath = "../db.sh"

local function fatal(fmt, ...)
	io.stderr:write(string.format(fmt, ...), "\n")
	os.exit(1)
end

local function backup_disk(cfg)
	local cmd = string.format("%s backup %s %s", shpath, cfg:disk_dir(), cfg:work_dir())
	local ret, err = os.execute(cmd)
	local _ = (ret == true or ret == 0) or fatal("backup_disk fail %s %s", cmd, err)
end

local cmd_map = {}

cmd_map.kv = {
	priority = 8,
	func = function(conn)
		local sql = string.format("select * from kv")
		local rs, e = conn:select(sql)
		local exist_map = {}
		for _, r in ipairs(rs) do
			exist_map[r.k] = r
		end

		local new_map = {
			{k = "username", v = "admin"},
			{k = "password", v = "admin"},
			{k = "timezone", v = "CST-8"},
			{k = "zonename", v = "Asia/Shanghai"},

			{k = "auth_bypass_dst", 	v = "{}"},
			{k = "auth_bypass_time",	v = "20"},
			{k = "auth_redirect_ip", 	v = "10.0.0.1"},
			{k = "cloud_bypass_dst",	v = "{}"},
			{k = "cloud_bypass_mac",	v = "{}"},
			{k = "cloud_ad_version",	v = "1970-01-01 00:00:00"},
			{k = "cloud_auth_options",	v = "{}"},

			{k = "auth_offline_time", 	v = '{"enable":0,"time":10800}'},
			{k = "auth_no_flow_timeout", v = '{"enable":1,"time":300}'},
			{k = "auth_preempt", v = "0"},
			{k = "https_redirect_en", v = "1"},
			{k = "netrule_switch", v = 0},
			{k = "wan_input_enable", v = 0},

			{k = "inspeed",		v = "0"},
			{k = "ienable",		v = "1"},
			{k = "mult",		v = "0"},
			{k = "rate",		v = "2"},
			{k = "enable",		v = "1"},
			{k = "country", 	v = "China"},
			{k = "flow_limit",	v = "500"},
			{k = "rssi_limit",	v = "-85"},
			{k = "sta_enable",	v = "0"},
			{k = "sensitivity",	v = "1"},
			{k = "debug",		v = "disable"},
			{k = "ledctrl",		v = "enable"},
			{k = "ledctrl_switch",		v = "enable"},
			{k = "account",		v = "default"},
			{k = "reboot",		v = "{\"switch\":1,\"time\":{\"hour\":3,\"min\":0},\"interval\":1}"},
			{k = "ld_switch",	v = "0"},
			{k = "rdo_cycle",	v = "5"},
			{k = "upload_log",	v = "0"},
			{k = "sta_cycle",	v = "5"},
			{k = "detectctl",	v = "disable"},
			{k = "rulectrl",	v = "disable"},
			{k = "g_recover",	v = "disable"},
			{k = "sys_crontab", v = "{\"switch\":\"0\",\"time\":{\"hour\":\"03\",\"min\":\"00\",\"week\":\"0\",\"month\":\"01\"},\"weekenable\":\"1\",\"monthenable\":\"0\"}"},
			{k = "reboot_crontab", v = "{\"dayenable\":\"0\",\"day\":{\"hour\":\"00\",\"min\":\"00\"},\"week\":{\"hour\":\"03\",\"min\":\"00\",\"week\":\"0\"},\"month\":{\"hour\":\"03\",\"min\":\"00\",\"month\":\"01\"},\"weekenable\":\"0\",\"monthenable\":\"0\"}"},
			{k = "guestwifi_crontab",	v = '{"time":"unlimited"}'},
			{k = "cloud_account_info",	v = '{"ac_port":61886,"switch":0,"descr":"","ac_host":"","account":""}'},
			{k = "devname", v = "CANWING ROUTER"},
		}

		local miss, find = {}, false
		for _, r in ipairs(new_map) do
			if not exist_map[r.k] then
				miss[r.k], find = r, true
			end
		end

		if not find then
			return false
		end

		local arr = {}
		for k, r in pairs(miss) do
			table.insert(arr, string.format("('%s','%s')", conn:escape(k), conn:escape(r.v)))
		end

		local sql = string.format("insert into kv (k, v) values %s", table.concat(arr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)
		return true
	end
}

--[[
cmd_map.iface = {
	priority = 3,
	func = function(conn)
		local sql = "select count(*) as count from iface"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then
			return
		end

		local default = {
			ifname = "",
			ifdesc = "",
			ethertype = "",
			iftype = "",
			proto = "",
			mtu = "",
			mac = "",
			metric = "",
			gateway = "",
			pppoe_account = "",
			pppoe_password = "",
			static_ip = "",
			dhcp_enable = "",
			dhcp_start = "",
			dhcp_end = "",
			dhcp_time = "",
			dhcp_dynamic = "",
			dhcp_lease = "",
			dhcp_dns = "",
		}
		local set_default = function(r)
			for field, v in pairs(default) do
				if not r[field] then
					r[field] = v
		end
			end
		end

		local ifarr = require("parse_network").parse()
		for _, r in ipairs(ifarr) do
			set_default(r)
			end
		local ifmap = arr2map(ifarr, "ifname")
		-- set zid
		local rs, e = conn:select("select * from zone") 					assert(rs, e)
		local zonemap = arr2map(rs, "zonename")
		for _, r in pairs(ifmap) do
			local n = zonemap[r.ifname:find("^wan") and "WAN" or "LAN"] 	assert(n)
			r.zid, r.pid = n.zid, -1
		end

		-- set pid
		for _, r in pairs(ifmap) do
			local parent = r.parent
			if parent then
				local n = ifmap[parent]
				r.pid = n.zid
			end
		end

		local fields = {
			"fid",
			"ifname",
			"ifdesc",
			"ethertype",
			"iftype",
			"proto",
			"mtu",
			"mac",
			"metric",
			"gateway",
			"pppoe_account",
			"pppoe_password",
			"static_ip",
			"dhcp_enable",
			"dhcp_start",
			"dhcp_end",
			"dhcp_time",
			"dhcp_dynamic",
			"dhcp_lease",
			"dhcp_dns",
			"zid",
			"pid",
		}
		local narr = {}
		for i, r in ipairs(ifarr) do
			local arr = {}
			r.fid = i - 1
			for _, field in ipairs(fields) do
				table.insert(arr, string.format("'%s'", r[field]))
		end
			local s = string.format("(%s)", table.concat(arr, ","))
			table.insert(narr, s)
		end

		local sql = string.format("insert into iface(%s) values %s", table.concat(fields, ","), table.concat(narr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)
		return true
	end
}
]]
cmd_map.zone = {
	priority = 2,
	func = function(conn)
		local sql = "select count(*) as count from zone"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then
			return false
		end

		local arr = {
			{zid = 0, 	zonename = "lan", zonedesc = "lan", zonetype = 3},
			{zid = 1, 	zonename = "wan", zonedesc = "wan", zonetype = 3},
			{zid = 255, zonename = "all", zonedesc = "all", zonetype = 3},
		}

		local narr = {}
		for _, r in ipairs(arr) do
			table.insert(narr, string.format("('%s','%s','%s','%s')", r.zid, r.zonename, r.zonedesc, r.zonetype))
		end
		local sql = string.format("insert into zone (zid,zonename,zonedesc,zonetype) values %s", table.concat(narr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)
		return true
	end
}

cmd_map.ipgroup = {
	priority = 4,
	func = function(conn)
		local sql = "select count(*) as count from ipgroup"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then
			return false
		end

		local arr = {
			{ipgid = 63, ipgrpname = "ALL", ipgrpdesc = "ALL", ranges = js.encode({"0.0.0.0-255.255.255.255"})},
		}

		local narr = {}
		for _, r in ipairs(arr) do
			table.insert(narr, string.format("('%s','%s','%s','%s')", r.ipgid, r.ipgrpname, r.ipgrpdesc, r.ranges))
		end

		local sql = string.format("insert into ipgroup (ipgid,ipgrpname,ipgrpdesc,ranges) values %s", table.concat(narr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)

		return true
	end
}

cmd_map.acgroup = {
	priority = 5,
	func = function(conn)
		local sql = "select count(*) as count from acgroup"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then
			return false
		end

		local arr = {
			{gid = 63, groupname = "default", groupdesc = "default", pid = -1},
		}

		local narr = fp.reduce(arr, function(t, r)
			local s = string.format("('%s','%s','%s','%s')", r.gid, r.groupname, r.groupdesc, r.pid)
			return rawset(t, #t + 1, s)
		end, {})

		local sql = string.format("insert into acgroup (gid,groupname,groupdesc,pid) values %s", table.concat(narr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)

		return true
	end
}

cmd_map.timegroup = {
	priority = 9,
	func = function(conn)
		local sql = "select count(*) as count from timegroup where tmgrpname='ALL'"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then
			return false
		end

		local days = {mon = 1, tues = 1, wed = 1, thur = 1, fri = 1, sat = 1, sun = 1}
		local tmlist = {{hour_start = 0, min_start = 0, hour_end = 23, min_end = 59}}
		local arr = {
			{tmgid = 255, tmgrpname = "ALL", tmgrpdesc = "ALL", days = js.encode(days), tmlist = js.encode(tmlist)},
		}

		local narr = {}
		for _, r in ipairs(arr) do
			table.insert(narr, string.format("('%s','%s','%s','%s','%s')", r.tmgid, r.tmgrpname, r.tmgrpdesc, r.days, r.tmlist))
		end

		local sql = string.format("insert into timegroup (tmgid,tmgrpname,tmgrpdesc,days,tmlist) values %s", table.concat(narr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)

		return true
	end
}

cmd_map.acset = {
	priority = 10,
	func = function(conn)
		local sql = "select count(*) as count from acset"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then
			return false
		end

		local arr = {
			{setid = 0, setname = "access_white_mac", setdesc = "access white mac", setclass = "control", settype = "mac", content = "[]", action = "bypass", enable = 1},
			{setid = 1, setname = "access_black_mac", setdesc = "access balck mac", setclass = "control", settype = "mac", content ="[]", action = "check", enable = 1},
			{setid = 2, setname = "access_white_ip", setdesc = "access white ip", setclass = "control", settype = "ip", content = "[]", action = "bypass", enable = 1},
			{setid = 3, setname = "access_black_ip", setdesc = "access balck ip", setclass = "control", settype = "ip", content = "[]", action = "check", enable = 1},
			{setid = 4, setname = "audit_white_mac", setdesc = "audit white mac", setclass = "audit", settype = "mac", content = "[]", action = "bypass", enable = 0},
			{setid = 5, setname = "audit_white_ip", setdesc = "audit white ip", setclass = "audit", settype = "ip", content = "[]", action = "bypass", enable = 0},
		}

		local narr = {}
		for _, r in ipairs(arr) do
			table.insert(narr, string.format("('%s','%s','%s','%s','%s','%s','%s','%s')", r.setid, r.setname, r.setdesc, r.setclass, r.settype, r.content, r.action, r.enable))
		end

		local sql = string.format("insert into acset (setid,setname,setdesc,setclass,settype,content,action,enable) values %s", table.concat(narr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)

		return true
	end
}

cmd_map.authrule = {
	priority = 6,
	func = function(conn)
		local sql = "select count(*) as count from authrule"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then
			return false
		end

		local arr = {
			{
				rid 		= 1,
				rulename 	= "adm",
				ruledesc 	= "adm",
				zid 		= 0,
				ipgid 		= 63,
				authtype 	= "web",
				modules 	= '{\"adm\":1}',
				priority 	= 0,
				redirect 	= "http://www.baidu.com",
				white_ip 	= '62',
				white_mac 	= '62',
				wechat 		= '{}',
				sms 		= '{}',
			},
			{
                                rid             = 15,
                                rulename        = "default",
                                ruledesc        = "default",
                                zid             = 0,
                                ipgid           = 63,
                                authtype        = "auto",
                                modules         = '{}',
                                priority        = 9999999,
                                redirect        = "",
                                white_ip        = '[]',
                                white_mac       = '[]',
                                wechat          = '{}',
                                sms             = '{}',
                        },
		}

		local narr = {}
		for _, r in ipairs(arr) do
			table.insert(narr, string.format("('%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s')",
				r.rid, r.rulename, r.ruledesc, r.zid, r.ipgid, r.authtype, r.modules, r.priority, r.redirect,
				r.white_ip, r.white_mac, r.wechat, r.sms))
		end

		local sql = string.format("insert into authrule (rid,rulename,ruledesc,zid,ipgid,authtype,modules,priority,redirect, white_ip, white_mac, wechat, sms) values %s", table.concat(narr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)

		return true
	end
}

local function get_devid()
	local path = "/etc/config/board.json"
	local s, e = read(path)
	if not s then
		return nil, e
	end

	local m, e = js.decode(s)
	if not (m and m.model and m.model.devid) then
		return nil, e
	end

	return m.model.devid
end

cmd_map.device = {
	priority = 11,
	func = function(conn)
		local sql = "select count(*) as count from device"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then
			return false
		end

		local g_devid = get_devid()
		local arr = {
			{
				devid		= g_devid,
				devdesc		= "builtinAP",
				hbd_cycle	= "30",
				hbd_time	= "60",
				mnt_time	= "300",
				mode		= "normal",
				radios		= "[\"2g\", \"5g\"]",
				scan_chan	= "recommend",
				devtype		= "ac",
				version		= "1970-01-01 00:00:00",
			},
		}

		local narr = {}
		for _, r in ipairs(arr) do
			table.insert(narr, string.format("('%s','%s','%s','%s','%s','%s','%s','%s','%s','%s')", r.devid, r.devdesc, r.hbd_cycle, r.hbd_time, r.mnt_time, r.mode, r.radios, r.scan_chan, r.devtype, r.version))
		end

		local sql = string.format("insert into device (devid,devdesc,hbd_cycle,hbd_time,mnt_time,mode,radios,scan_chan,devtype,version) values %s", table.concat(narr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)

		return true
	end
}

cmd_map.radio = {
	priority = 12,
	func = function(conn)
		local sql = "select count(*) as count from radio"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then
			return false
		end

		local g_devid = get_devid()
		local arr = {
			{
				devid		= g_devid,
				band		= "2g",
				proto		= "bgn",
				ampdu		= "1",
				amsdu		= "1",
				bandwidth	= "auto",
				beacon		= "100",
				bswitch		= "1",
				chanid		= "auto",
				dtim		= "1",
				leadcode	= "1",
				power		= "auto",
				remax		= "4",
				rts			= "2347",
				shortgi		= "1",
				usrlimit	= "40",
			},
			{
				devid		= g_devid,
				band		= "5g",
				proto		= "n",
				ampdu		= "1",
				amsdu		= "1",
				bandwidth	= "auto",
				beacon		= "100",
				bswitch		= "1",
				chanid		= "auto",
				dtim		= "1",
				leadcode	= "1",
				power		= "auto",
				remax		= "4",
				rts			= "2347",
				shortgi		= "1",
				usrlimit	= "40",
			},
		}

		local narr = {}
		for _, r in ipairs(arr) do
			table.insert(narr, string.format("('%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s')", r.devid, r.band, r.proto, r.ampdu, r.amsdu, r.bandwidth, r.beacon, r.bswitch, r.chanid, r.dtim, r.leadcode, r.power, r.remax, r.rts, r.shortgi, r.usrlimit))
		end

		local sql = string.format("insert into radio (devid,band,proto,ampdu,amsdu,bandwidth,beacon,bswitch,chanid,dtim,leadcode,power,remax,rts,shortgi,usrlimit) values %s", table.concat(narr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)

		return true
	end
}

cmd_map.wlan = {
	priority = 13,
	func = function(conn)
		local sql = "select count(*) as count from wlan"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then
			return false
		end

		local mac = get_devid()
		mac = mac and mac:gsub(":", ""):upper()
		local len = #mac
		mac = string.sub(mac, len - 3, len)
--		local model = (read([[cat /etc/openwrt_release | grep DISTRIB_ID | awk -F\' '{print $2}']], io.popen) or ""):gsub("[ \t\r\n]", "")
--		local default_2gssid = string.format("%s_2G_%s", model, mac)
--		local default_5gssid = string.format("%s_5G_%s", model, mac)
		local home_ssid = string.format("CW_home_%s",  mac)
		local guest_ssid = string.format("CW_guest_%s",  mac)

		local ssid_uuid_md5 = (read([[cat /proc/sys/kernel/random/uuid | md5sum | awk '{print $1}']], io.popen) or ""):gsub("[ \t\r\n]", "")
		local len = #ssid_uuid_md5
		local pair_default_ssid = string.format("Pair_%s", string.sub(ssid_uuid_md5, len - 16, len))

		local pwd_uuid_md5 = (read([[cat /proc/sys/kernel/random/uuid | md5sum | awk '{print $1}']], io.popen) or ""):gsub("[ \t\r\n]", "")
		local len = #pwd_uuid_md5
		local pair_default_pwd = string.sub(pwd_uuid_md5, len - 16, len)

		local arr = {
			{
				wlanid 		= 2,
				ssid 		= home_ssid,
				band	 	= "2g",
				encrypt 	= "none",
				password 	= "",
				network 	= "lan1",
				code_format = 0,
				hide 		= 0,
				enable 		= 1,
				vlan_enable = 0,
				vlanid		= 1,
				ruleid		= 23,
				wifi_double	= 1,
				wlanflag 	= "private",
				apply_all 	= 0,
			},
			{
				wlanid 		= 5,
				ssid 		= home_ssid,
				band	 	= "5g",
				encrypt 	= "none",
				password 	= "",
				network 	= "lan1",
				code_format = 0,
				hide 		= 0,
				enable 		= 1,
				vlan_enable = 0,
				vlanid		= 1,
				ruleid		= 23,
				wifi_double	= 1,
				wlanflag 	= "private",
				apply_all 	= 0,
			},
			{
				wlanid 		= 7,
				ssid 		= guest_ssid,
				band	 	= "all",
				encrypt 	= "none",
				password 	= "",
				network 	= "lan2",
				code_format = 0,
				hide 		= 0,
				enable 		= 0,
				vlan_enable = 0,
				vlanid		= 1,
				ruleid		= 22,
				wifi_double	= 0,
				wlanflag 	= "public",
				apply_all 	= 0,
			},
			{
				wlanid 		= 9,
				ssid 		= pair_default_ssid,
				band	 	= "2g",
				encrypt 	= "psk2",
				password 	= pair_default_pwd,
				network 	= "lan1",
				code_format = 0,
				hide 		= 1,
				enable 		= 1,
				vlan_enable = 0,
				vlanid		= 1,
				ruleid		= 0,
				wifi_double	= 0,
				wlanflag 	= "hiden",
				apply_all 	= 0,
			},
		}

		local narr = {}
		for _, r in ipairs(arr) do
			table.insert(narr, string.format("(%s,'%s','%s','%s','%s','%s','%s','%d',%d, %d, %d, %d, %d, %d, %d)", r.wlanid, r.ssid, r.band, r.encrypt, r.password, r.network, r.wlanflag, r.hide, r.enable, r.vlan_enable, r.vlanid, r.wifi_double, r.ruleid, r.apply_all, r.code_format))
		end

		local sql = string.format("insert into wlan (wlanid,ssid,band,encrypt,password,network,wlanflag,hide,enable,vlan_enable,vlanid,wifi_double,ruleid,apply_all,code_format) values %s", table.concat(narr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)

		return true
	end
}

cmd_map.wlanap = {
	priority = 14,
	func = function(conn)
		local sql = "select count(*) as count from wlan2ap"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then
			return false
		end

		local g_devid = get_devid()
		local arr = {
			{
				wlanid 		= 2,
				devid		= g_devid,
			},
			{
				wlanid 		= 5,
				devid		= g_devid,
			},
			{
				wlanid 		= 7,
				devid		= g_devid,
			},
			{
				wlanid 		= 9,
				devid		= g_devid,
			},
		}

		local narr = {}
		for _, r in ipairs(arr) do
			table.insert(narr, string.format("(%s,'%s')", r.wlanid, r.devid))
		end

		local sql = string.format("insert into wlan2ap (wlanid,devid) values %s", table.concat(narr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)

		return true
	end
}

cmd_map.macgroup = {
	priority = 15,
	func = function(conn)
		local sql = "select count(*) as count from macgroup"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then
			return false
		end

		local arr = {
			{macgid = 62, macgrpname = "NONE", macgrpdesc = "NONE", ranges = ""},
		}

		local narr = {}
		for _, r in ipairs(arr) do
			table.insert(narr, string.format("('%s','%s','%s','%s')", r.macgid, r.macgrpname, r.macgrpdesc, r.ranges))
		end

		local sql = string.format("insert into macgroup (macgid,macgrpname,macgrpdesc,ranges) values %s", table.concat(narr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)

		return true
	end
}
--[[
cmd_map.netrule = {
	priority = 6,
	func = function(conn)
		local sql = "select count(*) as count from netrule"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then
			return false
		end

		local arr = {
			{
				ruleid = 23,
				rulename = '默认允许上网',
				ruletype = 'default',
				starttime = '00:00',
				stoptime = '23:59',
				netusage = '23:59',
				week_list = '["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]',
				active = os.time(),
			},
			{
				ruleid = 22,
				rulename = '默认禁止上网',
				ruletype = 'default',
				starttime = '00:00',
				stoptime = '00:00',
				netusage = '00:00',
				week_list = '["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]',
				active = os.time(),
			},
		}

		local narr = {}
		for _, r in ipairs(arr) do
			table.insert(narr, string.format("('%s','%s','%s','%s','%s','%s','%s','%s')", r.ruleid, r.rulename, r.ruletype, r.starttime, r.stoptime, r.netusage, r.week_list, r.active))
		end

		local sql = string.format("insert into netrule (ruleid,rulename,ruletype,starttime,stoptime,netusage,week_list,active) values %s", table.concat(narr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)

		return true
	end
}
]]

local function main()
	local cfg, e = config.ins() 					assert(cfg, e)
	local conn = dc.new(cfg:get_workdb())

	local arr = {}
	for _, r in pairs(cmd_map) do
		table.insert(arr, r)
	end

	table.sort(arr, function(a, b) return a.priority < b.priority end)

	local change = false
	for _, r in pairs(arr) do
		local r, e = r.func(conn)
		change = change and change or r
	end

	if change then
		backup_disk(cfg)
	end

	-- conn:close()
end

main()
