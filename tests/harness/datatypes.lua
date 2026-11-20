-- Roblox datatype mocks for the headless harness (Lua 5.4).
-- Vector3, Vector2, CFrame, Color3, UDim, UDim2, Enum, NumberRange,
-- NumberSequence, ColorSequence, TweenInfo, Font, Random, RaycastParams, etc.

local D = {}

local function typed(name, mt)
	mt.__type = name
	mt.__index = mt.__index or mt
	return mt
end

---------------------------------------------------------------------------
-- Vector3
---------------------------------------------------------------------------
local V3 = {}
V3.__type = "Vector3"
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3.__index = function(v, k)
	if k == "x" then
		return rawget(v, "X")
	elseif k == "y" then
		return rawget(v, "Y")
	elseif k == "z" then
		return rawget(v, "Z")
	elseif k == "Magnitude" or k == "magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" or k == "unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			return v3(0 / 0, 0 / 0, 0 / 0)
		end
		return v3(v.X / m, v.Y / m, v.Z / m)
	end
	local m = rawget(V3, k)
	if m ~= nil then
		return m
	end
	error(tostring(k) .. " is not a valid member of Vector3", 2)
end
V3.__newindex = function()
	error("Vector3 is immutable", 2)
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	if getmetatable(a) ~= V3 or getmetatable(b) ~= V3 then
		return false
	end
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(a)
	return string.format("%g, %g, %g", a.X, a.Y, a.Z)
end
function V3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3.Lerp(a, b, t)
	return a + (b - a) * t
end
function V3.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	return math.abs(a.X - b.X) <= eps and math.abs(a.Y - b.Y) <= eps and math.abs(a.Z - b.Z) <= eps
end
function V3.Abs(a)
	return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
function V3.Min(a, b)
	return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function V3.Max(a, b)
	return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
D.Vector3 = {
	new = v3,
	zero = v3(0, 0, 0),
	one = v3(1, 1, 1),
	xAxis = v3(1, 0, 0),
	yAxis = v3(0, 1, 0),
	zAxis = v3(0, 0, 1),
}

---------------------------------------------------------------------------
-- Vector2
---------------------------------------------------------------------------
local V2 = {}
V2.__type = "Vector2"
local function v2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
V2.__index = function(v, k)
	if k == "x" then
		return rawget(v, "X")
	elseif k == "y" then
		return rawget(v, "Y")
	elseif k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y)
		return v2(v.X / m, v.Y / m)
	end
	local m = rawget(V2, k)
	if m ~= nil then
		return m
	end
	error(tostring(k) .. " is not a valid member of Vector2", 2)
end
V2.__newindex = function()
	error("Vector2 is immutable", 2)
end
V2.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if type(a) == "number" then
		return v2(b.X * a, b.Y * a)
	elseif type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then
		return v2(a.X / b, a.Y / b)
	end
	return v2(a.X / b.X, a.Y / b.Y)
end
V2.__eq = function(a, b)
	if getmetatable(a) ~= V2 or getmetatable(b) ~= V2 then
		return false
	end
	return a.X == b.X and a.Y == b.Y
end
function V2.Lerp(a, b, t)
	return a + (b - a) * t
end
D.Vector2 = { new = v2, zero = v2(0, 0), one = v2(1, 1) }

