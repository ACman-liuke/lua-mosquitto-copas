-- author@yjs tgb
--[[
	涉及:log.bin和disk.db的操作，全部加锁，即需要保证资源访问的互斥性.
	涉及到互斥资源的操作如下：
	op1:save_log 由main.lua中rpc指令中加锁
	op2:前端升级通过rpc调用backup，由main.lua中rpc指令加锁
	op3:周期性刷新log.bin，可能触发backup
]]

local log = require("nlog")
local common = require("common")
local js = require("cjson.safe")
local rdsparser = require("rdsparser")
local dc = require("dbcommon")
local bklock = require("bklock")

local shpath = "./db.sh"

local method = {}
local mt = {__index = method}

-- sysupgrade: this method call under lock protect(rcp cmd)
function method:backup()
	self:flush_nolock()
	self:backup_nolock()
	return true
end

-- close fp--backup--open fp
function method:backup_nolock()
	local cfg = self.cfg

	self:fini_log()
	local cmd = string.format("%s backup %s %s", shpath, cfg:disk_dir(), cfg:work_dir())
	local ret, err = os.execute(cmd)
	self:init_log()
	local _ = (ret == true or ret == 0) or log.fatal("backup_disk fail %s %s", cmd, err)
end

function method:try_backup_nolock()
	local fp = self:get_log_fp()
	if not fp then
		return
	end

	local size, err = fp:seek("end")
	local _ = size or log.fatal("seek fail")
	if size < self.cfg:get("max_log_size") then
		print("try_backup_nolock size < max_log_size：", size, self.cfg:get("max_log_size"))
		return
	end

	self:backup_nolock()
	log.debug("back up for log.bin recach max_log_size:%d >= %d", size, self.cfg:get("max_log_size"))
end

function method:init_log()
	local fp, err = io.open(self.cfg:get_logpath(), "a")
	local _ = fp or log.fatal("open log fail %s", err)
	self.fp = fp
end

function method:fini_log()
	local fp = self.fp
	if not fp then
		fp:close()
	end
	self.fp = nil
end

function method:get_log_fp()
	if not self.fp then
		self:init_log()
	end
	return self.fp
end

-- logs lost tolerated, no need to keep all logs
function method:flush_nolock()
	local fp = self:get_log_fp()
	if not fp then
		return
	end

	local sqlarr = self.sql_cache
	self.sql_cache = {}
	if #sqlarr > 0 then
		local arr = {}
		for _, sql in ipairs(sqlarr) do
			table.insert(arr, rdsparser.encode({rdsparser.hex(sql), sql}))
		end
		local ret, err = fp:write(table.concat(arr))
		local _ = ret or log.fatal("write fail %s", err)
		fp:flush()
	end
end

-- this method call under lock protect(rcp cmd)
function method:save_log(v, force_flush)
	if type(v) == "string" then
		table.insert(self.sql_cache, v)
	else
		for _, sql in pairs(v) do
			table.insert(self.sql_cache, sql)
		end
	end
	local _ = (force_flush or #self.sql_cache >= self.cfg:get("cache_log_count")) and self:flush_nolock()
end

-- flush and try backup if need backup
local function timeout_save(ins)
	local copas = require("copas")
	local cache_log_timeout = ins.cfg:get("cache_log_timeout") 		assert(cache_log_timeout)
	while true do
		while ins.sleep_count < cache_log_timeout do
			ins.sleep_count = ins.sleep_count + 1, copas.sleep(1)
		end

		-- try best to get lock
		if bklock.lock(cache_log_timeout) then
			ins:flush_nolock()
			ins:try_backup_nolock()
			bklock.unlock()
		end
		ins.sleep_count  = 0
	end
end

function method:prepare()
	local copas = require("copas")
	copas.addthread(timeout_save, self)
	log.debug("init update log ok")
end

local function new(cfg)
	local obj = {cfg = cfg, sql_cache = {}, sleep_count = 0, fp = nil}
	setmetatable(obj, mt)
	return obj
end

return {new = new}

