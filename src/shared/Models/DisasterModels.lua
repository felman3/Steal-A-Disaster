--[[
	DisasterModels — builds the hatched disaster collectibles that sit on the
	display pedestals.

	Every disaster is a cute-but-dangerous mini creature built from plain parts.
	`def.archetype` picks the silhouette (Vortex funnel, puffy Cloud, anvil
	StormCloud, blocky Golem, S-curve Serpent, four-legged Beast, flame Wisp,
	ground Maw, cone Volcano, flaming Meteor, curling Wave, spread-wing Bird,
	floating Entity, BlackHole), and per-id tweaks make disasters that share an
	archetype read differently (debris, horns, tails, crests, palettes...).

	Model contract:
	  * returns a Model whose PrimaryPart "Root" (invisible) sits at the origin;
	    the bottom of the model is at y = 0 (it stands on a pedestal top), the
	    face looks toward -Z
	  * all parts anchored, non-colliding, CanTouch false
	  * height is set by rarity (Common ~4.6 studs ... Mythic ~8.6 studs)
	  * attributes: DisasterId, Rarity, Mutation (if any), AnimBob, AnimSpin;
	    parts may carry Orbit / SelfSpin (rad/s) for the client animator
]]

local Config = require(script.Parent.Parent.Config.GameConfig)
local Kit = require(script.Parent.Kit)

local DisasterModels = {}

local M = Enum.Material
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local PI = math.pi

local INK = { 22, 20, 30 }
local WHITE = { 255, 255, 255 }
local IVORY = { 245, 238, 220 }
local BLUSH = { 255, 140, 170 }

-- Target model height (studs) per rarity.
DisasterModels.Heights = {
	Common = 4.6,
	Uncommon = 5.3,
	Rare = 6.0,
	Epic = 6.7,
	Legendary = 7.6,
	Mythic = 8.6,
	Chaos = 8.9,
}

---------------------------------------------------------------------------
-- Part helpers (all non-colliding; positions are design-space and get
-- normalized to the rarity height afterwards)
---------------------------------------------------------------------------
local function toCF(at)
	if typeof(at) == "Vector3" then
		return CF(at)
	end
	return at or CF()
end

local function part(m, name, size, at, color, mat, tr, shape)
	return Kit.part(m, {
		name = name,
		size = size,
		cf = toCF(at),
		color = color,
		material = mat or M.SmoothPlastic,
		transparency = tr,
		shape = shape,
		collide = false,
	})
end

local function ball(m, name, d, at, color, mat, tr)
	return Kit.ball(m, { name = name, diameter = d, cf = toCF(at), color = color, material = mat or M.SmoothPlastic, transparency = tr, collide = false })
end

local function cyl(m, name, h, d, at, color, mat, tr)
	return Kit.cylinder(m, { name = name, height = h, diameter = d, cf = toCF(at), color = color, material = mat or M.SmoothPlastic, transparency = tr, collide = false })
end

-- Block spanning a -> b. Cross-section is w (local X) by wz (local Y).
local function seg(m, name, a, b, w, color, mat, tr, wz)
	local len = math.max((b - a).Magnitude, 0.05)
	return part(m, name, V(w, wz or w, len), CFrame.lookAt((a + b) / 2, b), color, mat, tr)
end

-- Round limb (cylinder) spanning a -> b.
local function rod(m, name, a, b, d, color, mat, tr)
	local len = math.max((b - a).Magnitude, 0.05)
	return part(m, name, V(len, d, d), CFrame.lookAt((a + b) / 2, b) * ANG(0, PI / 2, 0), color, mat, tr, "Cylinder")
end

local function orbit(p, speed)
	p:SetAttribute("Orbit", speed)
	return p
end

local function selfSpin(p, speed)
	p:SetAttribute("SelfSpin", speed)
	return p
end

-- Zig-zag chain of neon segments through `pts`.
local function bolt(m, pts, w, color)
	for i = 1, #pts - 1 do
		seg(m, "Bolt", pts[i], pts[i + 1], w, color, M.Neon)
	end
end

-- Front-surface z of a ball (for placing faces on round bodies).
local function ballZ(center, r)
	return function(y, x)
		local dx, dy = (x or 0) - center.X, y - center.Y
		return center.Z - math.sqrt(math.max(0, r * r - dx * dx - dy * dy))
	end
end

local function surfaceZ(z, y, x)
	if type(z) == "function" then
		return z(y, x)
	end
	return z
end

local function mouth(m, kind, pos, w, glow)
	if kind == "smile" then
		part(m, "Mouth", V(w, w * 0.16, w * 0.18), pos, INK)
		for s = -1, 1, 2 do
			part(m, "Mouth", V(w * 0.16, w * 0.32, w * 0.18), pos + V(s * w * 0.5, w * 0.1, 0), INK)
		end
	elseif kind == "o" then
		ball(m, "Mouth", w * 0.42, pos, INK)
	elseif kind == "fangs" then
		part(m, "Mouth", V(w, w * 0.26, w * 0.18), pos, INK)
		for s = -1, 1, 2 do
			part(m, "Tooth", V(w * 0.18, w * 0.18, w * 0.1), CF(pos + V(s * w * 0.28, -w * 0.13, -w * 0.07)) * ANG(0, 0, PI / 4), WHITE)
		end
	elseif kind == "grin" then
		part(m, "Mouth", V(w, w * 0.3, w * 0.18), pos, INK)
		part(m, "Tooth", V(w * 0.86, w * 0.1, w * 0.1), pos + V(0, w * 0.08, -w * 0.06), WHITE)
	elseif kind == "maw" then
		part(m, "Mouth", V(w, w * 0.36, w * 0.18), pos, INK)
		part(m, "MouthGlow", V(w * 0.7, w * 0.1, w * 0.1), pos + V(0, -w * 0.05, -w * 0.06), glow or { 255, 160, 60 }, M.Neon)
		for s = -1, 1, 2 do
			part(m, "Tooth", V(w * 0.16, w * 0.16, w * 0.1), CF(pos + V(s * w * 0.3, w * 0.16, -w * 0.07)) * ANG(0, 0, PI / 4), WHITE)
		end
	elseif kind == "line" then
		part(m, "Mouth", V(w, w * 0.12, w * 0.16), pos, INK)
	elseif kind == "glowline" then
		part(m, "Mouth", V(w, w * 0.1, w * 0.12), pos, glow or WHITE, M.Neon)
	end
end

--[[
	face(m, {
		y, d (eye diameter), gap (eye x offset), x = 0,
		z = number | function(y, x) -> front surface z,
		glow = color (glowing eyes) | nil (black eyes), shine = bool,
		brows = angle | nil, browColor, blush = color,
		mouth = "smile"|"o"|"fangs"|"grin"|"maw"|"line"|"glowline",
		mouthY, mouthZ, mouthW, mouthGlow,
	})
]]
local function face(m, o)
	local d, gap, x0, y = o.d, o.gap, o.x or 0, o.y
	for s = -1, 1, 2 do
		local ex = x0 + s * gap
		local p = V(ex, y, surfaceZ(o.z, y, ex) - d * 0.12)
		if o.glow then
			ball(m, "Eye", d, p, o.glow, M.Neon)
		else
			ball(m, "Eye", d, p, INK)
		end
		if o.shine ~= false then
			ball(m, "EyeShine", d * 0.36, p + V(d * 0.18, d * 0.2, -d * 0.34), WHITE, M.Neon)
		end
		if o.brows then
			local by = y + d * 0.74
			local bz = surfaceZ(o.z, by, ex) - d * 0.2
			part(m, "Brow", V(d * 1.1, d * 0.24, d * 0.32), CF(ex - s * d * 0.05, by, bz) * ANG(0, 0, s * o.brows), o.browColor or INK)
		end
		if o.blush then
			local bx = ex + s * d * 0.55
			local byy = y - d * 0.66
			part(m, "Blush", V(d * 0.62, d * 0.26, d * 0.1), V(bx, byy, surfaceZ(o.z, byy, bx) - d * 0.03), o.blush)
		end
	end
	if o.mouth then
		local my = o.mouthY or (y - d * 0.95)
		local mz = o.mouthZ or (surfaceZ(o.z, my, x0) - d * 0.06)
		mouth(m, o.mouth, V(x0, my, mz), o.mouthW or gap * 1.25, o.mouthGlow)
	end
end

---------------------------------------------------------------------------
-- Bounds / normalization
---------------------------------------------------------------------------
local function partExtent(p)
	local cf, s = p.CFrame, p.Size
	if p:IsA("Part") and p.Shape == Enum.PartType.Ball then
		local r = math.min(s.X, s.Y, s.Z) / 2
		return V(r, r, r)
	end
	local rv, uv, zv = cf.RightVector, cf.UpVector, cf.LookVector
	if p:IsA("Part") and p.Shape == Enum.PartType.Cylinder then
		local hx, r = s.X / 2, math.min(s.Y, s.Z) / 2
		local function ax(a)
			return math.abs(a) * hx + r * math.sqrt(math.max(0, 1 - a * a))
		end
		return V(ax(rv.X), ax(rv.Y), ax(rv.Z))
	end
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	return V(
		math.abs(rv.X) * hx + math.abs(uv.X) * hy + math.abs(zv.X) * hz,
		math.abs(rv.Y) * hx + math.abs(uv.Y) * hy + math.abs(zv.Y) * hz,
		math.abs(rv.Z) * hx + math.abs(uv.Z) * hy + math.abs(zv.Z) * hz
	)
end

-- World-space AABB of every BasePart except `skip` (rotation aware).
local function bounds(m, skip)
	local lo, hi
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d ~= skip then
			local e = partExtent(d)
			local pos = d.CFrame.Position
			local a, b = pos - e, pos + e
			lo = lo and lo:Min(a) or a
			hi = hi and hi:Max(b) or b
		end
	end
	return lo or Vector3.zero, hi or Vector3.zero
end
DisasterModels.bounds = bounds

-- Uniformly scale the design about the vertical axis so it is `targetH` tall
-- (or `maxW` wide, whichever is smaller) with its bottom at y = 0.
local function normalize(m, root, targetH, maxW)
	local lo, hi = bounds(m, root)
	local h = math.max(hi.Y - lo.Y, 0.1)
	local w = math.max(hi.X - lo.X, hi.Z - lo.Z, 0.1)
	local s = targetH / h
	if maxW and w * s > maxW then
		s = maxW / w
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			local cf = d.CFrame
			local pos = cf.Position
			d.Size = d.Size * s
			d.CFrame = CF(pos.X * s, (pos.Y - lo.Y) * s, pos.Z * s) * cf.Rotation
		elseif d:IsA("PointLight") then
			d.Range = d.Range * s
		end
	end
	return bounds(m, root)