---------------------------------------------------------------------------
-- CFrame (rotation matrix rows r00..r22 + position)
---------------------------------------------------------------------------
local CF = {}
CF.__type = "CFrame"
local function cf(px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return setmetatable({
		px = px,
		py = py,
		pz = pz,
		r00 = r00 or 1,
		r01 = r01 or 0,
		r02 = r02 or 0,
		r10 = r10 or 0,
		r11 = r11 or 1,
		r12 = r12 or 0,
		r20 = r20 or 0,
		r21 = r21 or 0,
		r22 = r22 or 1,
	}, CF)
end
local function mulRot(a, b)
	return a.r00 * b.r00 + a.r01 * b.r10 + a.r02 * b.r20,
		a.r00 * b.r01 + a.r01 * b.r11 + a.r02 * b.r21,
		a.r00 * b.r02 + a.r01 * b.r12 + a.r02 * b.r22,
		a.r10 * b.r00 + a.r11 * b.r10 + a.r12 * b.r20,
		a.r10 * b.r01 + a.r11 * b.r11 + a.r12 * b.r21,
		a.r10 * b.r02 + a.r11 * b.r12 + a.r12 * b.r22,
		a.r20 * b.r00 + a.r21 * b.r10 + a.r22 * b.r20,
		a.r20 * b.r01 + a.r21 * b.r11 + a.r22 * b.r21,
		a.r20 * b.r02 + a.r21 * b.r12 + a.r22 * b.r22
end
local function rotVec(c, x, y, z)
	return c.r00 * x + c.r01 * y + c.r02 * z, c.r10 * x + c.r11 * y + c.r12 * z, c.r20 * x + c.r21 * y + c.r22 * z
end
CF.__index = function(c, k)
	if k == "Position" or k == "p" then
		return v3(c.px, c.py, c.pz)
	elseif k == "X" then
		return c.px
	elseif k == "Y" then
		return c.py
	elseif k == "Z" then
		return c.pz
	elseif k == "LookVector" or k == "lookVector" then
		return v3(-c.r02, -c.r12, -c.r22)
	elseif k == "RightVector" or k == "rightVector" then
		return v3(c.r00, c.r10, c.r20)
	elseif k == "UpVector" or k == "upVector" then
		return v3(c.r01, c.r11, c.r21)
	elseif k == "XVector" then
		return v3(c.r00, c.r10, c.r20)
	elseif k == "YVector" then
		return v3(c.r01, c.r11, c.r21)
	elseif k == "ZVector" then
		return v3(c.r02, c.r12, c.r22)
	elseif k == "Rotation" then
		return cf(0, 0, 0, c.r00, c.r01, c.r02, c.r10, c.r11, c.r12, c.r20, c.r21, c.r22)
	end
	local m = rawget(CF, k)
	if m ~= nil then
		return m
	end
	error(tostring(k) .. " is not a valid member of CFrame", 2)
end
CF.__newindex = function()
	error("CFrame is immutable", 2)
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		local x, y, z = rotVec(a, b.px, b.py, b.pz)
		return cf(a.px + x, a.py + y, a.pz + z, mulRot(a, b))
	elseif getmetatable(b) == V3 then
		local x, y, z = rotVec(a, b.X, b.Y, b.Z)
		return v3(a.px + x, a.py + y, a.pz + z)
	end
	error("bad CFrame multiplication", 2)
end
CF.__add = function(a, v)
	return cf(a.px + v.X, a.py + v.Y, a.pz + v.Z, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22)
end
CF.__sub = function(a, v)
	return cf(a.px - v.X, a.py - v.Y, a.pz - v.Z, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22)
end
CF.__eq = function(a, b)
	if getmetatable(a) ~= CF or getmetatable(b) ~= CF then
		return false
	end
	for _, k in ipairs({ "px", "py", "pz", "r00", "r01", "r02", "r10", "r11", "r12", "r20", "r21", "r22" }) do
		if rawget(a, k) ~= rawget(b, k) then
			return false
		end
	end
	return true
end
CF.__tostring = function(c)
	return string.format("CFrame(%g, %g, %g)", c.px, c.py, c.pz)
end
function CF.Inverse(c)
	-- general 3x3 inverse (not just transpose) so accumulated float drift can
	-- never compound; Roblox keeps CFrames orthonormal, so the result matches
	local a, b, cc = c.r00, c.r01, c.r02
	local d, e, f = c.r10, c.r11, c.r12
	local g, h, i = c.r20, c.r21, c.r22
	local A, B, C = e * i - f * h, -(d * i - f * g), d * h - e * g
	local det = a * A + b * B + cc * C
	if det == 0 then
		det = 1
	end
	local inv = 1 / det
	local r00, r01, r02 = A * inv, -(b * i - cc * h) * inv, (b * f - cc * e) * inv
	local r10, r11, r12 = B * inv, (a * i - cc * g) * inv, -(a * f - cc * d) * inv
	local r20, r21, r22 = C * inv, -(a * h - b * g) * inv, (a * e - b * d) * inv
	local x = -(r00 * c.px + r01 * c.py + r02 * c.pz)
	local y = -(r10 * c.px + r11 * c.py + r12 * c.pz)
	local z = -(r20 * c.px + r21 * c.py + r22 * c.pz)
	return cf(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end
function CF.PointToWorldSpace(c, v)
	return c * v
end
function CF.PointToObjectSpace(c, v)
	return CF.Inverse(c) * v
end
function CF.VectorToWorldSpace(c, v)
	return v3(rotVec(c, v.X, v.Y, v.Z))
end
function CF.VectorToObjectSpace(c, v)
	return v3(rotVec(CF.Inverse(c), v.X, v.Y, v.Z))
end
function CF.ToWorldSpace(c, o)
	return c * o
end
function CF.ToObjectSpace(c, o)
	return CF.Inverse(c) * o
end
function CF.GetComponents(c)
	return c.px, c.py, c.pz, c.r00, c.r01, c.r02, c.r10, c.r11, c.r12, c.r20, c.r21, c.r22
end
CF.components = CF.GetComponents
function CF.Lerp(a, b, t)
	-- position lerp + normalized matrix lerp (good enough for tests)
	local function l(k)
		return a[k] + (b[k] - a[k]) * t
	end
	local x = v3(l("r00"), l("r10"), l("r20")).Unit
	local y = v3(l("r01"), l("r11"), l("r21"))
	local z = x:Cross(y).Unit
	y = z:Cross(x).Unit
	return cf(l("px"), l("py"), l("pz"), x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z)
end
function CF.ToEulerAnglesXYZ(c)
	local ry = math.asin(math.max(-1, math.min(1, c.r02)))
	local rx = math.atan(-c.r12, c.r22)
	local rz = math.atan(-c.r01, c.r00)
	return rx, ry, rz
end
CF.toEulerAnglesXYZ = CF.ToEulerAnglesXYZ
function CF.ToEulerAnglesYXZ(c)
	local rx = math.asin(math.max(-1, math.min(1, -c.r12)))
	local ry = math.atan(c.r02, c.r22)
	local rz = math.atan(c.r10, c.r11)
	return rx, ry, rz
end
CF.ToOrientation = CF.ToEulerAnglesYXZ
function CF.ToAxisAngle(c)
	return v3(0, 1, 0), 0
end
function CF.Orthonormalize(c)
	return c
end
function CF.FuzzyEq(a, b, eps)
	return a.Position:FuzzyEq(b.Position, eps)
end

local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(0, 0, 0, 1, 0, 0, 0, c, -s, 0, s, c)
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(0, 0, 0, c, 0, s, 0, 1, 0, -s, 0, c)
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(0, 0, 0, c, -s, 0, s, c, 0, 0, 0, 1)
end

local function lookAt(pos, target, up)
	up = up or v3(0, 1, 0)
	local f = (target - pos)
	if f.Magnitude < 1e-9 then
		return cf(pos.X, pos.Y, pos.Z)
	end
	f = f.Unit
	local r = f:Cross(up)
	if r.Magnitude < 1e-6 then
		r = f:Cross(v3(0, 0, 1))
		if r.Magnitude < 1e-6 then
			r = f:Cross(v3(1, 0, 0))
		end
	end
	r = r.Unit
	local u = r:Cross(f).Unit
	local b = -f
	return cf(pos.X, pos.Y, pos.Z, r.X, u.X, b.X, r.Y, u.Y, b.Y, r.Z, u.Z, b.Z)
end

D.CFrame = {
	new = function(a, b, c, ...)
		if a == nil then
			return cf(0, 0, 0)
		end
		if type(a) == "number" then
			local extra = { ... }
			if #extra == 9 then
				return cf(a, b, c, table.unpack(extra))
			end
			if #extra == 4 then -- quaternion: qx,qy,qz,qw
				local qx, qy, qz, qw = extra[1], extra[2], extra[3], extra[4]
				return cf(
					a,
					b,
					c,
					1 - 2 * (qy * qy + qz * qz),
					2 * (qx * qy - qz * qw),
					2 * (qx * qz + qy * qw),
					2 * (qx * qy + qz * qw),
					1 - 2 * (qx * qx + qz * qz),
					2 * (qy * qz - qx * qw),
					2 * (qx * qz - qy * qw),
					2 * (qy * qz + qx * qw),
					1 - 2 * (qx * qx + qy * qy)
				)
			end
			return cf(a, b or 0, c or 0)
		end
		if b ~= nil then
			return lookAt(a, b)
		end
		return cf(a.X, a.Y, a.Z)
	end,
	lookAt = lookAt,
	Angles = function(x, y, z)
		return rx(x or 0) * ry(y or 0) * rz(z or 0)
	end,
	fromOrientation = function(x, y, z)
		return ry(y or 0) * rx(x or 0) * rz(z or 0)
	end,
	fromAxisAngle = function(axis, angle)
		local u = axis.Unit
		local c, s = math.cos(angle), math.sin(angle)
		local t = 1 - c
		return cf(
			0,
			0,
			0,
			t * u.X * u.X + c,
			t * u.X * u.Y - s * u.Z,
			t * u.X * u.Z + s * u.Y,
			t * u.X * u.Y + s * u.Z,
			t * u.Y * u.Y + c,
			t * u.Y * u.Z - s * u.X,
			t * u.X * u.Z - s * u.Y,
			t * u.Y * u.Z + s * u.X,
			t * u.Z * u.Z + c
		)
	end,
	fromMatrix = function(pos, vx, vy, vz)
		vz = vz or vx:Cross(vy)
		return cf(pos.X, pos.Y, pos.Z, vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z)
	end,
	identity = cf(0, 0, 0),
}
D.CFrame.fromEulerAnglesXYZ = D.CFrame.Angles
D.CFrame.fromEulerAnglesYXZ = D.CFrame.fromOrientation
D.CFrame.fromEulerAngles = D.CFrame.Angles

---------------------------------------------------------------------------
-- Color3
---------------------------------------------------------------------------
local C3 = {}
C3.__type = "Color3"
local function c3(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
end
C3.__index = function(c, k)
	local m = rawget(C3, k)
	if m ~= nil then
		return m
	end
	if k == "r" then
		return rawget(c, "R")
	elseif k == "g" then
		return rawget(c, "G")
	elseif k == "b" then
		return rawget(c, "B")
	end
	error(tostring(k) .. " is not a valid member of Color3", 2)
end
C3.__newindex = function()
	error("Color3 is immutable", 2)
end
C3.__eq = function(a, b)
	if getmetatable(a) ~= C3 or getmetatable(b) ~= C3 then
		return false
	end
	return a.R == b.R and a.G == b.G and a.B == b.B
end
function C3.Lerp(a, b, t)
	return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function C3.ToHSV(c)
	local r, g, b = c.R, c.G, c.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local h, s, v = 0, 0, mx
	local d = mx - mn
	if mx ~= 0 then
		s = d / mx
	end
	if d ~= 0 then
		if mx == r then
			h = (g - b) / d % 6
		elseif mx == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h = h / 6
	end
	return h, s, v
end
function C3.ToHex(c)
	return string.format("%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end
local function checkRGB(...)
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if type(v) ~= "number" then
			error("Color3.fromRGB expects numbers", 3)
		end
	end
end
D.Color3 = {
	new = c3,
	fromRGB = function(r, g, b)
		checkRGB(r, g, b)
		return c3(r / 255, g / 255, b / 255)
	end,
	fromHSV = function(h, s, v)
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		i = i % 6
		if i == 0 then
			return c3(v, t, p)
		elseif i == 1 then
			return c3(q, v, p)
		elseif i == 2 then
			return c3(p, v, t)
		elseif i == 3 then
			return c3(p, q, v)
		elseif i == 4 then
			return c3(t, p, v)
		end
		return c3(v, p, q)
	end,
	fromHex = function(hex)
		hex = hex:gsub("#", "")
		return c3(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255)
	end,
}

---------------------------------------------------------------------------
-- UDim / UDim2
---------------------------------------------------------------------------
local UD = typed("UDim", {})
local function udim(s, o)
	return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD)
end
UD.__add = function(a, b)
	return udim(a.Scale + b.Scale, a.Offset + b.Offset)
end
D.UDim = { new = udim }

local UD2 = {}
UD2.__type = "UDim2"
local function udim2(xs, xo, ys, yo)
	return setmetatable({ X = udim(xs, xo), Y = udim(ys, yo) }, UD2)
end
UD2.__index = function(u, k)
	if k == "Width" then
		return rawget(u, "X")
	elseif k == "Height" then
		return rawget(u, "Y")
	end
	local m = rawget(UD2, k)
	if m ~= nil then
		return m
	end
	error(tostring(k) .. " is not a valid member of UDim2", 2)
end
UD2.__add = function(a, b)
	return udim2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UD2.__sub = function(a, b)
	return udim2(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
end
UD2.__eq = function(a, b)
	if getmetatable(a) ~= UD2 or getmetatable(b) ~= UD2 then
		return false
	end
	return a.X.Scale == b.X.Scale and a.X.Offset == b.X.Offset and a.Y.Scale == b.Y.Scale and a.Y.Offset == b.Y.Offset
end
function UD2.Lerp(a, b, t)
	return udim2(
		a.X.Scale + (b.X.Scale - a.X.Scale) * t,
		a.X.Offset + (b.X.Offset - a.X.Offset) * t,
		a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t,
		a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t
	)
end
D.UDim2 = {
	new = function(a, b, c, d)
		if type(a) == "table" then
			return udim2(a.Scale, a.Offset, b.Scale, b.Offset)
		end
		return udim2(a, b, c, d)
	end,
	fromScale = function(x, y)
		return udim2(x, 0, y, 0)
	end,
	fromOffset = function(x, y)
		return udim2(0, x, 0, y)
	end,
}

---------------------------------------------------------------------------
-- Misc value types
---------------------------------------------------------------------------
local function simpleType(name, ctor)
	local mt = typed(name, {})
	return function(...)
		return setmetatable(ctor(...), mt)
	end
end

D.NumberRange = {
	new = simpleType("NumberRange", function(a, b)
		return { Min = a, Max = b or a }
	end),
}
D.NumberSequenceKeypoint = {
	new = simpleType("NumberSequenceKeypoint", function(t, v, e)
		return { Time = t, Value = v, Envelope = e or 0 }
	end),
}
D.NumberSequence = {
	new = simpleType("NumberSequence", function(a, b)
		if type(a) == "table" then
			for _, kp in ipairs(a) do
				if type(kp) ~= "table" or kp.Time == nil then
					error("NumberSequence.new expects keypoints", 3)
				end
			end
			return { Keypoints = a }
		end
		return { Keypoints = { { Time = 0, Value = a }, { Time = 1, Value = b or a } } }
	end),
}
D.ColorSequenceKeypoint = {
	new = simpleType("ColorSequenceKeypoint", function(t, c)
		if getmetatable(c) ~= C3 then
			error("ColorSequenceKeypoint expects Color3", 3)
		end
		return { Time = t, Value = c }
	end),
}
D.ColorSequence = {
	new = simpleType("ColorSequence", function(a, b)
		if getmetatable(a) == C3 then
			return { Keypoints = { { Time = 0, Value = a }, { Time = 1, Value = b or a } } }
		end
		if type(a) ~= "table" then
			error("ColorSequence.new expects Color3 or keypoints", 3)
		end
		return { Keypoints = a }
	end),
}
D.TweenInfo = {
	new = simpleType("TweenInfo", function(t, style, dir, repeatCount, reverses, delay)
		return {
			Time = t or 1,
			EasingStyle = style,
			EasingDirection = dir,
			RepeatCount = repeatCount or 0,
			Reverses = reverses or false,
			DelayTime = delay or 0,
		}
	end),
}
D.PhysicalProperties = {
	new = simpleType("PhysicalProperties", function(d, f, e, fw, ew)
		return { Density = d, Friction = f, Elasticity = e, FrictionWeight = fw, ElasticityWeight = ew }
	end),
}
D.Rect = {
	new = simpleType("Rect", function(a, b, c, d)
		return { MinX = a, MinY = b, MaxX = c, MaxY = d }
	end),
}
D.Ray = {
	new = simpleType("Ray", function(o, d)
		return { Origin = o, Direction = d }
	end),
}
D.RaycastParams = {
	new = simpleType("RaycastParams", function()
		return { FilterDescendantsInstances = {}, FilterType = nil, IgnoreWater = false }
	end),
}
D.OverlapParams = {
	new = simpleType("OverlapParams", function()
		return { FilterDescendantsInstances = {}, FilterType = nil, MaxParts = 0 }
	end),
}
D.BrickColor = {
	new = simpleType("BrickColor", function(name)
		return { Name = tostring(name), Color = c3(0.5, 0.5, 0.5) }
	end),
}

---------------------------------------------------------------------------
-- Enum: any Enum.X.Y resolves to a cached EnumItem.
---------------------------------------------------------------------------
local enumItemMt = { __type = "EnumItem" }
enumItemMt.__index = enumItemMt
enumItemMt.__tostring = function(e)
	return "Enum." .. e.EnumType .. "." .. e.Name
end
local enumTypes = {}
local function enumType(typeName)
	if enumTypes[typeName] then
		return enumTypes[typeName]
	end
	local items = {}
	local et = setmetatable({}, {
		__type = "Enum",
		__index = function(_, itemName)
			if itemName == "GetEnumItems" then
				return function()
					local out = {}
					for _, v in pairs(items) do
						table.insert(out, v)
					end
					return out
				end
			end
			if not items[itemName] then
				items[itemName] = setmetatable({ Name = itemName, EnumType = typeName, Value = 0 }, enumItemMt)
			end
			return items[itemName]
		end,
	})
	enumTypes[typeName] = et
	return et
end
D.Enum = setmetatable({}, {
	__index = function(_, typeName)
		return enumType(typeName)
	end,
})

D.Font = {
	new = simpleType("Font", function(family, weight, style)
		return { Family = family, Weight = weight, Style = style, Bold = false }
	end),
	fromEnum = simpleType("Font", function(e)
		return { Family = tostring(e), Bold = false }
	end),
	fromName = simpleType("Font", function(n, weight, style)
		return { Family = n, Weight = weight, Style = style, Bold = false }
	end),
}

---------------------------------------------------------------------------
-- Random (deterministic LCG; seedable)
---------------------------------------------------------------------------
local RandomMt = typed("Random", {})
function RandomMt:NextNumber(a, b)
	self.state = (self.state * 1103515245 + 12345) % 2147483648
	local f = self.state / 2147483648
	if a then
		return a + (b - a) * f
	end
	return f
end
function RandomMt:NextInteger(a, b)
	return a + math.floor(self:NextNumber() * (b - a + 1))
end
function RandomMt:Shuffle(t)
	for i = #t, 2, -1 do
		local j = self:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
end
D.Random = {
	new = function(seed)
		return setmetatable({ state = math.floor(seed or 1234567) % 2147483648 }, RandomMt)
	end,
}

-- typeof
function D.typeof(v)
	local t = type(v)
	if t == "table" or t == "userdata" then
		local mt = getmetatable(v)
		if type(mt) == "table" and mt.__type then
			return mt.__type
		end
	end
	return t
end

return D
