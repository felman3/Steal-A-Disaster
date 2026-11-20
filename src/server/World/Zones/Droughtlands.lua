--[[
	Zone 3 — Droughtlands. "Nothing grows. Everything cracks."
	A sun-baked clay pan split by dark crack lines (a few still glowing with
	trapped heat), a dry riverbed snaking across the route, banded sandstone
	mesas walling in the sides, saguaro cacti, dead trees, tumbleweeds and the
	bleached ribcage of something enormous arching over the trail. Behind the
	nest the route passes under the hero: a sandstone arch crowned by a giant
	horned cattle skull with embers smouldering in its eye sockets.

	Zone builder contract (see docs/ZONE_CONTRACT.md):
	  build(ctx) -> { palette = { accent, gate, gateMaterial, nest, nestMaterial } }
	  ctx: folder, index, zone, z0, z1, length, width, pathWidth, nest (Vector3),
	       nestRadius, rng(a,b), Kit, tree(parent, pos, scale, leafColor)
]]

local CLAY = { 206, 146, 98 }
local CLAY_LIGHT = { 224, 172, 120 }
local CLAY_DARK = { 184, 124, 84 }
local TRAIL = { 228, 196, 150 }
local CRACK = { 72, 42, 28 }
local BED = { 232, 210, 170 }
local BONE = { 236, 226, 200 }
local BONE_DARK = { 196, 182, 154 }
local CACTUS = { 88, 132, 74 }
local DEADWOOD = { 128, 106, 88 }
-- the Skull Arch stands right in front of the Frostfall gate; everything above its mouth is lifted
-- so the gate sign reads through the mouth from far away
local MOUTH_LIFT = 10
local HEAT = { 255, 130, 40 }
local BANDS = { { 196, 112, 74 }, { 226, 164, 108 }, { 178, 96, 66 }, { 236, 196, 146 }, { 206, 134, 88 } }

-- cylinder between two points (Roblox cylinders run along local X)
local function rod(Kit, parent, a, b, d, o)
	if math.abs(b.X - a.X) < 0.01 and math.abs(b.Z - a.Z) < 0.01 then
		b = b + Vector3.new(0.02, 0, 0)
	end
	local mid = (a + b) / 2
	return Kit.part(parent, {
		name = o.name or "Rod",
		shape = "Cylinder",
		size = Vector3.new((b - a).Magnitude, d, d),
		cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0),
		color = o.color,
		material = o.material,
		collide = o.collide,
		transparency = o.transparency,
		castShadow = o.castShadow,
	})
end

-- Safety net: collidable decoration that strays into the run corridor (kept
-- open through the whole zone so players can reach the next gate) or the nest
-- arena is made non-colliding.
local function clearPlayArea(ctx)
	local nest = ctx.nest
	local guard = ctx.nestRadius + 14.5
	local half = ctx.pathWidth / 2 + 0.5
	for _, d in ipairs(ctx.folder:GetDescendants()) do
		if d:IsA("BasePart") and d.CanCollide then
			local cf, s = d.CFrame, d.Size / 2
			local lx, ly, lz, hx, hy, hz = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local c = cf * Vector3.new(s.X * sx, s.Y * sy, s.Z * sz)
						lx, ly, lz = math.min(lx, c.X), math.min(ly, c.Y), math.min(lz, c.Z)
						hx, hy, hz = math.max(hx, c.X), math.max(hy, c.Y), math.max(hz, c.Z)
					end
				end
			end
			if hy > 0.8 then
				local inCorridor = ly < 12.5 and lx < half and hx > -half
				local cx = math.clamp(nest.X, lx, hx)
				local cz = math.clamp(nest.Z, lz, hz)
				local inNest = Vector3.new(cx - nest.X, 0, cz - nest.Z).Magnitude < guard
				if inCorridor or inNest then
					d.CanCollide = false
				end
			end
		end
	end
end

