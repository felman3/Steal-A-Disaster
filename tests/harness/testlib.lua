-- Minimal BDD test library for the headless harness.
local T = { results = {}, current = nil }

local suiteStack = {}

function T.describe(name, fn)
	table.insert(suiteStack, name)
	fn()
	table.remove(suiteStack)
end

local function fmt(v)
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

function T.it(name, fn)
	local full = table.concat(suiteStack, " > ") .. " > " .. name
	local ok, err = xpcall(fn, function(e)
		return tostring(e) .. "\n" .. debug.traceback("", 2)
	end)
	table.insert(T.results, { name = full, ok = ok, err = err })
end

local Expect = {}
Expect.__index = Expect

-- Jest-style: expect(x).toBe(y)  (methods are bound, use a dot)
function T.expect(v)
	local holder = { v = v }
	local obj = {}
	for name, fn in pairs(Expect) do
		if type(fn) == "function" then
			obj[name] = function(...)
				local r = fn(holder, ...) -- not a tail call: keeps the spec frame for error levels
				return r
			end
		end
	end
	return obj
end

local function fail(msg)
	error(msg, 4)
end

function Expect:toBe(x)
	if self.v ~= x then
		fail("expected " .. fmt(self.v) .. " to be " .. fmt(x))
	end
end
function Expect:never(x)
	if self.v == x then
		fail("expected value to not be " .. fmt(x))
	end
end
function Expect:toEqual(x)
	local function eq(a, b)
		if type(a) ~= type(b) then
			return false
		end
		if type(a) ~= "table" then
			return a == b
		end
		for k, v in pairs(a) do
			if not eq(v, b[k]) then
				return false
			end
		end
		for k in pairs(b) do
			if a[k] == nil then
				return false
			end
		end
		return true
	end
	if not eq(self.v, x) then
		fail("tables not equal")
	end
end
function Expect:toBeTruthy()
	if not self.v then
		fail("expected truthy, got " .. fmt(self.v))
	end
end
function Expect:toBeFalsy()
	if self.v then
		fail("expected falsy, got " .. fmt(self.v))
	end
end
function Expect:toBeNil()
	if self.v ~= nil then
		fail("expected nil, got " .. fmt(self.v))
	end
end
function Expect:toBeNear(x, eps)
	eps = eps or 1e-6
	if type(self.v) ~= "number" or math.abs(self.v - x) > eps then
		fail("expected " .. fmt(self.v) .. " to be near " .. fmt(x) .. " (+-" .. eps .. ")")
	end
end
function Expect:toBeGreaterThan(x)
	if not (self.v > x) then
		fail("expected " .. fmt(self.v) .. " > " .. fmt(x))
	end
end
function Expect:toBeAtLeast(x)
	if not (self.v >= x) then
		fail("expected " .. fmt(self.v) .. " >= " .. fmt(x))
	end
end
function Expect:toBeLessThan(x)
	if not (self.v < x) then
		fail("expected " .. fmt(self.v) .. " < " .. fmt(x))
	end
end
function Expect:toBeAtMost(x)
	if not (self.v <= x) then
		fail("expected " .. fmt(self.v) .. " <= " .. fmt(x))
	end
end
function Expect:toThrow()
	local ok = pcall(self.v)
	if ok then
		fail("expected function to throw")
	end
end
function Expect:toContain(x)
	if type(self.v) == "string" then
		if not string.find(self.v, x, 1, true) then
			fail("expected " .. fmt(self.v) .. " to contain " .. fmt(x))
		end
		return
	end
	for _, v in ipairs(self.v) do
		if v == x then
			return
		end
	end
	fail("expected list to contain " .. fmt(x))
end

return T
