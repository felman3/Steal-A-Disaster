--[[
	RateLimiter — token bucket per key. `clock` is injectable for tests.
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(ratePerSecond, burst, clock)
	local self = setmetatable({}, RateLimiter)
	self.rate = ratePerSecond
	self.burst = burst
	self.clock = clock or os.clock
	self.buckets = {}
	return self
end

function RateLimiter:allow(key)
	local now = self.clock()
	local b = self.buckets[key]
	if not b then
		b = { tokens = self.burst, t = now }
		self.buckets[key] = b
	end
	b.tokens = math.min(self.burst, b.tokens + (now - b.t) * self.rate)
	b.t = now
	if b.tokens >= 1 then
		b.tokens = b.tokens - 1
		return true
	end
	return false
end

function RateLimiter:reset(key)
	self.buckets[key] = nil
end

return RateLimiter