end

---------------------------------------------------------------------------
-- Archetype builders: builder(m, c, id) -> { bob = studs, spin = rad/s }
---------------------------------------------------------------------------
local A = {}

-- Stacked cylinder funnel. Returns the layer list { {y, d}, ... }.
local function funnel(m, o)
	local layers = {}
	for i = 1, o.layers do
		local t = (i - 1) / (o.layers - 1)
		local d = o.baseD + (o.topD - o.baseD) * (t ^ (o.curve or 1.5))
		local y = o.startY + (i - 1) * o.step
		local a = i * 1.7
		local wob = o.wobble or 0.1
		local p = cyl(m, "Layer", o.layerH, d, V(math.cos(a) * wob, y, math.sin(a) * wob), o.color(i, t), o.material(i), o.transparency or 0.08)
		orbit(p, o.speed(i, t))
		layers[i] = { y = y, d = d }
	end
	return layers
end

local function funnelZ(layers, layerH)
	return function(y)
		local r = 0
		for _, l in ipairs(layers) do
			if math.abs(y - l.y) <= layerH / 2 + 0.02 then
				r = math.max(r, l.d / 2)
			end
		end
		if r == 0 then
			r = layers[1].d / 2
		end
		return -r
	end
end

-- Maelstrom: a whirlpool funnel opening upward, with a foam rim and a dark eye.
local function maelstrom(m, c)
	local water, foam, glow = c[1], c[2], c[3]
	local deep = Kit.shade(water, 0.35)
	cyl(m, "Pool", 0.3, 3.8, V(0, 0.15, 0), water, M.Glass, 0.25)
	for i = 1, 4 do
		local a = i / 4 * PI * 2 + 0.4
		orbit(ball(m, "Splash", 0.5, V(math.cos(a) * 1.75, 0.32, math.sin(a) * 1.75), foam), 0.8)
	end
	local layerH = 0.7
	local layers = {}
	for i = 1, 6 do
		local t = (i - 1) / 5
		local d = 0.9 + 3.3 * (t ^ 1.2)
		local y = 0.55 + (i - 1) * 0.6
		local p = cyl(m, "Layer", layerH, d, V(0, y, 0), Kit.mix(deep, water, 0.35 + t * 0.65), M.Glass, 0.18)
		orbit(p, -(3.6 - 2 * t))
		layers[i] = { y = y, d = d }
	end
	local topY = layers[6].y + layerH / 2
	local topD = layers[6].d
	cyl(m, "Eye", 0.1, topD * 0.82, V(0, topY + 0.02, 0), deep)
	cyl(m, "Whirl", 0.12, 0.9, V(0, topY + 0.05, 0), glow, M.Neon)
	for i = 1, 3 do
		local a = i / 3 * PI * 2
		local p = part(m, "Streak", V(0.15, 0.06, 1.2), CF(math.cos(a) * 0.95, topY + 0.07, math.sin(a) * 0.95) * ANG(0, -a, 0), foam)
		orbit(p, -2.6)
	end
	for i = 1, 8 do
		local a = i / 8 * PI * 2
		orbit(ball(m, "Foam", 0.6, V(math.cos(a) * topD / 2, topY, math.sin(a) * topD / 2), foam), -1.2)
	end
	face(m, { y = 2.75, d = 0.55, gap = 0.45, z = funnelZ(layers, layerH), brows = 0.3, browColor = deep, mouth = "fangs" })
	Kit.particles(m:FindFirstChild("Whirl"), { color = foam, size = 0.35, rate = 8, speed = 1.5, lifetime = 1, spread = 40, accel = V(0, 2, 0) })
	return { bob = 0.1, spin = 0 }
end

function A.Vortex(m, c, id)
	if id == "Maelstrom" then
		return maelstrom(m, c)
	end
	local chaos = id == "ChaosStorm"
	local sandy = id == "DustDevil" or id == "Sandstorm"
	local wide = id == "Sandstorm"
	local layerH = 0.75
	local layers = funnel(m, {
		layers = 7,
		baseD = wide and 0.9 or 0.55,
		topD = wide and 4.4 or 3.7,
		layerH = layerH,
		startY = 0.38,
		step = 0.62,
		wobble = 0.1,
		color = function(i, t)
			if chaos then
				return c[(i - 1) % 3 + 1]
			end
			return Kit.mix(c[2], c[1], 0.3 + t * 0.7)
		end,
		material = function(i)
			if chaos then
				return (i % 2 == 0) and M.Neon or M.Glass
			end
			if sandy then
				return M.Sand
			end
			return M.SmoothPlastic
		end,
		transparency = chaos and 0.15 or 0.06,
		speed = function(i, t)
			local s = 4.2 - t * 2.4
			if chaos and i % 2 == 0 then
				return -s
			end
			return s
		end,
	})
	local zf = funnelZ(layers, layerH)
	local topY = layers[7].y + layerH / 2

	-- dust skirt at the touch-down point
	cyl(m, "Skirt", 0.2, wide and 2.8 or 1.8, V(0, 0.1, 0), c[2], sandy and M.Sand or M.SmoothPlastic, 0.45)

	if id == "MiniTornado" or chaos then
		local cap = chaos and c[1] or Kit.mix(c[1], WHITE, 0.25)
		ball(m, "Cloud", 1.7, V(-1.25, topY + 0.25, 0.1), cap)
		ball(m, "Cloud", 2.0, V(0, topY + 0.5, 0.05), chaos and c[2] or cap)
		ball(m, "Cloud", 1.7, V(1.25, topY + 0.25, 0.1), chaos and c[3] or cap)
	end

	if id == "DustDevil" then
		face(m, { y = 2.95, d = 0.58, gap = 0.42, z = zf, mouth = "smile", blush = BLUSH })
		local weed = ball(m, "Tumbleweed", 0.75, V(1.75, 1.6, 0.3), { 150, 110, 60 }, M.Grass)
		orbit(weed, 3.0)
		selfSpin(weed, 4)
		orbit(ball(m, "Pebble", 0.35, V(-1.6, 2.6, -0.4), c[2], M.Slate), 2.6)
		orbit(ball(m, "Pebble", 0.3, V(0.4, 3.7, 1.9), c[2], M.Slate), 2.2)
	elseif id == "MiniTornado" then
		face(m, { y = 2.95, d = 0.58, gap = 0.42, z = zf, brows = 0.35, mouth = "grin" })
		-- suburban debris: a fence plank, a roof piece and a mailbox
		local plank = part(m, "FencePlank", V(0.18, 0.45, 1.7), CF(2.15, 2.4, 0) * ANG(0.4, 0.3, 0.6), { 240, 235, 225 }, M.WoodPlanks)
		orbit(plank, 2.2)
		selfSpin(plank, 3)
		local roof = part(m, "RoofPiece", V(1.2, 0.45, 0.9), CF(-1.95, 3.3, 0.6) * ANG(0.3, 0.8, -0.4), { 170, 60, 50 }, M.Slate, nil, "Wedge")
		orbit(roof, 1.8)
		selfSpin(roof, -2)
		local box = part(m, "Mailbox", V(0.35, 0.35, 0.6), CF(0.3, 1.4, -1.9) * ANG(0, 0.6, 0.3), { 60, 90, 160 }, M.Metal)
		orbit(box, 2.6)
	elseif id == "Sandstorm" then
		face(m, { y = 2.95, d = 0.6, gap = 0.48, z = zf, brows = 0.45, mouth = "fangs" })
		orbit(cyl(m, "Cactus", 0.9, 0.35, CF(2.4, 2.8, 0) * ANG(0.5, 0, 0.4), { 80, 140, 70 }, M.Grass), 1.6)
		orbit(part(m, "Rock", V(0.5, 0.4, 0.45), CF(-2.2, 1.9, 0.4) * ANG(0.4, 0.5, 0.2), c[2], M.Slate), 2.4)
		orbit(part(m, "Rock", V(0.4, 0.35, 0.4), CF(0.6, 3.9, 2.3) * ANG(0.2, 0.9, 0.5), c[2], M.Slate), 2.0)
		Kit.particles(m:FindFirstChild("Skirt"), { color = c[1], color2 = c[2], size = 0.5, rate = 18, speed = 3, lifetime = 1.2, spread = 60, accel = V(0, 2, 0), emission = 0 })
	elseif chaos then
		face(m, { y = 2.95, d = 0.6, gap = 0.44, z = zf, glow = c[3], brows = 0.5, mouth = "grin" })
		for r = 1, 2 do
			local tilt = (r == 1) and 0.5 or -0.5
			for i = 1, 6 do
				local a = i / 6 * PI * 2
				local p = part(m, "ChaosRing", V(0.35, 0.35, 0.35), CF(0, 2.8, 0) * ANG(tilt, 0, 0) * CF(math.cos(a) * 2.6, 0, math.sin(a) * 2.6) * ANG(0.6, a, 0.6), c[r], M.Neon)
				orbit(p, (r == 1) and 2.6 or -2.6)
			end
		end
		bolt(m, { V(-0.9, topY + 0.1, -0.9), V(-0.5, topY - 0.5, -1.0), V(-0.8, topY - 1.0, -1.0) }, 0.16, c[3])
		Kit.particles(m:FindFirstChild("Cloud"), { color = c[1], color2 = c[2], size = 0.4, rate = 16, speed = 3, lifetime = 1 })
	else
		face(m, { y = 2.95, d = 0.58, gap = 0.42, z = zf, mouth = "smile" })
	end
	return { bob = 0.15, spin = 0 }
end

local CLOUD_PUFFS = {
	{ 0, 3.6, 0, 2.5 },
	{ -1.25, 3.3, 0.15, 1.85 },
	{ 1.25, 3.3, 0.15, 1.85 },
	{ -0.55, 4.35, 0.3, 1.75 },
	{ 0.6, 4.25, 0.25, 1.6 },
	{ 0, 3.4, 0.8, 2.0 },
}

