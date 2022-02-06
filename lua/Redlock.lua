local redis = require "resty.redis"

-- lock expiry milliseconds
local TTL = 10000

-- lua script to be executed by redis
-- for more detaild read https://redis.io/commands/eval
local UNLOCK_SCRIPT = [[
    if redis.call("get", KEYS[1]) == ARGV[1] then
        return redis.call("del", KEYS[1])
    else
        return 0
    end
]]

local function get_lock_key(resource)
	return "lock:" .. resource
end

local function lock(lock_id, resource, retry)
	local r = redis:new()
	local ok, err = r:connect("redis", 6379)

	if not ok then
		return nil, err
	end

	local lock_key = get_lock_key(resource)
	local res, err = r:set(lock_key, lock_id, "NX", "PX", TTL)

	if res == ngx.null then
		return nil, "resource locked"
	end

	return res, err
end

local function unlock(lock_id, resource)
	local r = redis:new()
	local ok, err = r:connect("redis", 6379)

	if not ok then
		return nil, err
	end

	local lock_key = get_lock_key(resource)
	local res, err = r:eval(UNLOCK_SCRIPT, 1, lock_key, lock_id)

	return res, err
end

return {
	lock = lock,
	unlock = unlock
}

