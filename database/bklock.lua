-- author@tgb

local LOCK, UNLOCK = true, false
local singleton = UNLOCK

local function lock(timeout)
	local copas = require("copas")
	local wait = timeout and tonumber(timeout) or 10
	local tick_intval, tick_total = 0.01, 100 * wait
	local tick_count = 0

	while tick_count < tick_total do
		if singleton == UNLOCK then
			singleton = LOCK
			return true
		end
		copas.sleep(tick_intval)
		tick_count = tick_count + 1
	end

	if singleton == LOCK then
		return false
	end

	return true
end

local function try_lock()
	if singleton == UNLOCK then
		singleton = LOCK
		return true
	end

	return false
end

local function unlock()
	if singleton == LOCK then
		singleton = UNLOCK
	end
	return true
end

return {lock = lock, try_lock = try_lock, unlock = unlock}