function A.Cloud(m, c, id)
	for i, p in ipairs(CLOUD_PUFFS) do
		ball(m, (i == 1) and "Body" or "Puff", p[4], V(p[1], p[2], p[3]), Kit.mix(c[1], c[2], (i - 1) * 0.05))
	end
	local body = m:FindFirstChild("Body")
	local zf = ballZ(V(0, 3.6, 0), 1.25)
	if id == "HailSprite" then
		face(m, { y = 3.7, d = 0.52, gap = 0.46, z = zf, brows = 0.25, mouth = "grin" })
		-- icy crown
		for s = -1, 1, 2 do
			part(m, "Crown", V(0.3, 0.75, 0.3), CF(s * 0.35, 5.2, 0.3) * ANG(0, PI / 4, s * 0.35), c[3], M.Glass, 0.15)
		end
		local hail = { { -0.8, 1.9, -0.3, 0.38 }, { 0.5, 1.4, -0.1, 0.32 }, { 0.95, 2.25, 0.25, 0.3 }, { -0.3, 0.85, 0.1, 0.34 } }
		for _, h in ipairs(hail) do
			ball(m, "Hail", h[4], V(h[1], h[2], h[3]), c[3], M.Ice)
		end
		cyl(m, "SnowPatch", 0.16, 2.4, V(0, 0.08, 0), c[1], M.Snow)
		ball(m, "HailPile", 0.5, V(0.3, 0.3, 0), c[3], M.Ice)
		ball(m, "HailPile", 0.45, V(-0.25, 0.28, 0.2), c[3], M.Ice)
		ball(m, "HailPile", 0.4, V(0.05, 0.6, 0.1), c[3], M.Ice)
		Kit.particles(body, { color = c[3], size = 0.22, sizeEnd = 0.18, rate = 8, speed = 2, lifetime = 0.9, spread = 15, accel = V(0, -18, 0), emission = 0.2 })
	else -- SporeCloud
		face(m, { y = 3.7, d = 0.52, gap = 0.46, z = zf, mouth = "smile", blush = BLUSH })
		for s = -1, 1, 2 do
			part(m, "Sprout", V(0.12, 0.45, 0.7), CF(s * 0.3, 5.25, 0.3) * ANG(0, s * PI / 2, 0) * ANG(-0.5, 0, 0), c[2], M.Grass, nil, "Wedge")
		end
		cyl(m, "Moss", 0.2, 2.8, V(0, 0.1, 0), c[2], M.Grass)
		local shrooms = { { -0.75, 0.7, 0.75, 0.2 }, { 0.65, 0.5, 0.6, -0.1 }, { 0.05, 0.9, 0.85, 0.5 } }
		for _, s in ipairs(shrooms) do
			cyl(m, "Stem", s[2], 0.26, V(s[1], 0.2 + s[2] / 2, s[4]), { 240, 230, 210 })
			ball(m, "Cap", s[3], V(s[1], 0.2 + s[2] + s[3] * 0.2, s[4]), c[1])
		end
		ball(m, "Spore", 0.28, V(-0.7, 1.6, -0.3), c[3], M.Neon)
		ball(m, "Spore", 0.26, V(0.6, 2.05, 0), c[3], M.Neon)
		ball(m, "Spore", 0.22, V(0.15, 1.35, -0.5), c[3], M.Neon)
		Kit.particles(body, { color = c[3], color2 = c[1], size = 0.3, rate = 6, speed = 0.6, lifetime = 2.2, accel = V(0, 0.6, 0) })
	end
	return { bob = 0.35, spin = 0 }
end

function A.StormCloud(m, c, id)
	local ash = id == "AshCloud"
	local cell = id == "Supercell"
	local puffs = {
		{ 0, 3.3, 0, 2.7 },
		{ -1.45, 3.1, 0.1, 2.05 },
		{ 1.45, 3.1, 0.1, 2.05 },
		{ 0, 3.5, 0.85, 2.3 },
		{ -0.7, 4.1, 0.4, 1.9 },
		{ 0.75, 4.0, 0.4, 1.8 },
	}
	local mat = ash and M.Slate or M.SmoothPlastic
	for i, p in ipairs(puffs) do
		ball(m, (i == 1) and "Body" or "Puff", p[4], V(p[1], p[2], p[3]), Kit.mix(c[1], c[2], (i % 3) * 0.25), mat)
	end
	local body = m:FindFirstChild("Body")
	if ash then
		-- rising ash plume with embers
		ball(m, "Plume", 2.0, V(0.2, 4.75, 0.3), c[2], M.Slate)
		ball(m, "Plume", 1.4, V(-0.15, 5.65, 0.35), Kit.mix(c[1], c[2], 0.5), M.Slate)
		for i = 1, 3 do
			local a = i / 3 * PI * 2
			orbit(ball(m, "Ember", 0.3, V(math.cos(a) * 2.2, 3.0 + i * 0.6, math.sin(a) * 2.2), c[3], M.Neon), 1.4)
		end
	else
		-- flat anvil top
		local wideD = cell and 5.6 or 4.8
		cyl(m, "Anvil", 0.5, wideD, V(0, 4.85, 0.2), c[2])
		cyl(m, "Anvil", 0.3, wideD + 0.8, V(0, 5.2, 0.25), Kit.mix(c[1], c[2], 0.5))
	end
	local zf = ballZ(V(0, 3.3, 0), 1.35)
	face(m, { y = 3.45, d = 0.5, gap = 0.5, z = zf, glow = c[3], brows = 0.45, browColor = c[2], mouth = cell and "fangs" or "grin" })

	-- inner lightning flicker
	local flick = ball(m, "Flicker", 1.0, V(1.0, 2.8, -0.7), c[3], M.Neon, 0.1)
	Kit.light(flick, c[3], 10, 1.8)

	if cell then
		-- rotating wall cloud and a funnel touching down
		for i = 1, 6 do
			local a = i / 6 * PI * 2
			orbit(ball(m, "WallCloud", 1.0, V(math.cos(a) * 1.6, 2.2, math.sin(a) * 1.6), c[2]), 1.2)
		end
		local f = { { 2.0, 1.0 }, { 1.4, 0.75 }, { 0.8, 0.5 }, { 0.25, 0.32 } }
		for i, l in ipairs(f) do
			orbit(cyl(m, "Funnel", 0.65, l[2], V(0, l[1], -0.1), Kit.mix(c[1], WHITE, 0.25), M.SmoothPlastic, 0.1), 5 - i * 0.5)
		end
		bolt(m, { V(-1.4, 2.4, -0.6), V(-1.8, 1.7, -0.7), V(-1.5, 1.1, -0.7) }, 0.18, c[3])
		cyl(m, "Debris", 0.1, 1.2, V(0, 0.05, -0.1), Kit.shade(c[1], 0.6), M.Slate, 0.3)
	else
		bolt(m, { V(0.5, 2.1, -0.5), V(-0.25, 1.45, -0.55), V(0.3, 0.85, -0.55), V(-0.15, 0.15, -0.55) }, 0.2, c[3])
		if ash then
			ball(m, "Ember Rock", 0.8, V(-0.15, 0.4, -0.55), { 50, 40, 38 }, M.Basalt)
			part(m, "Crack", V(0.1, 0.5, 0.06), CF(-0.15, 0.45, -0.96) * ANG(0, 0, 0.5), c[3], M.Neon)
		else
			cyl(m, "Scorch", 0.08, 1.1, V(-0.15, 0.04, -0.55), { 30, 30, 34 })
			ball(m, "Spark", 0.3, V(-0.15, 0.15, -0.55), c[3], M.Neon)
		end
	end
	if ash then
		Kit.particles(body, { color = { 60, 55, 55 }, color2 = c[3], size = 0.35, rate = 10, speed = 1.2, lifetime = 1.6, accel = V(0, -2, 0), emission = 0.2 })
	else
		Kit.particles(body, { color = { 150, 180, 255 }, size = 0.12, sizeEnd = 0.1, rate = 14, speed = 3, lifetime = 0.6, spread = 10, accel = V(0, -25, 0), emission = 0 })
	end
	return { bob = 0.25, spin = 0 }
end

