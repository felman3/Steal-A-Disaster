--[[
	Util — small pure helpers shared by server, client and tests.
]]

local Util = {}

function Util.clamp(x, lo, hi)
	if x < lo then
		return lo
	end
	if x > hi then
		return hi
	end
	return x
end

function Util.lerp(a, b, t)
	return a + (b - a) * t
end

function Util.round(x)
	return math.floor(x + 0.5)
end

function Util.isFiniteNumber(x)
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1234 -> "1.23K", 15 -> "15", 2500000 -> "2.5M"
function Util.formatNumber(n)
	if not Util.isFiniteNumber(n) then
		return "0"
	end
	local negative = n < 0
	if negative then
		n = -n
	end
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n = n / 1000
		i = i + 1
	end
	local s
	if i == 1 then
		s = tostring(math.floor(n))
	elseif n >= 100 then
		s = string.format("%.0f", math.floor(n))
	elseif n >= 10 then
		s = string.format("%.1f", math.floor(n * 10) / 10)
	else
		s = string.format("%.2f", math.floor(n * 100) / 100)
	end
	-- strip trailing zeros after a decimal point ("2.50" -> "2.5", "3.0" -> "3")
	if string.find(s, "%.") then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return (negative and "-" or "") .. s .. SUFFIXES[i]
end

function Util.formatMoney(n)
	return "$" .. Util.formatNumber(n)
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function Util.formatTime(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

function Util.deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = Util.deepCopy(v)
	end
	return out
end

function Util.count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

function Util.find(list, value)
	for i, v in ipairs(list) do
		if v == value then
			return i
		end
	end
	return nil
end

-- Roblox-only: convert a {r,g,b} config array into a Color3.
function Util.rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

return Util
