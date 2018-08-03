local log = require('log')
local ski = require("ski")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local simplesql = require("simplesql")
local sandcproxy = require("sandcproxy")
local config = require("config")
local misc = require("ski.misc")
local updatelog = require("updatelog")
local dc = require("dbcommon")

local conn
local ud

local SELECT_RES_INDEX 	= 1
local ID_LIMIT 			= 64
local MAX_ID 			= 63 		-- 0~63
local CLOUD_MAC_GID		= 61
local CLOUD_DST_GID		= 61

local lan_file = "/etc/config/lan.json"
local default_lan = "CN"	-- 默认为"CN"-中文
local cur_lan 					--当前的语言环境

local lan_map = {
	CLOUD_BYPASS_MAC = {CN = '云端mac白名单', US = 'cloud_bypass_mac'},
	CLOUD_BYPASS_DST = {CN = '云端url白名单', US = 'cloud_bypass_dst'},
	AUTH_BYPASS_DST = {CN = '本地url白名单', US = 'auth_bypass_dst'},
	AUTH_WHITE_IP = {CN = 'IP白名单', US = 'auth_white_ip'},
	AUTH_WHITE_MAC = {CN = 'MAC白名单', US = 'auth_white_mac'}
}

local function read(path, func)
	func = func and func or io.open
	local fp, err = func(path, "r")
	if not fp then
		return nil, err
	end
	local s = fp:read("*a")
	fp:close()
	return s
end

local function get_cur_lan()
	if cur_lan then
		return cur_lan
	end

	local s = read(lan_file)
	if not s then
		return default_lan
	end

	local map = js.decode(s) or {}
	cur_lan = map.lan

	return cur_lan or default_lan
end

local function translate_lan(code)
	local item = lan_map[code]
	local lan = get_cur_lan()
	return item[lan]
end


local function init_config()
	local cfg, err = config.ins()
	local _ = cfg or log.fatal("load config fail %s", err)
	return cfg
end

local function init()
	local cfg = init_config()
	conn = dc.new(cfg:get_workdb(), {{path = cfg:get_memodb(), alias = "memo"}})
end

local function set_ud(in_ud)
	ud = in_ud
end

local function set_conn(in_conn)
	conn = in_conn
end

local function get_conn()
	if not conn then
		init()
	end
	return conn
end

local function insert_macgroup(macgrps)
	local sql = string.format("insert into macgroup %s values %s", conn:insert_format(macgrps))
	local r, e = conn:execute(sql)
	if not r then
		return nil, e
	end
	ud:save_log(sql, true)
	return true
end

local function insert_ipgroup(ipgrps)
	local sql = string.format("insert into ipgroup %s values %s", conn:insert_format(ipgrps))
	local r, e = conn:execute(sql)
	if not r then
		return nil, e
	end
	ud:save_log(sql, true)
	return true
end