function A.Golem(m, c, id)
	local glow = c[3]
	local main, sec, mat, secMat = c[1], c[2], M.Slate, M.Slate
	if id == "BrambleQuake" then
		main, sec, mat, secMat = c[2], Kit.shade(c[2], 0.8), M.Wood, M.Wood
	elseif id == "AvalancheGolem" then
		mat, secMat = M.Snow, M.Slate
	elseif id == "GlacierTitan" then
		mat, secMat = M.Ice, M.Ice
	end
	local quake = id == "BrambleQuake" or id == "QuakeTitan"
	local b = 0
	if quake then
		cyl(m, "Slab", 0.3, 3.6, V(0, 0.15, 0), Kit.shade(c[2], 0.9), M.Slate)
		part(m, "Crack", V(0.12, 0.06, 1.4), CF(0.75, 0.31, -0.7) * ANG(0, 0.5, 0), glow, M.Neon)
		part(m, "Crack", V(0.12, 0.06, 1.2), CF(-0.85, 0.31, 0.3) * ANG(0, -0.9, 0), glow, M.Neon)
		b = 0.3
	end
	local fist = (id == "QuakeTitan") and 1.3 or 1.05
	for s = -1, 1, 2 do
		part(m, "Leg", V(0.9, 1.3, 0.95), V(s * 0.62, b + 0.65, 0), sec, secMat)
	end
	part(m, "Pelvis", V(2.0, 0.6, 1.25), V(0, b + 1.55, 0), sec, secMat)
	part(m, "Torso", V(2.7, 1.8, 1.6), V(0, b + 2.75, 0), main, mat)
	local head = part(m, "Head", V(1.4, 1.15, 1.25), V(0, b + 4.2, -0.12), main, mat)
	for s = -1, 1, 2 do
		if id == "AvalancheGolem" and s == 1 then
			-- right arm raised, holding a big snowball
			part(m, "Arm", V(0.85, 1.5, 0.85), CF(1.8, b + 4.0, 0) * ANG(0, 0, -0.15), main, mat)
			part(m, "Fist", V(fist, 1.0, fist), V(1.95, b + 4.95, -0.1), sec, secMat)
			ball(m, "Snowball", 1.3, V(1.95, b + 5.85, -0.1), WHITE, M.Snow)
		else
			part(m, "Arm", V(0.85, 1.5, 0.85), CF(s * 1.8, b + 2.9, 0) * ANG(0, 0, s * 0.12), main, mat)
			part(m, "Fist", V(fist, fist * 0.95, fist), V(s * (1.85 + fist * 0.1), b + 1.75, -0.1), sec, secMat)
		end
	end
	local gem = ball(m, "Gem", 0.7, V(0, b + 2.85, -0.75), glow, M.Neon)
	Kit.light(gem, glow, 8, 1.2)
	part(m, "Crack", V(0.1, 0.9, 0.06), CF(0.72, b + 2.4, -0.81) * ANG(0, 0, 0.4), glow, M.Neon)
	part(m, "Crack", V(0.1, 0.7, 0.06), CF(-0.68, b + 3.15, -0.81) * ANG(0, 0, -0.5), glow, M.Neon)
	face(m, { y = b + 4.3, d = 0.36, gap = 0.32, z = -0.745, glow = glow, brows = 0.45, browColor = Kit.shade(main, 0.5), mouth = "line", mouthY = b + 3.9, mouthW = 0.6 })

	if id == "BrambleQuake" then
		for s = -1, 1, 2 do
			part(m, "Moss", V(1.0, 0.35, 1.0), V(s * 1.8, b + 3.8, 0), c[1], M.Grass)
			part(m, "Thorn", V(0.22, 0.6, 0.22), CF(s * 1.9, b + 4.1, 0.15) * ANG(0, 0, -s * 0.5), Kit.shade(c[1], 0.6), M.Wood)
			part(m, "Leaf", V(0.15, 0.7, 0.6), CF(s * 0.35, b + 5.05, 0) * ANG(0, s * PI / 2, 0), c[1], M.Grass, nil, "Wedge")
		end
		part(m, "Thorn", V(0.25, 0.7, 0.25), CF(0.5, b + 3.1, 0.85) * ANG(0.7, 0, 0), Kit.shade(c[1], 0.6), M.Wood)
		part(m, "Thorn", V(0.25, 0.7, 0.25), CF(-0.5, b + 2.5, 0.85) * ANG(0.7, 0, 0), Kit.shade(c[1], 0.6), M.Wood)
		ball(m, "Flower", 0.4, V(-0.45, b + 4.85, 0.1), glow, M.Neon)
	elseif id == "QuakeTitan" then
		for s = -1, 1, 2 do
			ball(m, "Boulder", 1.15, V(s * 1.85, b + 3.85, 0.1), sec, M.Slate)
			part(m, "Crack", V(0.1, 0.8, 0.06), CF(s * 1.85, b + 2.7, -0.45) * ANG(0, 0, s * 0.3), glow, M.Neon)
		end
		part(m, "Spike", V(0.4, 0.9, 0.4), CF(0, b + 3.9, 0.55) * ANG(-0.5, PI / 4, 0), sec, M.Slate)
		Kit.particles(m:FindFirstChild("Slab"), { color = c[1], size = 0.4, rate = 6, speed = 1.5, lifetime = 0.8, spread = 50, emission = 0 })
	elseif id == "AvalancheGolem" then
		ball(m, "SnowCap", 1.1, V(0, b + 4.8, 0), WHITE, M.Snow)
		ball(m, "SnowShoulder", 0.9, V(-1.8, b + 3.75, 0), WHITE, M.Snow)
		part(m, "Icicle", V(0.2, 0.6, 0.2), CF(-1.8, b + 2.0, -0.2) * ANG(0, PI / 4, 0), glow, M.Glass, 0.2)
		part(m, "Icicle", V(0.18, 0.5, 0.18), CF(0.5, b + 3.4, -0.83) * ANG(0, PI / 4, 0), glow, M.Glass, 0.2)
		Kit.particles(head, { color = WHITE, size = 0.25, rate = 5, speed = 0.6, lifetime = 1.6, accel = V(0, -1.5, 0), emission = 0 })
	elseif id == "GlacierTitan" then
		local spikes = {
			{ CF(0.55, b + 3.7, 0.65) * ANG(-0.6, 0, -0.25), 1.4 },
			{ CF(-0.55, b + 3.6, 0.7) * ANG(-0.7, 0, 0.3), 1.2 },
			{ CF(1.85, b + 4.0, 0) * ANG(0, 0, -0.3), 1.2 },
			{ CF(-1.85, b + 4.0, 0) * ANG(0, 0, 0.3), 1.2 },
			{ CF(0, b + 5.0, 0) * ANG(0, PI / 4, 0), 0.9 },
			{ CF(0.45, b + 4.9, 0.05) * ANG(0, PI / 4, -0.35), 0.6 },
			{ CF(-0.45, b + 4.9, 0.05) * ANG(0, PI / 4, 0.35), 0.6 },
		}
		for _, sp in ipairs(spikes) do
			part(m, "IceSpike", V(0.42, sp[2], 0.42), sp[1], glow, M.Glass, 0.15)
		end
		Kit.particles(gem, { color = glow, size = 0.25, rate = 6, speed = 1, lifetime = 1.4, emission = 0.8 })
	end
	return { bob = 0.06, spin = 0 }
end

function A.Serpent(m, c, id)
	local main, sec, glow = c[1], c[2], c[3]
	local mat = (id == "VineSerpent") and M.Grass or M.SmoothPlastic
	local watery = id == "RiptideEel" or id == "UndertowLeviathan"
	local jet = id == "JetstreamDrake"
	-- coiled base
	for i = 1, 5 do
		local a = (i - 1) / 5 * PI * 2 + 0.6
		if jet then
			ball(m, "CloudBase", 1.25 - (i % 2) * 0.15, V(math.cos(a) * 1.0, 0.6, math.sin(a) * 1.0), sec)
		else
			ball(m, "Coil", 1.1, V(math.cos(a) * 1.05, 0.55 + i * 0.03, math.sin(a) * 1.05 + 0.1), (i % 2 == 0) and Kit.shade(main, 0.85) or main, mat)
		end
	end
	if watery then
		cyl(m, "Water", 0.15, 3.4, V(0, 0.075, 0.1), { 60, 150, 200 }, M.Glass, 0.35)
	end
	-- rising S-curve body
	local pts = {}
	for i = 1, 6 do
		local t = i / 6
		local p = V(math.sin(t * PI * 1.6) * 0.95, 0.9 + t * 3.3, 0.35 - t * 0.55)
		pts[i] = p
		ball(m, "Body", 1.15 - t * 0.3, p, (i % 2 == 0) and Kit.shade(main, 0.88) or main, mat)
	end
	local hp = V(pts[6].X * 0.4, 4.85, -0.4)
	ball(m, "Head", 1.55, hp, main, mat)
	part(m, "Snout", V(0.95, 0.55, 0.85), hp + V(0, -0.25, -0.72), main, mat)
	local zf = ballZ(hp, 0.775)
	local fo = { x = hp.X, y = hp.Y + 0.2, d = 0.4, gap = 0.34, z = zf, mouthY = hp.Y - 0.38, mouthZ = hp.Z - 1.17, mouthW = 0.55 }

	if id == "VineSerpent" then
		fo.mouth = "fangs"
		fo.blush = BLUSH
		for i = 2, 5 do
			local s = (i % 2 == 0) and 1 or -1
			part(m, "Leaf", V(0.15, 0.5, 0.75), CF(pts[i] + V(s * 0.55, 0.15, 0)) * ANG(0, s * PI / 2, 0) * ANG(-0.4, 0, 0), sec, M.Grass, nil, "Wedge")
		end
		for i = 1, 3 do
			local a = i / 3 * PI * 2
			ball(m, "Petal", 0.32, hp + V(math.cos(a) * 0.25 + 0.3, 0.75, math.sin(a) * 0.25), { 255, 150, 200 })
		end
		ball(m, "Pollen", 0.22, hp + V(0.3, 0.82, 0), { 255, 230, 90 }, M.Neon)
	elseif id == "InfernoDrake" then
		fo.mouth = "fangs"
		fo.brows = 0.45
		for s = -1, 1, 2 do
			seg(m, "Horn", hp + V(s * 0.35, 0.5, 0.1), hp + V(s * 0.6, 1.2, 0.7), 0.22, sec)
			part(m, "Wing", V(0.12, 1.3, 1.5), CF(pts[3] + V(s * 0.95, 0.45, 0.45)) * ANG(0.3, 0, -s * 0.55), sec, M.SmoothPlastic, 0.1)
			part(m, "WingBone", V(0.18, 1.5, 0.18), CF(pts[3] + V(s * 0.95, 0.5, -0.25)) * ANG(0, 0, -s * 0.55), Kit.shade(sec, 0.7))
		end
		for i = 3, 5 do
			part(m, "Flame", V(0.14, 0.55, 0.6), CF(pts[i] + V(0, 0.2, 0.45)) * ANG(0, PI / 2, 0), glow, M.Neon, nil, "Wedge")
		end
		for i = 2, 4 do
			ball(m, "Belly", 0.4, pts[i] + V(0, 0, -(1.15 - i / 6 * 0.3) / 2 + 0.08), glow, M.Neon)
		end
		Kit.particles(m:FindFirstChild("Snout"), { color = glow, color2 = main, size = 0.4, rate = 10, speed = 2, lifetime = 0.5, spread = 20, accel = V(0, 3, 0) })
	elseif id == "RiptideEel" then
		fo.mouth = "smile"
		fo.brows = 0.25
		for i = 2, 5 do
			part(m, "Fin", V(0.1, 0.45, 0.6), CF(pts[i] + V(0, 0.45, 0.25)) * ANG(0, PI / 2, 0), sec, M.Glass, 0.2, "Wedge")
			ball(m, "Spot", 0.22, pts[i] + V((i % 2 == 0) and 0.4 or -0.4, 0.1, -0.3), glow, M.Neon)
		end
		for i = 1, 3 do
			local a = i / 3 * PI * 2
			orbit(part(m, "Swirl", V(0.2, 0.15, 0.9), CF(math.cos(a) * 1.9, 0.4 + i * 0.25, math.sin(a) * 1.9) * ANG(0, -a, 0), { 160, 230, 255 }, M.Glass, 0.3), 2.2)
		end
	elseif id == "UndertowLeviathan" then
		fo.mouth = "fangs"
		fo.brows = 0.5
		fo.glow = glow
		for i = -1, 1 do
			part(m, "Crown", V(0.18, 0.7 - math.abs(i) * 0.2, 0.18), CF(hp + V(i * 0.32, 0.8, 0.15)) * ANG(0, PI / 4, i * 0.35), sec, M.Neon)
		end
		for s = -1, 1, 2 do
			part(m, "Fin", V(0.12, 0.6, 0.9), CF(hp + V(s * 0.75, 0, 0.25)) * ANG(0, s * PI / 2, 0), Kit.shade(main, 0.7), M.SmoothPlastic, nil, "Wedge")
		end
		for i = 1, 5 do
			ball(m, "Spot", 0.22, pts[i] + V((i % 2 == 0) and 0.42 or -0.42, 0.15, -0.28), glow, M.Neon)
		end
		Kit.particles(m:FindFirstChild("Water"), { color = glow, size = 0.2, rate = 6, speed = 0.8, lifetime = 2, accel = V(0, 1, 0) })
	elseif jet then
		fo.mouth = "smile"
		fo.brows = 0.2
		for s = -1, 1, 2 do
			for k = 1, 2 do
				local root = pts[3] + V(s * 0.45, 0.3, 0.2)
				seg(m, "Feather", root, root + V(s * (1.1 + k * 0.35), 0.5 + k * 0.45, 0.35), 0.12, sec, M.SmoothPlastic, nil, 0.45)
			end
			seg(m, "Horn", hp + V(s * 0.3, 0.55, 0.1), hp + V(s * 0.45, 1.05, 0.5), 0.16, glow, M.Neon)
		end
		for i = 1, 3 do
			local a = i / 3 * PI * 2
			orbit(part(m, "Wind", V(0.08, 0.08, 1.6), CF(math.cos(a) * 2.0, 1.4 + i * 0.8, math.sin(a) * 2.0) * ANG(0, -a, 0.2), glow, M.Neon, 0.3), 3)
		end
	end
	face(m, fo)
	return { bob = 0.12, spin = 0 }
