local fp = require("fp")
local log = require("nlog")

local function format_replace(conn, rs, tbname)
	local fields = {}
	for k in pairs(rs[1]) do
		table.insert(fields, k)
	end

	local narr = {}
	for _, r in ipairs(rs) do
		local arr = {}
		for _, field in ipairs(fields) do
			table.insert(arr, string.format("'%s'", conn:escape(r[field])))
		end
		table.insert(narr, string.format("(%s)", table.concat(arr, ",")))
	end

	return string.format("replace into %s (%s) values %s", tbname, table.concat(fields, ","), table.concat(narr, ","))
end

local function sync(conn_map, tbname, actions, key)
	local copas = require("copas")
	local conn, myconn = conn_map.conn, conn_map.myconn
	local arr = actions.del

	-- tb, act, key, val
	if #arr > 0 then
		local narr = {}
		for _, r in ipairs(arr) do
			local devid, wlanid = r.val:match("(.+)_(%d+)")	assert(devid and wlanid)
			table.insert(narr, string.format("(devid='%s' and wlanid='%s')", devid, wlanid))
		end

		local cycle = 300
		while narr and #narr > 0 do
			local count = math.min(#narr, cycle)
			local del = {}
			for i = 1, count do
				local tmp = table.remove(narr)
				table.insert(del, tmp)
			end

			local sql = string.format("delete from wlan2ap where %s", table.concat(del, " or "))
			local r, e = myconn:execute(sql)
			local _ = r or log.fatal("%s %s", sql, e)

			copas.sleep(0.05)
		end
	end

	arr = actions.set
	for _, r in ipairs(actions.add) do
		table.insert(arr, r)
	end

	actions.add = nil
	if #arr == 0 then
		return
	end

	local narr = {}
	for _, r in ipairs(arr) do
		local devid, wlanid = r.val:match("(.+)_(%d+)")	assert(devid and wlanid)
		table.insert(narr, string.format("(devid='%s' and wlanid='%s')", devid, wlanid))
	end

	local cycle = 300
	local rs_map = {}
	while narr and #narr > 0 do
		local count = math.min(#narr, cycle)
		local map = {}
		for i = 1, count do
			local tmp = table.remove(narr)
			table.insert(map, tmp)
		end

		local sql = string.format("select * from %s where %s", tbname, table.concat(map, " or "))
		local rs, e = conn:select(sql)
		local _ = rs or log.fatal("%s %s", sql, e)

		for _, v in ipairs(rs) do
			table.insert(rs_map, v)
		end

		copas.sleep(0.01)
	end

	local sql = format_replace(conn, rs_map, tbname)
	local r, e = myconn:execute(sql)
	local _ = r or log.fatal("%s %s", sql, e)
end

return {sync = sync}