--[[
	函数: update_ipgroup()
	功能: 转换ipgroup, 并且改变ALL组的ipgid和增加一个NONE组. MAC相关的NONE组, 在default_92文件中操作.
	描述: 从低版本升级到高版本(3.1->3.2)时, ranges存ip数据改为ext存ip数据, 所以要进行相应的转换把ranges中的数据存在ext中.
	作者: isshe
	日期: 20170605
	注意: 如果保留配置升级时, ipgroup中有ipgid为62的组, NONE组将添加失败!!!目前暂无解决方案.
]]
local function update_ipgroup()
	log.debug("Update the ipgroup table to the new table")
	local ipgroups = {}
	local sql = string.format("select * from ipgroup")
	local ret, e = conn:select(sql)
	if not (ret and #ret ~= 0)then
		return
	end

	local all_sql = {}
	local none_flag = false
	for _, ipgrp in ipairs(ret) do
		-- 不能把ALL组的ipgid改为62, 因为内核应用控制规则的时候用到了63.
		-- 如果已经有NONE组了, 就标志一下.
		if ipgrp.ipgrpname == "NONE" and tonumber(ipgrp.ipgid) == MAX_ID-1 then
			none_flag = true
		end

		local new_ipgrp = {}
		local ext = {}
		local ranges = ipgrp.ranges and js.decode(ipgrp.ranges) or {}
		for _, ip in ipairs(ranges) do
			table.insert(ext, {val = ip, desc = ""})
		end

		if ext and #ext ~= 0 then
			new_ipgrp.ext = js.encode(ext)
			new_ipgrp.ranges = ""
			new_ipgrp.ipgrpname = ipgrp.ipgrpname
			new_ipgrp.ipgrpdesc = ipgrp.ipgrpdesc
			new_ipgrp.ipgid = ipgrp.ipgid
			local sql = string.format("update ipgroup set %s where ipgid=%s", conn:update_format(new_ipgrp), new_ipgrp.ipgid)
			table.insert(all_sql, sql)
		end
	end

	if not none_flag then  		-- 添加NONE组
		local new_ipgrp = {}
		new_ipgrp.ext = ""
		new_ipgrp.ranges = ""
		new_ipgrp.ipgrpname = "NONE"
		new_ipgrp.ipgrpdesc = "NONE"
		new_ipgrp.ipgid = MAX_ID - 1 		-- 62
		local sql = string.format("insert into ipgroup %s values %s", conn:insert_format(new_ipgrp))
		table.insert(all_sql, sql)
	end

	for _, sql in ipairs(all_sql) do
		local r, e = conn:execute(sql)
		if not r then
			log.debug("ERRPR : %s.[ignore.executing next one]", e)
			--return nil, e
		end
	end

	log.debug("Update the ipgroup table success")
	ud:save_log(all_sql, true)
	return true
end

local function update_authrule()
	local sqlarr = {}
	log.debug("Update the authrule table to the new table")
	local format_ip_data = function(ips, rulename)
		local ipgrps = {}
		ipgrps.ranges = ""
		ipgrps.ext = js.encode(ips)
		ipgrps.ipgrpname = rulename .. translate_lan("AUTH_WHITE_IP")
		ipgrps.ipgrpdesc = translate_lan("AUTH_WHITE_IP")
		local sql = string.format("select ipgid, ipgrpname from ipgroup")
		local rs, e = conn:select(sql)
		if not rs then
			return nil, e
		end

		local ids = {}
		for _, r in ipairs(rs) do
			local id, ipgrpname = r.ipgid, r.ipgrpname
			table.insert(ids, id)
			if ipgrps.ipgrpname == ipgrpname then
				ipgrps.ipgrpname = ipgrps.ipgrpname .. "_auth_white_ip_3.1"
			end
		end

		-- get next rid
		local ipgid, e = conn:next_id(ids, ID_LIMIT)
		if not ipgid then
			log.debug("ERRPR : update_authrule get next ipgid fail : %s", e)
			return nil, e
		end
		ipgrps.ipgid = ipgid
		return ipgrps
	end

	local format_mac_data = function(macs, rulename)
		local macgrps = {}
		macgrps.ranges = js.encode(macs)
		macgrps.macgrpname = rulename .. translate_lan("AUTH_WHITE_MAC")
		macgrps.macgrpdesc = translate_lan("AUTH_WHITE_MAC")
		local sql = string.format("select macgid, macgrpname from macgroup")
		local rs, e = conn:select(sql)
		if not rs then
			return nil, e
		end
		local ids = {}
		for _, r in ipairs(rs) do
			local id, macgrpname = r.macgid, r.macgrpname
			table.insert(ids, id)
			if macgrps.macgrpname == macgrpname then
				macgrps.macgrpname = macgrps.macgrpname .. "_auth_white_mac_3.1"
			end
		end
		-- get next rid
		local macgid, e = conn:next_id(ids, ID_LIMIT)
		if not macgid then
			log.debug("ERRPR : update_authrule get next macgid fail : %s", e)
			return nil, e
		end
		macgrps.macgid = macgid
		return macgrps
	end

	local sql = string.format("select white_mac, white_ip, rulename from authrule")
	local ret, e = conn:select(sql)
	if not ret then
		log.debug("authrule-over")
		return nil, e
	end
	for _, authgrp in ipairs(ret) do
		if authgrp.rulename == "default" then
			local sql_de = string.format("update authrule set white_ip = '62', white_mac = '62' where rulename = 'default'")
			ret, e = conn:execute(sql_de)
			if not ret then
				return nil, e
			end
		else
			local macs, ips = {}, {}
			local white_ip = authgrp.white_ip and js.decode(authgrp.white_ip) or {}
			local white_mac = authgrp.white_mac and js.decode(authgrp.white_mac) or {}
			if not tonumber(white_ip) and type(white_ip) == "table" then
				if next(white_ip) then
					for _, ip in ipairs(white_ip) do
						table.insert(ips, {val = ip, desc = "auth_white_ip"})
					end
				end
			end

			if not tonumber(white_mac) and type(white_mac) == "table" then
				if next(white_mac) then
					for _, mac in ipairs(white_mac) do
						table.insert(macs, {val = mac, desc = "auth_white_mac"})
					end
				end
			end
			if not (tonumber(white_ip) ~= nil and tonumber(white_mac) ~= nil) then
				local ipgrps, macgrps = {}, {}
				local e
				if #ips > 0 then
					ipgrps, e = format_ip_data(ips, authgrp.rulename)
					if e then
						log.debug("ERRPR : authrule format ip data : %s", e)
					end
					if ipgrps then
						local rs, e = insert_ipgroup(ipgrps)
						if not rs then
							log.debug("ERRPR : authrule insert ipgroup table : %s", e)
							return nil, e
						end
					end
				else
					ipgrps.ipgid = 62
				end
				if #macs > 0 then
					macgrps, e = format_mac_data(macs, authgrp.rulename)
					if e then
						log.debug("ERRPR : authrule format mac data : %s", e)
					end
					if macgrps then
						local r, e = insert_macgroup(macgrps)
						if not r then
							log.debug("ERRPR : authrule insert macgroup table : %s", e)
							return nil, e
						end
					end
				else
					macgrps.macgid = 62
				end
				local sql = string.format("update authrule set white_mac='%s', white_ip='%s' where rulename = '%s'", macgrps.macgid, ipgrps.ipgid, authgrp.rulename)
				print("sql = ",sql)
				local r, e = conn:execute(sql)
				if not r then
					log.debug("ERRPR : update authrule table : %s", e)
					return nil, e
				end
				table.insert(sqlarr, sql)
			end
		end
	end
	ud:save_log(sqlarr, true)
	log.debug("Update the authrule table success")
	return true
end

--[[
	功能: 获取ipgroup的下一个组id(gid)
	作者: isshe
	日期: 20170527
]]
local function get_next_ipid()
	local sql = string.format("select ipgid from ipgroup")
	local rs, e = conn:select(sql)
	if not rs then
		return nil, e
	end
	local ids = {}
	for _, r in ipairs(rs) do
		local id = r.ipgid
		table.insert(ids, id)
	end
	-- get next rid
	local new_id, e = conn:next_id(ids, ID_LIMIT)
	if not new_id then
		log.debug("ERRPR : update_acset get next ipgid fail : %s", e)
		return nil, e
	end
	return new_id
end
--[[
	功能: 获取macgroup的下一个组id(gid)
	作者: isshe
	日期: 20170527
]]
local function get_next_macid()
	local sql = string.format("select macgid from macgroup")
	local rs, e = conn:select(sql)
	if not rs then
		return nil, e
	end
	local ids = {}
	for _, r in ipairs(rs) do
		local id = r.macgid
		table.insert(ids, id)
	end
	-- get next rid
	local new_id, e = conn:next_id(ids, ID_LIMIT)
	if not new_id then
		log.debug("ERRPR : update_acset get next macid fail : %s", e)
		return nil, e
	end
	return new_id
end

--[[
	功能: content中原来不是gid, 现在用于存gid
	作者: isshe
	日期: 20170527
]]
local function update_content_to_gid(setname, gid)
	if setname and gid then
		local sql = string.format("update acset set content='%s' where setname='%s'", gid, setname)
		local r, e = conn:execute(sql)
		if not r then
			log.debug("ERRPR : delete acset table : %s", e)
			return nil, e
		end
		ud:save_log(sql, true)
	end
end

--[[
	功能: 定义这个map主要是为了方便生成需要的组名字.
	作者: isshe
	日期: 20170527
	setname: 数据库acset表中的setname
	def_grpname: 生成默认组时使用的组名
	def_grpdesc: 默认组的描述
]]
local group_info_map =  {
	{setname="access_white_mac", def_grpname="默认MAC白名单", def_grpdesc = "默认的MAC白名单组"},
	{setname="access_black_mac", def_grpname="默认MAC黑名单", def_grpdesc = "默认的MAC黑名单组"},
	{setname="access_white_ip", def_grpname="默认IP白名单", def_grpdesc = "默认的IP白名单组"},
	{setname="access_black_ip", def_grpname="默认IP黑名单", def_grpdesc = "默认的IP黑名单组"},
}

--[[
	功能: 根据setname获取group_info_map中的信息
]]
local function get_group_info(setname)
	local grpinfo = {}
	if group_info_map and type(group_info_map) == "table" and setname then
		for _, v in pairs(group_info_map) do
			if setname == v.setname then
				grpinfo = v
				break
			end
		end
	end

	return grpinfo
end

--[[
	函数: update_acset()
	功能: 1. 系统升级时, 更新acset到ipgroup/macgroup里面, 当acset相关条目的content为空, 就添加一条默认的给group
		 2. 不是系统升级时, content里面存的是gid.
		 所以要区分升级和不是升级, content是gid还是不是gid.
	修改: isshe
	日期: 20170526
]]
local function update_acset()
	log.debug("Update the acset table to the new table")
	local  format_mac_data = function(accessgrp)
		local content = js.decode(accessgrp.content) or {}

		local ranges, macgrps = {}, {}
		for _, range in ipairs(content) do
			table.insert(ranges, {val = range, desc = accessgrp.action})
		end
		if  #ranges == 0 then
			macgrps.ranges = ""
		else
			macgrps.ranges = js.encode(ranges)
		end

		local grpinfo = get_group_info(accessgrp.setname)
		macgrps.macgrpname = grpinfo.def_grpname
		macgrps.macgrpdesc = grpinfo.def_grpdesc
		-- get next rid
		local macid, e = get_next_macid()
		if not macid then
			log.debug("ERRPR : update_acset get next macid fail : %s", e)
			return nil, e
		end
		macgrps.macgid = macid
		return macgrps
	end

	local  format_ip_data = function(accessgrp)
		local content = js.decode(accessgrp.content) or {}
		local ranges, ipgrps = {}, {}

		for _, range in ipairs(content) do
			table.insert(ranges, {val = range, desc = accessgrp.action})
		end
		if  #ranges == 0 then
			ipgrps.ext = ""
		else
			ipgrps.ext = js.encode(ranges)
		end
		ipgrps.ranges = ""

		local grpinfo = get_group_info(accessgrp.setname)
		ipgrps.ipgrpname = grpinfo.def_grpname
		ipgrps.ipgrpdesc = grpinfo.def_grpdesc

		-- get next rid
		local ipid, e = get_next_ipid()
		if not ipid then
			log.debug("ERRPR : update_acset get next ipid fail : %s", e)
			return nil, e
		end
		ipgrps.ipgid = ipid
		return ipgrps
	end
	local sql = string.format("select * from acset")
	local ret, e = conn:select(sql)
	if not (ret and #ret ~= 0)then
		return
	end

	for _, accessgrp in ipairs(ret) do
		if accessgrp.setclass == "control" then
			local content = js.decode(accessgrp.content) or {}
			local gid = tonumber(content)
			if gid and type(gid) == "number" then 	-- 如果是数字(有内容), 不用进行相关操作, 直接返回. (type(gid) == "number"应该可以不要)
				log.debug("是组ID, 返回, 不用继续操作")
				--return nil, "Is group ID"			-- 其他循环也不做了
			else
				if accessgrp.settype == "mac" then
					local macgrps, e = format_mac_data(accessgrp)
					if e then
						log.debug("ERRPR : acset format mac data : %s", e)
					end
					if macgrps then
						local r, e = insert_macgroup(macgrps)
						if not r then
							log.debug("ERRPR : acset insert macgroup table : %s", e)
							return nil, e
						end
						update_content_to_gid(accessgrp.setname, macgrps.macgid) 	-- 更新
					end
				end
				if accessgrp.settype == "ip" then
					local ipgrps, e = format_ip_data(accessgrp)
					if e then
						log.debug("ERRPR : format ip data : %s", e)
					end
					if ipgrps then
						local rs, e = insert_ipgroup(ipgrps)
						if not rs then
							log.debug("ERRPR : insert ipgroup table : %s", e)
							return nil, e
						end
						update_content_to_gid(accessgrp.setname, ipgrps.ipgid) 	-- 更新
					end
				end
			end
		end
	end
	log.debug("Update the acset table success")
	return true
end

local function crc32(str)
	if str == nil then
		return nil
	end
	local tmp = str:match(".*(%*%.)(.+)")
	if not tmp then
		local temp = str:match(".*(%*).+")
		if temp then
			str = str:match(".*%*(.+)")
		end
	else
		str = str:match(".*%*%.(.+)")
		local temp = str:match(".*(%*).+")
		if temp then
			str = str:match(".*%*(.+)")
		end
	end
	local crccmd = "/usr/sbin/ncrc32 -s "
	local cmdstr = string.format("%s",crccmd..str)
	local res = misc.execute(cmdstr)

	local res = res:match("(%w+)")

	if not res then
		return nil, "exec crc32 err"
	end
	return res
end

local function getcrc32arr(urlliststr)
	local urltab = urlliststr
	if not urltab then
		return nil, "urltab to decode err"
	end
	local res, tab = {}, {}
	for _, value in pairs(urltab) do
		local crcname, err = crc32(value.val)
		if not crcname then
			return nil, err
		end
		if tab[crcname] ~= 1 then
			table.insert(res, crcname)
			tab[crcname] = 1
		end
	end
	if not res then
		return nil, "getcrc32arr err"
	end

	return js.encode(res)
end


local function update_auth_bypass_dst()
	local sqlarr = {}
	local sql = string.format("select v from kv where k = 'auth_bypass_dst'")
	local ret, e = conn:select(sql)
	if not (ret[1] and ret[1].v and #(ret[1].v) ~= 0) then
		return
	end
	local urllist, urlgroup = {}, {}
	local urls = js.decode(ret[1].v)

	if type(urls) == "number" then
		return
	end

	if next(urls) == nil then
		urlgroup.url_ids = ""
	else
		for _, url in ipairs(urls) do
			if not url:match("(.+)%.(.+)") then
				return
			end
			table.insert(urllist, {val = url, desc = "auth_bypass_dst"})
		end
		urlgroup.url_ids, e = getcrc32arr(urllist)
		if not urlgroup.url_ids then
			return nil, e
		end
	end

	local urltype = {}
	table.insert(urltype, "http")
	table.insert(urltype, "https")
	urlgroup.urllist = next(urllist) and js.encode(urllist) or ""
	urlgroup.urltype = js.encode(urltype)
	urlgroup.urldesc = translate_lan("AUTH_BYPASS_DST")
	urlgroup.name = translate_lan("AUTH_BYPASS_DST")
	urlgroup.enable = 1
	local sql = string.format("select gid, name from urls")
	local rs, e = conn:select(sql)
	if not rs then
		return nil, e
	end
	local ids = {}
	for _, r in ipairs(rs) do
		local id, name = r.gid, r.name
		table.insert(ids, id)
		if urlgroup.name == name then
			urlgroup.name = urlgroup.name.."_3.1"
		end
	end
	-- get next rid
	local id, e = conn:next_id(ids, ID_LIMIT)
	if not id then
		log.debug("ERRPR : update_auth_bypass_dst get next urlid fail : %s", e)
		return nil, e
	end
	urlgroup.gid = id
	local sql = string.format("insert into urls %s values %s", conn:insert_format(urlgroup))
	local r, e = conn:execute(sql)
	if not r then
		log.debug("ERRPR : insert urls table : %s", e)
		return nil, e
	end
	table.insert(sqlarr, sql)
	local sql = string.format("update kv set v='%s' where k='auth_bypass_dst'",urlgroup.gid)
	local r, e = conn:execute(sql)
	if not r then
		log.debug("ERRPR : update auth_bypass_dst table : %s", e)
		return nil, e
	end
	table.insert(sqlarr, sql)
	ud:save_log(sqlarr, true)
end

local function update_cloud_bypass_dst()
	local sqlarr = {}
	local sql = "select v from kv where k = 'cloud_bypass_dst'"
	local ret, e = conn:select(sql)
	if not (ret[1] and ret[1].v and #(ret[1].v) ~= 0) then
		return
	end
	local urllist, urlgroup = {}, {}
	local urls = js.decode(ret[1].v)
	if type(urls) == "number" then
		return
	end
	if next(urls) == nil then
		urlgroup.url_ids = ""
	else
		for _, url in ipairs(urls) do
			if not url:match("(.+)%.(.+)") then
				return
			end
			table.insert(urllist, {val = url, desc = "cloud_bypass_dst"})
		end
		urlgroup.url_ids, e = getcrc32arr(urllist)
		if not urlgroup.url_ids then
			return nil, e
		end
	end

	local urltype = {}
	table.insert(urltype, "http")
	table.insert(urltype, "https")
	urlgroup.urllist = next(urllist) and js.encode(urllist) or ""
	urlgroup.urltype = js.encode(urltype)
	urlgroup.urldesc = translate_lan("CLOUD_BYPASS_DST")
	urlgroup.name = translate_lan("CLOUD_BYPASS_DST")
	urlgroup.enable = 1
	urlgroup.gid = tostring(CLOUD_DST_GID)
	local sql = string.format("select gid from urls where name = '%s'", translate_lan("CLOUD_BYPASS_DST"))
	local rs, e = conn:select(sql)
	if not rs then
		return nil, e
	end
	if #rs == 0 then
		local sql = string.format("insert into urls %s values %s", conn:insert_format(urlgroup))
		local r, e = conn:execute(sql)
		if not r then
			log.debug("ERRPR : insert urls table : %s", e)
			return nil, e
		end
		table.insert(sqlarr, sql)
	else
		local sql = string.format("update urls set url_ids='%s', urllist='%s' where name = '%s'", urlgroup.url_ids, urlgroup.urllist, translate_lan("CLOUD_BYPASS_DST"))
		local r, e = conn:execute(sql)
		if not r then
			log.debug("ERRPR : update urls table : %s", e)
			return nil, e
		end
		table.insert(sqlarr, sql)
	end
	local sql = string.format("update kv set v='%s' where k='cloud_bypass_dst'",tostring(urlgroup.gid))
	local r, e = conn:execute(sql)
	if not r then
		log.debug("ERRPR : update cloud_bypass_dst table : %s", e)
		return nil, e
	end
	table.insert(sqlarr, sql)
	ud:save_log(sqlarr, true)
end

local function update_cloud_bypass_mac()
	local sqlarr = {}
	local format_mac_data = function(macs)
		local macgrps = {}

		macgrps.ranges = next(macs) and js.encode(macs) or ""
		macgrps.macgrpname = translate_lan("CLOUD_BYPASS_MAC")
		macgrps.macgrpdesc = translate_lan("CLOUD_BYPASS_MAC")
		macgrps.macgid = tostring(CLOUD_MAC_GID)
		return macgrps
	end

	local macs, ips = {}, {}
	local sql = string.format("select v from kv where k = 'cloud_bypass_mac'")
	local ret, e = conn:select(sql)
	if not ret then
		return
	end
	local cloud_macs = js.decode(ret[1].v)

	if type(cloud_macs) == "number" then
		return
	end
	if cloud_macs == nil then
		return
	end
	if next(cloud_macs) ~= nil then
		for _, mac in ipairs(cloud_macs) do
			if not mac:match("^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$") then
				return
			end
			table.insert(macs, {val = mac, desc = "cloud_bypass_mac"})
		end
	end

	local macgrps, e = format_mac_data(macs)

	if macgrps then
		local sql = string.format("select macgid from macgroup where macgrpname = '%s'", translate_lan("CLOUD_BYPASS_MAC"))
		local ret, e = conn:select(sql)
		if not ret then
			log.debug("ERRPR : macgrpname select macgid table : %s", e)
			return
		end
		if #ret == 0 then
			local sql = string.format("insert into macgroup %s values %s", conn:insert_format(macgrps))
			local ret, e = conn:execute(sql)
			if not ret then
				log.debug("ERRPR : cloud_bypass_mac insert macgroup table : %s", e)
				return
			end
			table.insert(sqlarr, sql)
		else
			local sql = string.format("update macgroup set ranges='%s' where macgrpname='%s'",js.encode(macgrps.ranges), translate_lan("CLOUD_BYPASS_MAC"))
			local ret, e = conn:execute(sql)
			if not ret then
				log.debug("ERRPR : update macgroup table : %s", e)
				return
			end
			table.insert(sqlarr, sql)
		end
	end
	local sql = string.format("update kv set v='%s' where k='cloud_bypass_mac'",macgrps.macgid)
	local r, e = conn:execute(sql)
	if not r then
		log.debug("ERRPR : delete cloud_bypass_mac table : %s", e)
		return nil, e
	end
	table.insert(sqlarr, sql)
	ud:save_log(sqlarr, true)
	log.debug("Update the cloud_bypass_mac table success")
	return true
end

local function update_ops()
	update_ipgroup()
	update_authrule()
	update_acset()
	update_auth_bypass_dst()
	update_cloud_bypass_dst()
	update_cloud_bypass_mac()
end

return {set_ud = set_ud, set_conn = set_conn, update_ops = update_ops}