end

local function mammoth(m, c)
	local fur, ice, glow = c[1], c[2], c[3]
	for _, x in ipairs({ -0.7, 0.7 }) do
		for _, z in ipairs({ -0.85, 0.95 }) do
			part(m, "Leg", V(0.75, 1.3, 0.75), V(x, 0.65, z), Kit.shade(fur, 0.85), M.Fabric)
		end
	end
	part(m, "Body", V(2.2, 1.8, 2.9), V(0, 2.15, 0.15), fur, M.Fabric)
	ball(m, "Hump", 1.9, V(0, 2.85, -0.35), fur, M.Fabric)
	part(m, "Head", V(1.6, 1.5, 1.3), V(0, 3.0, -1.55), fur, M.Fabric)
	for s = -1, 1, 2 do
		part(m, "Ear", V(0.2, 0.7, 0.6), CF(s * 0.9, 3.05, -1.3) * ANG(0, s * 0.3, 0), Kit.shade(fur, 0.75), M.Fabric)
		seg(m, "Tusk", V(s * 0.45, 2.45, -2.1), V(s * 0.75, 1.75, -2.75), 0.24, IVORY)
		seg(m, "Tusk", V(s * 0.75, 1.75, -2.75), V(s * 0.55, 2.35, -3.3), 0.2, IVORY)
	end
	seg(m, "Trunk", V(0, 2.6, -2.15), V(0, 1.8, -2.45), 0.5, fur, M.Fabric)
	seg(m, "Trunk", V(0, 1.8, -2.45), V(0, 1.1, -2.3), 0.42, fur, M.Fabric)
	seg(m, "Trunk", V(0, 1.1, -2.3), V(0, 0.95, -1.95), 0.34, fur, M.Fabric)
	-- glacier riding on its back
	part(m, "IceBack", V(1.8, 0.6, 2.2), V(0, 3.25, 0.6), ice, M.Glass, 0.2)
	part(m, "Icicle", V(0.3, 0.8, 0.3), CF(0.4, 3.85, 0.3) * ANG(0, PI / 4, -0.25), glow, M.Glass, 0.1)
	part(m, "Icicle", V(0.3, 0.9, 0.3), CF(-0.4, 3.9, 0.7) * ANG(0, PI / 4, 0.25), glow, M.Glass, 0.1)
	part(m, "Icicle", V(0.25, 0.6, 0.25), CF(0, 3.75, 1.3) * ANG(0.3, PI / 4, 0), glow, M.Glass, 0.1)
	ball(m, "SnowTuft", 0.75, V(0, 3.8, -1.55), ice, M.Snow)
	seg(m, "Tail", V(0, 2.4, 1.6), V(0, 1.7, 1.95), 0.2, Kit.shade(fur, 0.8), M.Fabric)
	face(m, { y = 3.25, d = 0.3, gap = 0.42, z = -2.2, brows = 0.2, browColor = Kit.shade(fur, 0.5) })
	Kit.particles(m:FindFirstChild("IceBack"), { color = glow, size = 0.2, rate = 6, speed = 0.8, lifetime = 1.5, emission = 0.5, accel = V(0, -1, 0) })
	return { bob = 0.05, spin = 0 }
end

function A.Beast(m, c, id)
	if id == "MammothGlacier" then
		return mammoth(m, c)
	end
	local fox = id == "WildfireFox"
	local main, sec, glow = c[1], c[2], c[3]
	local mat = fox and M.SmoothPlastic or M.Fabric
	local bodyW = fox and 1.6 or 1.9
	local paw = fox and { 70, 45, 35 } or sec
	for _, x in ipairs({ -0.55, 0.55 }) do
		for _, z in ipairs({ -0.85, 0.95 }) do
			part(m, "Leg", V(0.5, 1.1, 0.5), V(x * bodyW / 1.6, 0.85, z), main, mat)
			part(m, "Paw", V(0.58, 0.3, 0.68), V(x * bodyW / 1.6, 0.15, z - 0.06), paw, mat)
		end
	end
	part(m, "Body", V(bodyW, fox and 1.3 or 1.5, 2.6), V(0, 1.95, 0.1), main, mat)
	part(m, "Head", V(1.45, 1.25, 1.25), V(0, 2.95, -1.25), main, mat)
	part(m, "Muzzle", V(0.75, 0.5, 0.6), V(0, 2.62, -2.05), fox and sec or Kit.mix(main, WHITE, 0.4), mat)
	ball(m, "Nose", 0.26, V(0, 2.8, -2.36), INK)
	if fox then
		part(m, "Chest", V(1.1, 1.0, 0.3), V(0, 1.85, -1.18), sec, mat)
		for s = -1, 1, 2 do
			part(m, "Ear", V(0.2, 0.9, 0.55), CF(s * 0.45, 3.95, -1.25) * ANG(0, s * PI / 2, 0), main, mat, nil, "Wedge")
		end
		seg(m, "Tail", V(0, 2.1, 1.35), V(0, 2.75, 1.95), 0.55, main, mat)
		local tip = ball(m, "TailTip", 0.75, V(0, 2.95, 2.15), sec, mat)
		ball(m, "TailFlame", 0.8, V(0, 3.3, 2.25), { 255, 140, 30 }, M.Neon, 0.1)
		ball(m, "TailFlame", 0.6, V(0.05, 3.75, 2.35), glow, M.Neon, 0.1)
		ball(m, "TailFlame", 0.4, V(0.1, 4.12, 2.4), { 255, 240, 150 }, M.Neon, 0.1)
		part(m, "HeadFlame", V(0.12, 0.45, 0.5), CF(0, 3.75, -1.0) * ANG(0, PI / 2, 0), glow, M.Neon, nil, "Wedge")
		Kit.particles(tip, { color = glow, color2 = { 255, 90, 20 }, size = 0.45, rate = 14, speed = 2, lifetime = 0.6, spread = 25, accel = V(0, 5, 0) })
		face(m, { y = 3.1, d = 0.38, gap = 0.33, z = -1.875, brows = 0.3, mouth = "fangs", mouthY = 2.58, mouthZ = -2.36, mouthW = 0.45 })
	else
		for s = -1, 1, 2 do
			ball(m, "Ear", 0.45, V(s * 0.55, 3.62, -1.15), main, mat)
			part(m, "Stripe", V(0.06, 0.9, 0.3), CF(s * (bodyW / 2 + 0.01), 2.0, -0.3 + s * 0.1) * ANG(0.4, 0, 0), sec, mat)
			part(m, "Stripe", V(0.06, 0.8, 0.3), CF(s * (bodyW / 2 + 0.01), 2.0, 0.5 + s * 0.1) * ANG(0.4, 0, 0), sec, mat)
		end
		local shards = { { 0.25, -0.6, 0.3, 1.0 }, { -0.25, -0.1, -0.3, 1.2 }, { 0.2, 0.45, 0.25, 0.95 }, { -0.15, 0.95, -0.2, 0.7 } }
		for _, sh in ipairs(shards) do
			part(m, "IceShard", V(0.35, sh[4], 0.35), CF(sh[1], 2.7 + sh[4] * 0.35, sh[2]) * ANG(-0.25, PI / 4, sh[3]), glow, M.Glass, 0.15)
		end
		ball(m, "Tail", 0.9, V(0, 2.4, 1.55), Kit.mix(main, WHITE, 0.3), mat)
		Kit.particles(m:FindFirstChild("Muzzle"), { color = glow, size = 0.3, rate = 8, speed = 1.5, lifetime = 0.8, spread = 20, emission = 0.3 })
		face(m, { y = 3.1, d = 0.38, gap = 0.33, z = -1.875, brows = 0.45, browColor = sec, mouth = "fangs", mouthY = 2.58, mouthZ = -2.36, mouthW = 0.45 })
	end
	return { bob = 0.06, spin = 0 }
end

local function solar(m, c)
	local sun, flare, glow = c[1], c[2], c[3]
	cyl(m, "PlasmaPool", 0.12, 2.2, V(0, 0.06, 0), flare, M.Neon, 0.35)
	cyl(m, "PlasmaColumn", 1.8, 0.5, V(0, 0.95, 0), flare, M.Neon, 0.3)
	ball(m, "PlasmaKnot", 0.8, V(0, 1.95, 0), flare, M.Neon, 0.1)
	local ctr = V(0, 3.9, 0)
	local core = ball(m, "Core", 3.0, ctr, sun, M.Neon)
	ball(m, "Corona", 3.5, ctr, glow, M.Neon, 0.75)
	Kit.light(core, sun, 16, 2.5)
	for k = 0, 7 do
		local a = k * PI / 4
		local len = (k % 2 == 0) and 1.2 or 0.8
		local dir = V(math.cos(a), math.sin(a), 0)
		part(m, "Ray", V(0.5, len, 0.35), CF(ctr + dir * (1.55 + len / 2)) * ANG(0, 0, a - PI / 2), flare, M.Neon)
	end
	bolt(m, { V(-1.2, 5.05, -0.3), V(-1.9, 5.8, -0.3), V(-1.3, 6.3, -0.3), V(-0.6, 5.45, -0.3) }, 0.22, glow)
	bolt(m, { V(1.35, 4.6, -0.2), V(2.3, 4.9, -0.2), V(2.2, 3.9, -0.2), V(1.5, 3.4, -0.2) }, 0.2, glow)
	face(m, { y = 4.1, d = 0.55, gap = 0.5, z = ballZ(ctr, 1.5), brows = 0.45, browColor = { 150, 50, 10 }, mouth = "grin" })
	Kit.particles(core, { color = glow, color2 = flare, size = 0.5, rate = 14, speed = 2.5, lifetime = 1, emission = 1 })
	return { bob = 0.3, spin = 0 }
end