-- zig-zag crack line on the ground (decorative)
local function crack(ctx, parent, start, heading, segs, segLen, width, color)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local p = start
	local a = heading
	for i = 1, segs do
		a = a + ctx.rng(-0.7, 0.7)
		local len = segLen * rng(0.7, 1.3)
		local q = p + Vector3.new(math.cos(a) * len, 0, math.sin(a) * len)
		q = Vector3.new(math.clamp(q.X, -73, 73), 0, math.clamp(q.Z, ctx.z0 + 2, ctx.z1 - 2))
		if (q - p).Magnitude < 0.5 then
			break
		end
		len = (q - p).Magnitude
		local mid = (p + q) / 2
		Kit.part(parent, {
			name = "Crack",
			size = Vector3.new(width * (1 - 0.15 * i / segs), 0.12, len + width),
			cf = CFrame.lookAt(Vector3.new(mid.X, 0.03, mid.Z), Vector3.new(q.X, 0.03, q.Z)),
			color = color or CRACK,
			material = Enum.Material.Slate,
			collide = false,
			castShadow = false,
		})
		p = q
	end
	return p
end

local function mesa(ctx, parent, pos, w, d, h, bandOffset)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "Mesa")
	local layers = math.max(3, math.floor(h / 7))
	local lh = h / layers
	for i = 0, layers - 1 do
		local shrink = 1 - 0.045 * i
		Kit.part(m, {
			name = "Band",
			size = Vector3.new(w * shrink * rng(0.96, 1.04), lh + 0.2, d * shrink * rng(0.96, 1.04)),
			cf = CFrame.new(pos + Vector3.new(rng(-0.6, 0.6), lh * (i + 0.5), rng(-0.6, 0.6))) * CFrame.Angles(0, rng(-0.06, 0.06), 0),
			color = BANDS[(i + bandOffset) % #BANDS + 1],
			material = Enum.Material.Sandstone,
		})
	end
	-- flat cap of darker desert varnish
	local top = 1 - 0.045 * layers
	Kit.part(m, { name = "Cap", size = Vector3.new(w * top + 1, 1.2, d * top + 1), cf = CFrame.new(pos + Vector3.new(0, h + 0.5, 0)), color = { 150, 86, 58 }, material = Enum.Material.Sandstone })
	-- talus at the foot
	for i = 1, 2 do
		local a = rng(0, 6.28)
		local r = math.min(w, d) * 0.5
		Kit.part(m, { name = "Talus", size = Vector3.new(rng(4, 7), rng(2, 4), rng(4, 7)), cf = CFrame.new(pos + Vector3.new(math.cos(a) * r, 1, math.sin(a) * r)) * CFrame.Angles(rng(-0.3, 0.3), rng(0, 3), rng(-0.3, 0.3)), color = BANDS[(i + bandOffset) % #BANDS + 1], material = Enum.Material.Sandstone })
	end
	return m
end

local function saguaro(ctx, parent, pos, h)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "Saguaro")
	local col = Kit.shade(CACTUS, rng(0.9, 1.1))
	local d = 1.6 + h * 0.08
	Kit.cylinder(m, { name = "Trunk", height = h, diameter = d, cf = CFrame.new(pos + Vector3.new(0, h / 2, 0)), color = col, material = Enum.Material.Plastic })
	Kit.ball(m, { name = "Top", diameter = d, cf = CFrame.new(pos + Vector3.new(0, h, 0)), color = col, material = Enum.Material.Plastic })
	local arms = (h > 7) and 2 or 1
	local a0 = rng(0, 6.28)
	for i = 1, arms do
		local a = a0 + (i - 1) * math.pi + rng(-0.3, 0.3)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local y = h * rng(0.38, 0.58)
		local reach = d * 1.5
		local ad = d * 0.72
		rod(Kit, m, pos + Vector3.new(0, y, 0), pos + dir * reach + Vector3.new(0, y, 0), ad, { name = "ArmOut", color = col, material = Enum.Material.Plastic })
		local up = h * rng(0.22, 0.34)
		Kit.cylinder(m, { name = "ArmUp", height = up, diameter = ad, cf = CFrame.new(pos + dir * reach + Vector3.new(0, y + up / 2, 0)), color = col, material = Enum.Material.Plastic })
		Kit.ball(m, { name = "ArmTip", diameter = ad, cf = CFrame.new(pos + dir * reach + Vector3.new(0, y + up, 0)), color = col, material = Enum.Material.Plastic })
	end
	return m
end

local function deadTree(ctx, parent, pos, h)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "DeadTree")
	local top = pos + Vector3.new(rng(-1.5, 1.5), h, rng(-1.5, 1.5))
	rod(Kit, m, pos + Vector3.new(0, -0.5, 0), top, 1.3, { name = "Trunk", color = DEADWOOD, material = Enum.Material.Wood })
	for i = 1, 3 do
		local t = 0.45 + i * 0.15
		local from = pos:Lerp(top, t)
		local a = rng(0, 6.28)
		local len = h * rng(0.3, 0.45)
		local to = from + Vector3.new(math.cos(a) * len, len * rng(0.4, 0.9), math.sin(a) * len)
		rod(Kit, m, from, to, 0.6, { name = "Branch", color = Kit.shade(DEADWOOD, 0.9), material = Enum.Material.Wood, collide = false })
	end
	return m
end

local function tumbleweed(ctx, parent, pos, d)
	local Kit = ctx.Kit
	Kit.ball(parent, { name = "Tumbleweed", diameter = d, cf = CFrame.new(pos + Vector3.new(0, d / 2 - 0.2, 0)), color = { 176, 136, 84 }, material = Enum.Material.Grass, transparency = 0.3, collide = false })
	Kit.ball(parent, { name = "TumbleweedCore", diameter = d * 0.65, cf = CFrame.new(pos + Vector3.new(0.2, d / 2 - 0.2, 0.1)), color = { 140, 104, 64 }, material = Enum.Material.Grass, collide = false })
end

-- the bleached ribcage of a colossal beast, ribs bowing over the trail
local function ribcage(ctx, parent, zA, zB)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "Ribcage")
	local spineX = -36
	local n = 9
	for i = 0, n - 1 do
		local z = zA + (zB - zA) * i / (n - 1)
		Kit.part(m, { name = "Vertebra", size = Vector3.new(3.6, 2.6, 3.2), cf = CFrame.new(spineX, 1, z) * CFrame.Angles(0, rng(-0.1, 0.1), 0.1), color = BONE, material = Enum.Material.Limestone })
		Kit.part(m, { name = "Spinous", size = Vector3.new(1, 3.2, 1.4), cf = CFrame.new(spineX - 1.4, 3.4, z) * CFrame.Angles(0, 0, 0.5), color = BONE_DARK, material = Enum.Material.Limestone })
	end
	-- ribs (the middle ones are the tallest; two are snapped off)
	local ribs = 6
	for r = 0, ribs - 1 do
		local z = zA + 3 + r * (zB - zA - 6) / (ribs - 1)
		local H = 16 + 7 * math.sin((r + 0.5) / ribs * math.pi)
		local c, a = -8, 28
		local broken = (r == 1 or r == 4)
		local stopAt = broken and 3 or 0
		local prev
		for k = 6, stopAt, -1 do
			local th = k / 6 * math.pi
			local p = Vector3.new(c + a * math.cos(th), H * math.sin(th) + 0.4, z - math.sin(th) * 2.5)
			if prev then
				rod(Kit, m, prev, p, 1.9 - (6 - k) * 0.12, { name = "Rib", color = BONE, material = Enum.Material.Limestone })
			end
			prev = p
		end
		if broken then
			-- the lost half lies in the dust off the trail
			rod(Kit, m, Vector3.new(24, 0.6, z - 3), Vector3.new(34, 0.8, z + 4), 1.5, { name = "RibShard", color = BONE_DARK, material = Enum.Material.Limestone })
		end
	end
	-- pelvis and a trailing tail
	Kit.part(m, { name = "Pelvis", size = Vector3.new(9, 4, 6), cf = CFrame.new(spineX - 3, 1.6, zB + 6) * CFrame.Angles(0.2, 0.3, 0.15), color = BONE_DARK, material = Enum.Material.Limestone })
	for i = 1, 5 do
		local t = i / 5
		Kit.ball(m, { name = "TailBone", diameter = 2.6 - t * 1.4, cf = CFrame.new(spineX - 6 - t * 18, 0.6, zB + 10 + math.sin(t * 3) * 5), color = BONE, material = Enum.Material.Limestone })
	end
	return m
end

-- hero: a sandstone arch crowned by a giant horned cattle skull
local function skullArch(ctx, parent, zc)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "SkullArch")
	local front = zc - 8
	for side = -1, 1, 2 do
		for i = 0, 4 do
			Kit.part(m, { name = "ArchPillar", size = Vector3.new(14 - i * 0.6, 6.2, 16 - i * 0.6), cf = CFrame.new(side * 21.5, 3 + i * 6, zc) * CFrame.Angles(0, rng(-0.03, 0.03), 0), color = BANDS[(i + 1) % #BANDS + 1], material = Enum.Material.Sandstone })
		end
		Kit.part(m, { name = "Rubble", size = Vector3.new(5, 3, 4), cf = CFrame.new(side * 30, 1.2, zc - 6) * CFrame.Angles(0.2, 0.5, 0.1), color = BANDS[2], material = Enum.Material.Sandstone })
	end
	Kit.part(m, { name = "Lintel", size = Vector3.new(58, 7, 16), cf = CFrame.new(0, 21.5, zc), color = BANDS[4], material = Enum.Material.Sandstone })
	Kit.part(m, { name = "LintelBand", size = Vector3.new(58.4, 1.6, 16.4), cf = CFrame.new(0, 19.6, zc), color = BANDS[3], material = Enum.Material.Sandstone })
	-- skull: snout drops toward the lintel, cranium above, cheekbones taper
	Kit.part(m, { name = "Snout", size = Vector3.new(15, 11, 12), cf = CFrame.new(0, 30.5, zc - 1), color = BONE, material = Enum.Material.Limestone })
	Kit.part(m, { name = "Muzzle", size = Vector3.new(12, 4, 11), cf = CFrame.new(0, 26.5, zc - 1.5), color = BONE_DARK, material = Enum.Material.Limestone })
	for side = -1, 1, 2 do
		Kit.part(m, { name = "Nostril", size = Vector3.new(2.2, 3, 0.6), cf = CFrame.new(side * 3, 28.5, zc - 7.2), color = { 52, 34, 26 }, material = Enum.Material.Slate })
		Kit.part(m, { name = "Cheekbone", size = Vector3.new(7, 13, 13), cf = CFrame.new(side * 10, 34, zc) * CFrame.Angles(0, 0, side * 0.32), color = BONE, material = Enum.Material.Limestone })
	end
	Kit.part(m, { name = "Cranium", size = Vector3.new(30, 17, 16), cf = CFrame.new(0, 44.5, zc), color = BONE, material = Enum.Material.Limestone })
	Kit.part(m, { name = "Crown", size = Vector3.new(22, 4, 13), cf = CFrame.new(0, 54.5, zc + 0.5), color = BONE, material = Enum.Material.Limestone })
	Kit.part(m, { name = "Brow", size = Vector3.new(31, 2.6, 3), cf = CFrame.new(0, 48.6, front - 0.6), color = BONE_DARK, material = Enum.Material.Limestone })
	for side = -1, 1, 2 do
		Kit.part(m, { name = "EyeSocket", size = Vector3.new(8, 7, 0.8), cf = CFrame.new(side * 7.5, 43.5, front - 0.3), color = { 40, 24, 18 }, material = Enum.Material.Slate })
		local ember = Kit.ball(m, { name = "Ember", diameter = 2.4, cf = CFrame.new(side * 7.5, 43, front - 0.6), color = HEAT, material = Enum.Material.Neon, collide = false })
		Kit.light(ember, HEAT, 22, 1.6)
		-- horn: a boss, then a sweep out and up
		Kit.ball(m, { name = "HornBoss", diameter = 7, cf = CFrame.new(side * 15, 47, zc), color = BONE_DARK, material = Enum.Material.Limestone })
		local pts = {
			Vector3.new(side * 15, 47, zc),
			Vector3.new(side * 27, 45, zc - 1),
			Vector3.new(side * 38, 48, zc - 2),
			Vector3.new(side * 46, 55, zc - 2.5),
			Vector3.new(side * 49, 64, zc - 2),
		}
		local ds = { 6.2, 5, 3.8, 2.6 }
		for i = 1, 4 do
			local col = Kit.mix(BONE, { 120, 96, 72 }, (i - 1) / 4)
			rod(Kit, m, pts[i], pts[i + 1], ds[i], { name = "Horn", color = col, material = Enum.Material.Limestone })
		end
		Kit.ball(m, { name = "HornTip", diameter = 2, cf = CFrame.new(pts[5]), color = { 110, 88, 66 }, material = Enum.Material.Limestone })
	end
	-- weathering cracks across the bone
	Kit.part(m, { name = "BoneCrack", size = Vector3.new(0.4, 9, 0.3), cf = CFrame.new(-2, 47, front - 0.1) * CFrame.Angles(0, 0, 0.4), color = { 120, 100, 80 }, material = Enum.Material.Slate, collide = false })
	Kit.part(m, { name = "BoneCrack", size = Vector3.new(0.4, 6, 0.3), cf = CFrame.new(3, 33, zc - 7.1) * CFrame.Angles(0, 0, -0.5), color = { 120, 100, 80 }, material = Enum.Material.Slate, collide = false })
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") and c.Name ~= "ArchPillar" and c.Name ~= "Rubble" then
			c.CFrame = c.CFrame + Vector3.new(0, MOUTH_LIFT, 0)
		end
	end
	return m
end

return function(ctx)
	local Kit = ctx.Kit
	local f = ctx.folder
	local z0, z1, W = ctx.z0, ctx.z1, ctx.width
	local rng = ctx.rng
	local nest = ctx.nest
	local half = ctx.pathWidth / 2
	local nestGuard = ctx.nestRadius + 14

	local function clear(x, z, r)
		if math.abs(x) - r < half + 2 then
			return false
		end
		if (Vector3.new(x, 0, z) - Vector3.new(nest.X, 0, nest.Z)).Magnitude - r * 1.42 < nestGuard + 1 then
			return false
		end
		if z - r < z0 + 3 or z + r > z1 - 2 then
			return false
		end
		if math.abs(x) < 26 + r and z - r < z0 + 6 then
			return false
		end
		return true
	end

	---------------------------------------------------------------------
	-- ground: baked clay plates in slightly different tones
	---------------------------------------------------------------------
	local cols = { { -75, -45 }, { -45, -13 }, { -13, 13 }, { 13, 45 }, { 45, 75 } }
	local rows = 7
	local rowLen = ctx.length / rows
	for r = 0, rows - 1 do
		for c, span in ipairs(cols) do
			local pick = ((r * 3 + c) % 3 == 0) and CLAY_DARK or (((r + c) % 2 == 0) and CLAY or CLAY_LIGHT)
			Kit.part(f, { name = "Ground", size = Vector3.new(span[2] - span[1], 4, rowLen), cf = CFrame.new((span[1] + span[2]) / 2, -2, z0 + (r + 0.5) * rowLen), color = Kit.shade(pick, rng(0.96, 1.04)), material = (c == 3) and Enum.Material.Sandstone or Enum.Material.Ground })
		end
	end
	-- worn trail of packed dust to the nest
	local trailEnd = nest.Z - nestGuard + 8
	Kit.part(f, { name = "Trail", size = Vector3.new(ctx.pathWidth - 6, 0.2, trailEnd - z0), cf = CFrame.new(0, 0.06, (z0 + trailEnd) / 2), color = TRAIL, material = Enum.Material.Sand, collide = false })
	for i = 0, 5 do
		for side = -1, 1, 2 do
			Kit.part(f, { name = "TrailEdge", size = Vector3.new(rng(3, 5), 0.18, rng(12, 18)), cf = CFrame.new(side * (half - 3 + rng(0, 1.5)), 0.05, z0 + 10 + i * (trailEnd - z0 - 10) / 6) * CFrame.Angles(0, rng(-0.3, 0.3), 0), color = Kit.mix(TRAIL, CLAY, 0.5), material = Enum.Material.Sand, collide = false })
		end
	end

	---------------------------------------------------------------------
	-- cracks: a dark network over the whole pan, radiating from the nest
	---------------------------------------------------------------------
	for i = 1, 24 do
		local x = rng(-70, 70)
		local z = rng(z0 + 6, z1 - 10)
		crack(ctx, f, Vector3.new(x, 0, z), rng(0, 6.28), 4, rng(4, 7), rng(0.3, 0.55))
	end
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2 + rng(-0.2, 0.2)
		local start = nest + Vector3.new(math.cos(a), 0, math.sin(a)) * (ctx.nestRadius + 8)
		crack(ctx, f, start, a, 3, rng(5, 8), 0.6)
	end
	-- deep fissures still glowing with trapped heat
	for _, s in ipairs({ { -42, z0 + 30, 0.3 }, { 40, z0 + 84, 2.6 }, { -56, z0 + 186, 1.4 } }) do
		local start = Vector3.new(s[1], 0, s[2])
		crack(ctx, f, start, s[3], 3, 8, 1.6)
		local p = start + Vector3.new(math.cos(s[3]) * 10, 0, math.sin(s[3]) * 10)
		local glow = Kit.part(f, { name = "HeatSeam", size = Vector3.new(0.5, 0.14, 16), cf = CFrame.lookAt(Vector3.new(start.X, 0.06, start.Z), Vector3.new(p.X, 0.06, p.Z)) * CFrame.new(0, 0, -6), color = HEAT, material = Enum.Material.Neon, collide = false, castShadow = false })
		Kit.light(glow, HEAT, 14, 0.9)
	end

	---------------------------------------------------------------------
	-- dry riverbed meandering across the pan (flush, crosses the trail)
	---------------------------------------------------------------------
	local river = {
		Vector3.new(-80, 0, z0 + 152), Vector3.new(-52, 0, z0 + 136), Vector3.new(-26, 0, z0 + 120),
		Vector3.new(0, 0, z0 + 104), Vector3.new(24, 0, z0 + 90), Vector3.new(48, 0, z0 + 64), Vector3.new(80, 0, z0 + 50),
	}
	for i = 1, #river - 1 do
		local a, b = river[i], river[i + 1]
		local len = (b - a).Magnitude + 6
		local cf = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0.05, 0), b + Vector3.new(0, 0.05, 0))
		Kit.part(f, { name = "Riverbed", size = Vector3.new(12, 0.16, len), cf = cf, color = BED, material = Enum.Material.Sand, collide = false, castShadow = false })
		for side = -1, 1, 2 do
			Kit.part(f, { name = "RiverBank", size = Vector3.new(1.4, 0.22, len), cf = cf * CFrame.new(side * 6.4, 0.02, 0), color = Kit.shade(CLAY_DARK, 0.85), material = Enum.Material.Ground, collide = false, castShadow = false })
		end
		for k = 1, 3 do
			local p = a:Lerp(b, rng(0, 1)) + Vector3.new(rng(-4, 4), 0, rng(-4, 4))
			Kit.ball(f, { name = "Pebble", diameter = rng(0.6, 1.6), cf = CFrame.new(p.X, 0.15, p.Z), color = Kit.shade({ 190, 170, 150 }, rng(0.8, 1.1)), material = Enum.Material.Pebble, collide = false })
		end
	end

	---------------------------------------------------------------------
	-- banded mesas & buttes walling in the sides
	---------------------------------------------------------------------
	local mesas = {
		{ -63, z0 + 32, 20, 26, 44 }, { -62, z0 + 108, 22, 30, 34 }, { -64, z0 + 212, 20, 24, 54 },
		{ 64, z0 + 56, 22, 28, 40 }, { 64, z0 + 140, 20, 24, 50 }, { 66, z0 + 228, 16, 20, 30 },
		{ -48, z0 + 64, 8, 8, 26 }, { 52, z0 + 104, 7, 8, 32 },
	}
	for i, s in ipairs(mesas) do
		mesa(ctx, f, Vector3.new(s[1], 0, s[2]), s[3], s[4], s[5], i)
	end

	---------------------------------------------------------------------
	-- saguaros, dead trees and tumbleweeds
	---------------------------------------------------------------------
	local cacti = {
		{ -22, z0 + 18, 9 }, { 23, z0 + 44, 11 }, { -30, z0 + 96, 7 }, { 34, z0 + 124, 12 },
		{ -40, z0 + 150, 10 }, { 22, z0 + 12, 6 }, { -54, z0 + 240, 12 }, { 56, z0 + 250, 9 },
		{ 44, z0 + 30, 8 }, { -46, z0 + 8, 10 }, { 58, z0 + 186, 8 }, { -64, z0 + 160, 9 },
	}
	for _, s in ipairs(cacti) do
		if clear(s[1], s[2], 3) then
			saguaro(ctx, f, Vector3.new(s[1], 0, s[2]), s[3])
		end
	end
	for _, s in ipairs({ { 30, z0 + 70, 12 }, { -26, z0 + 56, 10 }, { 46, z0 + 160, 14 }, { -52, z0 + 132, 11 }, { 36, z0 + 238, 12 }, { -36, z0 + 250, 10 } }) do
		if clear(s[1], s[2], 4) then
			deadTree(ctx, f, Vector3.new(s[1], 0, s[2]), s[3])
		end
	end
	for i = 1, 8 do
		tumbleweed(ctx, f, Vector3.new(rng(-60, 60), 0, rng(z0 + 10, z1 - 30)), rng(2.4, 4))
	end

	---------------------------------------------------------------------
	-- the ribcage the trail runs through
	---------------------------------------------------------------------
	ribcage(ctx, f, z0 + 70, z0 + 116)

	---------------------------------------------------------------------
	-- hero: the skull arch behind the nest; dust blows across it
	---------------------------------------------------------------------
	skullArch(ctx, f, z1 - 20)
	local dust = Kit.part(f, { name = "DustDrift", size = Vector3.new(140, 6, 40), cf = CFrame.new(0, 3, z0 + 60), transparency = 1, collide = false, castShadow = false })
	dust.CanQuery = false
	Kit.particles(dust, { color = { 230, 200, 150 }, color2 = { 210, 170, 120 }, size = 2.5, sizeEnd = 5, transparency = 0.75, rate = 6, lifetime = 4, speed = 4, spread = 20, emission = 0, accel = Vector3.new(6, 0, 0), texture = "rbxasset://textures/particles/smoke_main.dds" })

	clearPlayArea(ctx)

	return {
		palette = {
			accent = { 255, 176, 72 },
			gate = { 196, 138, 88 },
			gateMaterial = Enum.Material.Sandstone,
			nest = { 178, 124, 84 },
			nestMaterial = Enum.Material.Sandstone,
		},
	}
end
