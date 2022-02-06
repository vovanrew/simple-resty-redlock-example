-- seq 1 10 | xargs -n1 -P 0 curl "http://localhost:80/increment_counter"
local redis   = require "resty.redis"
local redlock = require "Redlock"

-- simple random string number generator
local function gen_lock_id()
	local random = math.random(0, 999999999)
	return tostring(random)
end

local function increment()
	local r = redis:new()
	local ok, err = r:connect("redis", 6379)

	if not ok then
		return nil, err
	end
	
	local res, err = r:get("counter")
	if not res then
		return nil, err
	end

	local counter
	if res == ngx.null then
		counter = 0
	else
		counter = res
	end

	counter = counter + 1
	
	res, err = r:set("counter", counter)
	if not res then
		return nil, err
	end

	return counter
end

-- lock
local lock_id = gen_lock_id()
local lock_res, err = redlock.lock(lock_id, "counter")
if not lock_res then
	ngx.status = ngx.HTTP_BAD_REQUEST
	ngx.say("couldnt lock resource: " .. err)
	return
end

-- increment
local counter = increment()

-- unlock
lock_res, err = redlock.unlock(lock_id, "counter")
if not lock_res then
	ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
	ngx.say("couldn't unlock resource: " .. err)
	return
end

ngx.status = ngx.HTTP_OK
ngx.say("counter incremented: " .. tostring(counter))