function A.Wisp(m, c, id)
	if id == "SolarStorm" then
		return solar(m, c)
	end
	local main, sec, glow = c[1], c[2], c[3]
	cyl(m, "GroundGlow", 0.1, 1.6, V(0, 0.05, 0), glow, M.Neon, 0.5)
	ball(m, "Tail", 0.55, V(-0.35, 0.35, 0.35), main, M.Neon, 0.25)
	ball(m, "Tail", 0.95, V(-0.15, 0.95, 0.2), main, M.Neon, 0.2)
	local core = ball(m, "Core", 1.5, V(0, 2.3, 0.05), glow, M.Neon)
	Kit.light(core, glow, 10, 1.6)
	ball(m, "Body", 2.5, V(0, 2.3, 0), main, M.Glass, 0.3)
	ball(m, "Flame", 1.7, V(0.1, 3.35, 0.15), main, M.Neon, 0.25)
	ball(m, "Flame", 1.1, V(0.3, 4.15, 0.3), sec, M.Neon, 0.2)
	ball(m, "Flame", 0.6, V(0.5, 4.75, 0.5), glow, M.Neon)
	for i = 1, 3 do
		local a = i / 3 * PI * 2
		orbit(ball(m, "Mote", 0.25, V(math.cos(a) * 1.8, 0.6 + i * 1.0, math.sin(a) * 1.8), glow, M.Neon), 1.6)
	end
	local zf = ballZ(V(0, 2.3, 0), 1.25)
	if id == "MirageWisp" then
		for s = -1, 1, 2 do
			ball(m, "Mirage", 2.0, V(s * 1.25, 2.5, 0.6), main, M.Neon, 0.82)
		end
		cyl(m, "SandRing", 0.15, 2.4, V(0, 0.075, 0), sec, M.Sand)
		face(m, { y = 2.45, d = 0.5, gap = 0.42, z = zf, brows = 0.25, browColor = { 150, 80, 20 }, mouth = "smile" })
		Kit.particles(core, { color = glow, size = 0.3, rate = 6, speed = 1, lifetime = 1.2, transparency = 0.5 })
	elseif id == "FrostWisp" then
		for i = 1, 3 do
			local a = i / 3 * PI * 2 + 0.5
			local pos = V(math.cos(a) * 1.9, 1.5 + i * 0.8, math.sin(a) * 1.9)
			for k = 0, 2 do
				orbit(part(m, "Snowflake", V(0.7, 0.1, 0.1), CF(pos) * ANG(0, -a, 0) * ANG(0, 0, k * PI / 3), WHITE, M.Neon), 1.2)
			end
		end
		part(m, "IceTip", V(0.3, 0.8, 0.3), CF(0.55, 5.1, 0.55) * ANG(0, PI / 4, -0.2), glow, M.Glass, 0.1)
		face(m, { y = 2.45, d = 0.5, gap = 0.42, z = zf, mouth = "o", blush = { 170, 210, 255 } })
		Kit.particles(core, { color = WHITE, size = 0.2, rate = 8, speed = 0.8, lifetime = 1.6, accel = V(0, -1.5, 0) })
	else -- RiftWisp
		bolt(m, { V(0.2, 0.6, 1.4), V(-0.35, 1.9, 1.4), V(0.3, 3.2, 1.4), V(-0.2, 4.6, 1.4) }, 0.3, glow)
		part(m, "Rift", V(0.9, 3.8, 0.05), V(0, 2.6, 1.48), Kit.shade(sec, 0.5), M.SmoothPlastic)
		for i = 1, 3 do
			local a = i / 3 * PI * 2
			local p = part(m, "Shard", V(0.3, 0.7, 0.3), CF(math.cos(a) * 1.9, 1.4 + i * 0.9, math.sin(a) * 1.9) * ANG(0.3, a, 0.3), glow, M.Glass, 0.15)
			orbit(p, -1.4)
			selfSpin(p, 2)
		end
		face(m, { y = 2.45, d = 0.5, gap = 0.42, z = zf, brows = 0.35, browColor = sec, mouth = "fangs" })
		Kit.particles(core, { color = glow, color2 = sec, size = 0.3, rate = 8, speed = 1, lifetime = 1.2 })
	end
	return { bob = 0.4, spin = 0 }
end

local function tarBlob(m, c)
	local tar, mud, glow = c[1], c[2], c[3]
	local puddle = cyl(m, "Puddle", 0.18, 3.8, V(0, 0.09, 0), tar)
	puddle.Reflectance = 0.2
	local lower = ball(m, "Body", 3.0, V(0, 1.45, 0), tar)
	lower.Reflectance = 0.15
	local upper = ball(m, "Blob", 2.3, V(0.05, 2.7, 0.05), tar)
	upper.Reflectance = 0.15
	ball(m, "Drip", 1.2, V(0.3, 3.65, 0.2), tar)
	ball(m, "Lump", 1.1, V(1.35, 0.7, -0.3), Kit.mix(tar, mud, 0.3))
	ball(m, "Lump", 0.9, V(-1.4, 0.55, 0.2), Kit.mix(tar, mud, 0.3))
	ball(m, "Bubble", 0.35, V(0.9, 2.95, -0.75), glow, M.Neon)
	ball(m, "Bubble", 0.28, V(-1.15, 1.9, -0.6), glow, M.Neon)
	ball(m, "Bubble", 0.4, V(-0.6, 3.6, 0.4), mud)
	-- a dino bone stuck in the tar
	seg(m, "Bone", V(-1.0, 2.55, 0.4), V(-1.85, 3.25, 0.6), 0.25, IVORY)
	ball(m, "BoneKnob", 0.35, V(-1.85, 3.38, 0.48), IVORY)
	ball(m, "BoneKnob", 0.35, V(-1.97, 3.2, 0.72), IVORY)
	face(m, { x = 0.05, y = 2.9, d = 0.5, gap = 0.45, z = ballZ(V(0.05, 2.7, 0.05), 1.15), glow = glow, brows = 0.3, browColor = mud })
	mouth(m, "maw", V(0, 1.6, -1.52), 1.4, glow)
	Kit.particles(upper, { color = mud, size = 0.3, rate = 4, speed = 0.4, lifetime = 1.8, accel = V(0, 0.8, 0), emission = 0 })
	return { bob = 0.04, spin = 0 }
end

function A.Maw(m, c, id)
	if id == "TarBlob" then
		return tarBlob(m, c)
	end
	local earth, pit, glow = c[1], c[2], c[3]
	cyl(m, "Ground", 0.25, 4.0, V(0, 0.125, 0), Kit.shade(earth, 0.9), M.Sand)
	for k = 0, 7 do
		local a = k * PI / 4
		local h = 0.95 + (k % 2) * 0.25
		part(m, "RimRock", V(0.8, h, 1.25), CF(math.cos(a) * 1.6, 0.2 + h / 2, math.sin(a) * 1.6) * ANG(0, -a, 0) * ANG(0, 0, -0.25), (k % 2 == 0) and earth or Kit.shade(earth, 0.8), M.Slate)
	end
	cyl(m, "Pit", 0.12, 2.6, V(0, 0.55, 0), pit)
	local deep = cyl(m, "DeepGlow", 0.1, 1.0, V(0, 0.6, 0), glow, M.Neon)
	Kit.light(deep, glow, 8, 1.5)
	for k = 0, 5 do
		local a = k * PI / 3 + 0.3
		part(m, "Tooth", V(0.25, 0.55, 0.25), CF(math.cos(a) * 1.12, 0.85, math.sin(a) * 1.12) * ANG(0, -a, 0) * ANG(0, 0, 0.5) * ANG(0, PI / 4, 0), WHITE)
	end
	-- eyes on stalks
	for s = -1, 1, 2 do
		rod(m, "Stalk", V(s * 0.6, 0.6, 0.55), V(s * 0.75, 3.0, 0.15), 0.32, Kit.shade(earth, 0.85))
		ball(m, "Sclera", 0.95, V(s * 0.75, 3.3, 0.1), { 250, 245, 235 })
	end
	face(m, { y = 3.3, d = 0.55, gap = 0.75, z = -0.12, brows = 0.45, browColor = pit })
	-- debris being sucked in: pebbles and a little road sign
	orbit(ball(m, "Pebble", 0.35, V(2.4, 1.4, 0), earth, M.Slate), -1.8)
	orbit(ball(m, "Pebble", 0.3, V(-2.3, 1.9, 0.5), earth, M.Slate), -1.8)
	orbit(part(m, "SignPost", V(0.12, 0.9, 0.12), CF(0.3, 2.0, 2.3) * ANG(0.3, 0, 0.5), { 120, 90, 60 }, M.Wood), -1.5)
	orbit(part(m, "Sign", V(0.7, 0.4, 0.08), CF(0.12, 2.38, 2.42) * ANG(0.3, 0, 0.5), { 240, 200, 40 }), -1.5)
	Kit.particles(deep, { color = earth, size = 0.3, rate = 8, speed = 1, lifetime = 1, spread = 40, emission = 0 })
	return { bob = 0.03, spin = 0 }
end

function A.Volcano(m, c, id)
	local big = id == "Supervolcano"
	local rock, lava, glow = c[1], c[2], c[3]
	local tiers = big and 6 or 5
	local baseD, topD, th, step = big and 5.0 or 4.0, big and 2.2 or 1.7, 0.8, 0.72
	local layers = {}
	for i = 1, tiers do
		local t = (i - 1) / (tiers - 1)
		local d = baseD + (topD - baseD) * t
		local y = th / 2 + (i - 1) * step
		cyl(m, "Cone", th, d, V(0, y, 0), Kit.shade(rock, 0.9 + 0.12 * (i % 2)), M.Basalt)
		layers[i] = { y = y, d = d }
	end
	local topY = layers[tiers].y + th / 2
	cyl(m, "Rim", 0.35, topD + 0.3, V(0, topY + 0.1, 0), Kit.shade(rock, 0.7), M.Basalt)
	local pool = cyl(m, "Lava", 0.12, topD - 0.2, V(0, topY + 0.22, 0), lava, M.Neon)
	Kit.light(pool, glow, 12, 2)
	ball(m, "LavaBlob", 0.6, V(0.15, topY + 0.38, 0.1), glow, M.Neon)
	local drips = big and { 0.2, 0.8, 1.25, 1.75, 2.3 } or { 0.25, 0.75, 1.2 }
	for _, f in ipairs(drips) do
		local a = f * PI
		local top = V(math.cos(a) * topD / 2, topY, math.sin(a) * topD / 2)
		local bot = V(math.cos(a) * (baseD / 2 - 0.15), 0.85, math.sin(a) * (baseD / 2 - 0.15))
		local n = V(math.cos(a), 0, math.sin(a)) * 0.12
		seg(m, "LavaDrip", top + n, bot + n, 0.25, lava, M.Neon)
	end
	local zf = funnelZ(layers, th)
	if big then
		face(m, { y = 2.4, d = 0.62, gap = 0.58, z = zf, glow = glow, brows = 0.5, browColor = { 30, 15, 12 }, mouth = "fangs" })
		for s = -1, 1, 2 do
			cyl(m, "Vent", 0.3, 0.6, CF(s * 1.75, 1.6, 0.7) * ANG(0, 0, -s * 0.5), Kit.shade(rock, 0.7), M.Basalt)
			local v = ball(m, "VentGlow", 0.35, V(s * 1.9, 1.75, 0.75), lava, M.Neon)
			Kit.particles(v, { color = { 70, 65, 65 }, size = 0.4, sizeEnd = 0.9, rate = 4, speed = 1.2, lifetime = 1.5, spread = 20, accel = V(0, 2, 0), emission = 0 })
		end
		local smoke = { { -0.4, 1.3, 0.3, 1.4 }, { 0.5, 1.6, 0.2, 1.1 }, { 0, 2.2, 0.4, 1.0 } }
		for _, s in ipairs(smoke) do
			ball(m, "AshCloud", s[4], V(s[1], topY + s[2], s[3]), { 70, 65, 65 }, M.Slate)
		end
		bolt(m, { V(0.6, topY + 2.3, -0.1), V(0.9, topY + 1.8, -0.2), V(0.6, topY + 1.35, -0.2) }, 0.14, { 255, 240, 120 })
		for i = 1, 2 do
			local a = i * PI
			orbit(ball(m, "LavaBomb", 0.35, V(math.cos(a) * 1.6, topY + 0.8, math.sin(a) * 1.6), glow, M.Neon), 1.5)
		end
	else
		face(m, { y = 2.0, d = 0.55, gap = 0.48, z = zf, mouth = "smile", blush = BLUSH })
		ball(m, "Puff", 0.8, V(0.3, topY + 0.9, 0.2), { 150, 145, 145 }, M.SmoothPlastic, 0.2)
	end
	Kit.particles(pool, { color = { 90, 85, 85 }, size = 0.5, sizeEnd = 1.2, rate = 5, speed = 1.5, lifetime = 2, spread = 15, accel = V(0, 1.5, 0), emission = 0 })
	Kit.particles(pool, { color = glow, color2 = lava, size = 0.25, rate = 6, speed = 4, lifetime = 0.8, spread = 25, accel = V(0, -8, 0), emission = 1 })
	return { bob = 0.05, spin = 0 }
end

function A.Meteor(m, c, id)
	local big = id == "ExtinctionAsteroid"
	local rock, fire, glow = c[1], c[2], c[3]
	local craterD = big and 3.6 or 3.0
	cyl(m, "Crater", 0.15, craterD, V(0, 0.075, 0), Kit.shade(rock, 0.5), M.Slate)
	cyl(m, "Molten", 0.1, 1.8, V(0, 0.13, 0), fire, M.Neon)
	local n = big and 8 or 6
	for k = 1, n do
		local a = k / n * PI * 2
		part(m, "RimRock", V(0.6, 0.4, 0.7), CF(math.cos(a) * (craterD / 2 - 0.1), 0.2, math.sin(a) * (craterD / 2 - 0.1)) * ANG(0.3 * (k % 2), -a, 0.2), Kit.shade(rock, 0.8), M.Slate)
	end
	local r = big and 1.5 or 1.25
	local ctr = V(0, r + 0.1, 0)
	local stone = ball(m, "Rock", r * 2, ctr, rock, M.Slate)
	local lumps = { V(0.7, 0.5, 0.4), V(-0.6, 0.7, 0.45), V(0.15, -0.25, 0.95), V(-0.85, -0.3, 0.3) }
	for _, l in ipairs(lumps) do
		ball(m, "Lump", r * 0.8, ctr + l.Unit * r * 0.8, Kit.shade(rock, 0.9), M.Slate)
	end
	local cracks = { V(0.8, -0.3, -0.5), V(-0.85, 0.15, -0.5), V(0.2, 0.85, -0.45) }
	if big then
		table.insert(cracks, V(-0.4, -0.6, -0.7))
		table.insert(cracks, V(0.9, 0.35, 0.25))
	end
	for i, d in ipairs(cracks) do
		local nrm = d.Unit
		local p = ctr + nrm * (r - 0.02)
		part(m, "Crack", V(0.1, r * 0.6, 0.08), CFrame.lookAt(p, p + nrm) * ANG(0, 0, i * 0.7), fire, M.Neon)
	end
	-- flame trail streaming up and back
	local T = V(0.25, 1, 0.75).Unit
	for k = 1, 4 do
		local d = (2.0 - k * 0.35) * (big and 1.15 or 1)
		ball(m, "Trail", d, ctr + T * (r * 0.6 + k * 0.85), Kit.mix(fire, glow, k / 4), M.Neon, 0.1 + k * 0.1)
	end
	Kit.particles(stone, { color = glow, color2 = fire, size = 0.6, rate = 16, speed = 3, lifetime = 0.7, spread = 30, accel = V(0, 6, 4) })
	Kit.light(stone, fire, 12, 1.8)
	face(m, { y = ctr.Y + 0.2, d = 0.5, gap = 0.45, z = ballZ(ctr, r), glow = big and glow or nil, brows = 0.45, mouth = big and "fangs" or "grin" })
	if big then
		for i = 1, 3 do
			local a = i / 3 * PI * 2
			orbit(ball(m, "Moonlet", 0.5, V(math.cos(a) * 2.5, 1.3 + i * 0.7, math.sin(a) * 2.5), Kit.shade(rock, 0.8), M.Slate), 1.0)
		end
		-- one very worried tiny dino
		ball(m, "Dino", 0.55, V(1.9, 0.33, -1.6), { 110, 190, 90 })
		ball(m, "DinoHead", 0.4, V(1.75, 0.78, -1.82), { 110, 190, 90 })
		seg(m, "DinoTail", V(2.05, 0.3, -1.35), V(2.3, 0.2, -0.95), 0.15, { 110, 190, 90 })
	end
	return { bob = 0.08, spin = 0 }
end

function A.Wave(m, c, id)
	local water, foam, glow = c[1], c[2], c[3]
	cyl(m, "Water", 0.35, 4.6, V(0, 0.175, 0), water, M.Glass, 0.25)
	part(m, "Body", V(3.4, 3.4, 1.8), V(0, 2.05, 0.5), water, M.SmoothPlastic, 0.05)
	for s = -1, 1, 2 do
		ball(m, "Shoulder", 1.8, V(s * 1.7, 1.75, 0.5), water, M.SmoothPlastic, 0.05)
		seg(m, "Arm", V(s * 1.9, 2.0, 0.2), V(s * 2.3, 1.45, -0.4), 0.7, water, M.SmoothPlastic, 0.05)
		ball(m, "Fist", 1.15, V(s * 2.35, 1.35, -0.55), Kit.mix(water, foam, 0.25), M.SmoothPlastic, 0.05)
	end
	part(m, "Swell", V(3.4, 3.2, 1.8), CF(0, 1.95, 2.2) * ANG(0, PI, 0), Kit.shade(water, 0.85), M.SmoothPlastic, 0.05, "Wedge")
	-- the curl, hooking over the face toward -Z
	local center, R = V(0, 3.9, -0.6), 1.05
	for k = 0, 7 do
		local a = -1.6 + k * 0.6
		local t = k / 7
		part(m, "Curl", V(3.4 - k * 0.17, 0.55, 0.85), CF(center) * ANG(-a, 0, 0) * CF(0, R, 0), Kit.mix(water, foam, t * t), M.SmoothPlastic, 0.08)
	end
	local foamAngles = { -0.2, 0.5, 1.2, 1.9, 2.6 }
	for i, a in ipairs(foamAngles) do
		local x = ((i % 2 == 0) and 0.9 or -0.9) * (1 - i * 0.08)
		ball(m, "Foam", 0.75 - i * 0.04, (CF(center) * ANG(-a, 0, 0) * CF(x, R + 0.35, 0)).Position, foam)
	end
	face(m, { y = 2.35, d = 0.55, gap = 0.55, z = -0.4, brows = 0.45, browColor = Kit.shade(water, 0.4), mouth = "grin", mouthY = 1.78 })
	local crest = m:FindFirstChild("Foam")
	Kit.particles(crest, { color = foam, color2 = glow, size = 0.35, rate = 12, speed = 2, lifetime = 0.8, spread = 60, accel = V(0, -4, 0), emission = 0 })
	return { bob = 0.12, spin = 0 }
end

function A.Bird(m, c, id)
	local gold, navy, glow = c[1], c[2], c[3]
	local cloud = Kit.mix(navy, WHITE, 0.3)
	ball(m, "Perch", 1.2, V(0, 0.55, 0.1), cloud)
	ball(m, "Perch", 1.0, V(-0.75, 0.5, 0.2), cloud)
	ball(m, "Perch", 1.0, V(0.75, 0.5, 0.0), cloud)
	for s = -1, 1, 2 do
		seg(m, "Leg", V(s * 0.35, 0.9, 0.05), V(s * 0.3, 1.65, 0.05), 0.18, Kit.shade(gold, 0.75))
	end
	ball(m, "Body", 2.0, V(0, 2.45, 0.1), gold)
	ball(m, "Belly", 1.5, V(0, 2.3, -0.35), Kit.mix(gold, WHITE, 0.45))
	local hc = V(0, 3.75, -0.25)
	ball(m, "Head", 1.4, hc, gold)
	part(m, "Beak", V(0.45, 0.42, 0.75), V(0, 3.58, -1.2), { 255, 170, 40 }, M.SmoothPlastic, nil, "Wedge")
	face(m, { y = 3.88, d = 0.34, gap = 0.3, z = ballZ(hc, 0.7), brows = 0.45, browColor = navy })
	-- lightning crest
	bolt(m, { V(0, 4.35, -0.1), V(0.25, 4.85, 0.0), V(-0.15, 5.15, 0.1), V(0.2, 5.7, 0.25) }, 0.22, glow)
	-- spread wings: a fan of flat feathers per side
	for s = -1, 1, 2 do
		local root = V(s * 1.0, 2.9, 0.25)
		for k = 0, 3 do
			local th = -0.35 + k * 0.42
			local L = 2.6 - math.abs(k - 1.5) * 0.25
			seg(m, "Feather", root, root + V(s * math.cos(th) * L, math.sin(th) * L, 0.1 + k * 0.05), 0.18, (k % 2 == 0) and navy or gold, M.SmoothPlastic, nil, 0.55)
		end
		seg(m, "WingBolt", root + V(s * 0.6, 0.15, -0.15), root + V(s * 2.0, 0.85, -0.18), 0.12, glow, M.Neon, nil, 0.2)
	end
	for i = -1, 1 do
		seg(m, "TailFeather", V(0, 2.0, 0.9), V(i * 0.45, 1.2 + math.abs(i) * 0.08, 1.95), 0.5, navy, M.SmoothPlastic, nil, 0.15)
	end
	local crest = m:FindFirstChild("Bolt")
	Kit.light(crest, glow, 10, 1.5)
	Kit.particles(crest, { color = glow, size = 0.25, rate = 10, speed = 3, lifetime = 0.3, emission = 1 })
	return { bob = 0.15, spin = 0 }
end

local function singularity(m, c)
	local core, dark, glow = c[1], c[2], c[3]
	cyl(m, "Well", 0.12, 3.2, V(0, 0.06, 0), dark)
	cyl(m, "WellGlow", 0.08, 2.2, V(0, 0.13, 0), glow, M.Neon, 0.4)
	cyl(m, "Beam", 2.6, 0.35, V(0, 1.43, 0), glow, M.Neon, 0.45)
	local ctr = V(0, 4.0, 0)
	local heart = ball(m, "Core", 2.2, ctr, core, M.Neon)
	ball(m, "Lens", 2.9, ctr, glow, M.Glass, 0.75)
	Kit.light(heart, glow, 16, 2.5)
	face(m, { y = 4.12, d = 0.42, gap = 0.38, z = ballZ(ctr, 1.1) })
	local rings = {
		{ r = 1.9, tilt = 0.5, roll = 0.2, speed = 2.2, color = dark },
		{ r = 2.4, tilt = -0.7, roll = -0.3, speed = -1.6, color = Kit.shade(dark, 0.6) },
		{ r = 2.9, tilt = 0.15, roll = 0.1, speed = 1.0, color = { 25, 0, 45 } },
	}
	for _, rg in ipairs(rings) do
		for i = 1, 8 do
			local a = i / 8 * PI * 2
			local glint = i == 1
			local p = part(m, "Ring", V(0.32, 0.32, 0.6), CF(ctr) * ANG(rg.tilt, 0, rg.roll) * CF(math.cos(a) * rg.r, 0, math.sin(a) * rg.r) * ANG(0, -a, 0), glint and glow or rg.color, glint and M.Neon or M.SmoothPlastic)
			orbit(p, rg.speed)
		end
	end
	Kit.particles(heart, { color = glow, color2 = core, size = 0.3, rate = 10, speed = 0.8, lifetime = 1.2, emission = 1 })
	return { bob = 0.25, spin = 0 }
end

function A.Entity(m, c, id)
	if id == "Singularity" then
		return singularity(m, c)
	end
	local robe, rune, glow = c[1], c[2], c[3]
	local tiers = { { 2.9, 0.55 }, { 2.4, 1.3 }, { 1.95, 2.05 }, { 1.6, 2.75 } }
	for i, t in ipairs(tiers) do
		cyl(m, "Robe", 0.85, t[1], V(0, t[2], 0), Kit.shade(robe, 1 + (i % 2) * 0.25), M.Fabric)
	end
	for k = 1, 5 do
		local a = k / 5 * PI * 2 + 0.3
		part(m, "Tatter", V(0.45, 0.45, 0.3), CF(math.cos(a) * 1.25, 0.25, math.sin(a) * 1.25) * ANG(0, -a + PI / 2, PI / 4), robe, M.Fabric)
	end
	cyl(m, "Belt", 0.14, 2.0, V(0, 2.1, 0), rune, M.Neon)
	ball(m, "Hood", 2.0, V(0, 3.75, 0.05), robe, M.Fabric)
	part(m, "HoodPeak", V(0.8, 0.9, 0.8), CF(0, 4.6, 0.45) * ANG(0.6, 0, 0), robe, M.Fabric)
	local void = ball(m, "Void", 1.5, V(0, 3.7, -0.38), { 5, 0, 10 })
	Kit.light(void, glow, 10, 1.5)
	face(m, { y = 3.82, d = 0.34, gap = 0.3, z = -1.0, glow = glow, shine = false, mouth = "glowline", mouthGlow = glow, mouthY = 3.45, mouthZ = -1.05, mouthW = 0.5 })
	for s = -1, 1, 2 do
		seg(m, "Sleeve", V(s * 0.8, 3.0, 0), V(s * 1.45, 2.2, -0.55), 0.65, robe, M.Fabric)
		ball(m, "Hand", 0.35, V(s * 1.55, 2.0, -0.65), glow, M.Neon)
	end
	local ys = { 1.6, 2.6, 3.4, 2.0 }
	for k = 1, 4 do
		local a = k * PI / 2 + 0.4
		local p = part(m, "Shard", V(0.32, 0.8, 0.32), CF(math.cos(a) * 2.1, ys[k], math.sin(a) * 2.1) * ANG(0.3, 0.5, 0.4), rune, M.Neon, 0.1)
		orbit(p, (k % 2 == 0) and -1.1 or 1.1)
		selfSpin(p, 2)
	end
	Kit.particles(m:FindFirstChild("Robe"), { color = rune, color2 = robe, size = 0.4, rate = 8, speed = 0.6, lifetime = 1.6, accel = V(0, -0.5, 0), emission = 0.6 })
	return { bob = 0.35, spin = 0 }
end

function A.BlackHole(m, c, id)
	local void, disk, glow = c[1], c[2], c[3]
	local ctr = V(0, 3.4, 0)
	cyl(m, "JetSplash", 0.1, 1.4, V(0, 0.05, 0), glow, M.Neon, 0.5)
	cyl(m, "Jet", 2.2, 0.32, V(0, 1.2, 0), glow, M.Neon, 0.35)
	cyl(m, "Jet", 2.1, 0.32, V(0, 5.55, 0), glow, M.Neon, 0.35)
	local hole = ball(m, "Hole", 2.2, ctr, void)
	-- photon ring: a glowing disk just behind the hole, seen as a halo from the front
	part(m, "PhotonRing", V(0.06, 2.8, 2.8), CF(ctr + V(0, 0, 0.3)) * ANG(0, PI / 2, 0), glow, M.Neon, nil, "Cylinder")
	local tiltCF = CF(ctr) * ANG(0.32, 0, 0.12)
	cyl(m, "AccretionDisk", 0.1, 5.4, tiltCF, disk, M.Neon, 0.3)
	cyl(m, "InnerDisk", 0.14, 3.6, tiltCF, glow, M.Neon, 0.1)
	for i = 1, 6 do
		local a = i / 6 * PI * 2
		local rr = 2.4 + (i % 3) * 0.25
		orbit(ball(m, "Matter", 0.25 + (i % 2) * 0.1, (tiltCF * CF(math.cos(a) * rr, 0.1, math.sin(a) * rr)).Position, disk, M.Neon), 1.8)
	end
	face(m, { y = ctr.Y + 0.25, d = 0.36, gap = 0.38, z = ballZ(ctr, 1.1), glow = glow })
	Kit.light(hole, disk, 14, 2)
	Kit.particles(hole, { color = disk, color2 = glow, size = 0.3, rate = 12, speed = 1, lifetime = 0.9, emission = 1 })
	return { bob = 0.25, spin = 0 }
end

---------------------------------------------------------------------------
-- Mutations
---------------------------------------------------------------------------
local FACE_PARTS = { Eye = true, EyeShine = true, Brow = true, Mouth = true, Tooth = true, Blush = true, MouthGlow = true }

local MUT_FX = {
	Charged = { size = 0.3, speed = 5, lifetime = 0.35, rate = 18, accel = V(0, 0, 0) },
	Frozen = { size = 0.35, speed = 1, lifetime = 1.6, rate = 10, accel = V(0, -3, 0) },
	Molten = { size = 0.4, speed = 1.5, lifetime = 1.2, rate = 12, accel = V(0, 5, 0) },
	Golden = { size = 0.3, speed = 0.8, lifetime = 1.4, rate = 10, accel = V(0, 1, 0) },
	Corrupted = { size = 0.5, speed = 0.8, lifetime = 1.8, rate = 10, accel = V(0, 2, 0) },
}

local TINTS = {
	Golden = { color = { 255, 200, 40 }, amount = 0.65 },
	Frozen = { color = { 170, 230, 255 }, amount = 0.25 },
	Corrupted = { color = { 70, 10, 110 }, amount = 0.35 },
}

local function mutationFx(m, root, mutationId, lo, hi)
	local mut = mutationId and Config.Mutations[mutationId]
	if not mut then
		return
	end
	local tint = TINTS[mutationId]
	if tint then
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d ~= root and not FACE_PARTS[d.Name] and d.Material ~= M.Neon then
				d.Color = Kit.mix(d.Color, tint.color, tint.amount)
				if mutationId == "Golden" and d.Material ~= M.Glass then
					d.Material = M.Foil
					d.Reflectance = 0.25
				elseif mutationId == "Frozen" and d.Material ~= M.Glass then
					d.Material = M.Ice
				end
			end
		end
	end
	local h = hi.Y - lo.Y
	local w = math.max(hi.X - lo.X, hi.Z - lo.Z)
	local diameter = math.min(math.max(h, w) * 1.08, h + 0.9)
	local aura = Kit.ball(m, {
		name = "MutationAura",
		diameter = diameter,
		cf = CF((lo.X + hi.X) / 2, h / 2, (lo.Z + hi.Z) / 2),
		color = mut.color,
		material = M.ForceField,
		transparency = 0.15,
		collide = false,
		castShadow = false,
	})
	local fx = MUT_FX[mutationId] or MUT_FX.Charged
	Kit.particles(aura, {
		color = mut.color,
		color2 = Kit.mix(mut.color, WHITE, 0.5),
		size = fx.size * h / 5,
		rate = fx.rate,
		speed = fx.speed,
		lifetime = fx.lifetime,
		accel = fx.accel,
		emission = 1,
	})
	Kit.light(aura, mut.color, h * 1.6, 1.2)
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--[[
	DisasterModels.build(disasterId, mutationId) -> Model
]]
function DisasterModels.build(disasterId, mutationId)
	local def = Config.Disasters[disasterId]
	if not def then
		error("Unknown disaster " .. tostring(disasterId))
	end
	local c = def.colors
	local m = Instance.new("Model")
	m.Name = def.name

	local root = Kit.part(m, { name = "Root", size = V(0.4, 0.4, 0.4), transparency = 1, collide = false })
	m.PrimaryPart = root

	local builder = A[def.archetype] or A.Golem
	local anim = builder(m, c, disasterId) or {}

	local rarity = def.rarity or "Common"
	local targetH = DisasterModels.Heights[rarity] or 5
	local lo, hi = normalize(m, root, targetH, targetH * 1.2 + 1.5)
	mutationFx(m, root, mutationId, lo, hi)

	m:SetAttribute("DisasterId", disasterId)
	m:SetAttribute("Rarity", rarity)
	if mutationId and Config.Mutations[mutationId] then
		m:SetAttribute("Mutation", mutationId)
	end
	m:SetAttribute("AnimBob", anim.bob or 0.15)
	m:SetAttribute("AnimSpin", anim.spin or 0)
	Kit.setCollide(m, false)
	return m
end

return DisasterModels
