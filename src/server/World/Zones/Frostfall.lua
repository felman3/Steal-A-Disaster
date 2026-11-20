--[[
	Zone 4 — Frostfall. "The cold bites back."
	A snowbound pass: packed-snow trail over deep snow with glacier and ice
	sheets, wind-carved drifts banked against the walls, snow-capped pines,
	jagged glowing ice crystals, a frozen pond, frost lanterns and an ice arch
	dripping icicles over the route. Behind the nest rises the hero: a glacier
	wall carved into an ice cathedral, twin spired towers around a gateway the
	route runs through, a glowing rose window, and an aurora above it all.

	Zone builder contract (see docs/ZONE_CONTRACT.md):
	  build(ctx) -> { palette = { accent, gate, gateMaterial, nest, nestMaterial } }
	  ctx: folder, index, zone, z0, z1, length, width, pathWidth, nest (Vector3),
	       nestRadius, rng(a,b), Kit, tree(parent, pos, scale, leafColor)
]]

local SNOW = { 238, 244, 252 }
local SNOW_SHADE = { 214, 226, 242 }
local PACKED = { 196, 210, 228 }
local ICE = { 162, 212, 242 }
local GLACIER = { 150, 200, 236 }
local GLACIER_DEEP = { 112, 168, 220 }
local PINE = { 38, 80, 60 }
local PINE_LIGHT = { 52, 98, 70 }
local BARK = { 88, 64, 50 }
local COLD = { 120, 214, 255 }
local AURORA = { { 110, 255, 200 }, { 130, 190, 255 }, { 180, 140, 255 }, { 100, 240, 230 } }

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

-- square pyramid (or a two-faced chisel point when `faces` = 2) from wedges.
-- `base` is the CFrame at the centre of the bottom face; slopes face outward.
local function peak(Kit, parent, base, sx, sz, h, o, faces)
	faces = faces or 4
	local step = (faces == 4) and 1 or 2
	for i = 0, 3, step do
		local even = (i % 2 == 0)
		local w = even and sx or sz
		local d = even and sz or sx
		Kit.part(parent, {
			name = o.name or "Peak",
			shape = "Wedge",
			size = Vector3.new(w, h, d / 2),
			cf = base * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, h / 2, -d / 4),
			color = o.color,
			material = o.material,
			transparency = o.transparency,
			reflectance = o.reflectance,
			collide = o.collide,
		})
	end
end

local function pine(ctx, parent, pos, scale, tiers)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "Pine")
	local trunkH = 4 * scale
	Kit.cylinder(m, { name = "Trunk", height = trunkH + 2, diameter = 1.4 * scale, cf = CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)), color = BARK, material = Enum.Material.Wood })
	local y = trunkH * 0.6
	local yaw = rng(0, 1.57)
	for t = 1, tiers do
		local k = 1 - (t - 1) / (tiers + 0.6)
		local s = 12 * scale * k
		local h = 6.5 * scale * (0.85 + 0.15 * k)
		local base = CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, yaw + t * 0.785, 0)
		peak(Kit, m, base, s, s, h, { name = "Needles", color = (t % 2 == 0) and PINE_LIGHT or PINE, material = Enum.Material.Grass })
		-- snow resting on the upper half of every tier above the lowest
		if t >= 2 then
			peak(Kit, m, base * CFrame.new(0, h * 0.5 - 0.15, 0), s * 0.56, s * 0.56, h * 0.56, { name = "SnowCap", color = SNOW, material = Enum.Material.Snow })
		end
		y = y + h * 0.62
	end
	return m
end

local function iceCluster(ctx, parent, pos, n, scale, lit)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "IceCrystals")
	for i = 1, n do
		local w = rng(1.6, 3) * scale
		local h = rng(5, 11) * scale * ((i == 1) and 1.35 or 1)
		local off = (i == 1) and Vector3.new(0, 0, 0) or Vector3.new(rng(-2.5, 2.5) * scale, 0, rng(-2.5, 2.5) * scale)
		local base = CFrame.new(pos + off + Vector3.new(0, -0.5, 0)) * CFrame.Angles(rng(-0.35, 0.35), rng(0, 3.14), rng(-0.35, 0.35))
		local col = (i % 2 == 0) and ICE or Kit.mix(ICE, { 255, 255, 255 }, 0.35)
		Kit.part(m, { name = "Shard", size = Vector3.new(w, h, w * 0.8), cf = base * CFrame.new(0, h / 2, 0), color = col, material = Enum.Material.Glass, transparency = 0.25, reflectance = 0.15 })
		peak(Kit, m, base * CFrame.new(0, h, 0), w, w * 0.8, w * 1.1, { name = "ShardTip", color = col, material = Enum.Material.Glass, transparency = 0.25, reflectance = 0.15 }, 2)
	end
	if lit then
		local core = Kit.ball(m, { name = "ColdCore", diameter = 1.4 * scale, cf = CFrame.new(pos + Vector3.new(0, 1.2 * scale, 0)), color = COLD, material = Enum.Material.Neon, collide = false })
		Kit.light(core, COLD, 18 * scale, 1.3)
	end
	return m
end

-- wind-packed drift: a wedge whose slope faces `dir`
local function drift(ctx, parent, pos, dir, len, h, depth)
	local Kit = ctx.Kit
	local c = pos + Vector3.new(0, h / 2 - 0.1, 0)
	return Kit.part(parent, { name = "Snowdrift", shape = "Wedge", size = Vector3.new(len, h, depth), cf = CFrame.lookAt(c, c + dir), color = Kit.shade(SNOW, ctx.rng(0.95, 1)), material = Enum.Material.Snow })
end

local function icicles(ctx, parent, from, to, y, count, maxLen)
	local Kit = ctx.Kit
	local rng = ctx.rng
	for i = 1, count do
		local p = from:Lerp(to, (i - 0.5) / count)
		local len = rng(maxLen * 0.4, maxLen)
		local w = rng(0.5, 0.9)
		Kit.part(parent, { name = "Icicle", size = Vector3.new(w, len, w), cf = CFrame.new(p.X + rng(-0.3, 0.3), y - len / 2, p.Z) * CFrame.Angles(0, 0.785, 0), color = Kit.mix(ICE, { 255, 255, 255 }, 0.4), material = Enum.Material.Ice, transparency = 0.15, collide = false })
	end
end

local function lantern(ctx, parent, pos)
	local Kit = ctx.Kit
	Kit.cylinder(parent, { name = "LanternPost", height = 9, diameter = 0.7, cf = CFrame.new(pos + Vector3.new(0, 4.5, 0)), color = { 60, 70, 86 }, material = Enum.Material.Metal })
	local lamp = Kit.part(parent, { name = "FrostLantern", size = Vector3.new(1.4, 1.8, 1.4), cf = CFrame.new(pos + Vector3.new(0, 9.6, 0)), color = COLD, material = Enum.Material.Neon })
	Kit.light(lamp, COLD, 20, 1.1)
	Kit.part(parent, { name = "LanternSnow", size = Vector3.new(2, 0.5, 2), cf = CFrame.new(pos + Vector3.new(0, 10.75, 0)), color = SNOW, material = Enum.Material.Snow })
end

-- hero: the glacier wall carved into an ice cathedral
local function cathedral(ctx, parent, zc)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "IceCathedral")
	local depth = 22
	local front = zc - depth / 2
	-- twin towers framing the gateway
	for side = -1, 1, 2 do
		local x = side * 21
		Kit.part(m, { name = "TowerBase", size = Vector3.new(15, 6, depth + 2), cf = CFrame.new(side * 21.8, 3, zc), color = GLACIER_DEEP, material = Enum.Material.Glacier })
		Kit.part(m, { name = "Tower", size = Vector3.new(14, 56, depth - 2), cf = CFrame.new(x, 32, zc), color = GLACIER, material = Enum.Material.Glacier })
		Kit.part(m, { name = "TowerSnow", size = Vector3.new(14.6, 1.4, depth - 1.4), cf = CFrame.new(x, 60.5, zc), color = SNOW, material = Enum.Material.Snow })
		peak(Kit, m, CFrame.new(x, 61, zc), 12, 12, 24, { name = "Spire", color = Kit.mix(ICE, { 255, 255, 255 }, 0.3), material = Enum.Material.Glass, transparency = 0.15, reflectance = 0.2 })
		-- glowing lancet window up each tower
		local slit = Kit.part(m, { name = "Lancet", size = Vector3.new(3, 16, 0.4), cf = CFrame.new(x, 40, front + 0.8), color = COLD, material = Enum.Material.Neon, transparency = 0.2, collide = false })
		Kit.light(slit, COLD, 24, 1)
		-- glacier wings out to the walls, jagged on top
		local wingX = { 36, 52, 67 }
		local wingH = { 44, 52, 38 }
		for i = 1, 3 do
			local wx = side * wingX[i]
			local w = (i == 3) and 16 or 17
			local h = wingH[i] + rng(-3, 3)
			Kit.part(m, { name = "GlacierWall", size = Vector3.new(w, h, depth - 4 + i * 1.5), cf = CFrame.new(wx, h / 2, zc + 1) * CFrame.Angles(0, rng(-0.04, 0.04), 0), color = (i % 2 == 0) and GLACIER or GLACIER_DEEP, material = Enum.Material.Glacier })
			Kit.part(m, { name = "GlacierShard", size = Vector3.new(w * 0.5, 14, 7), cf = CFrame.new(wx + rng(-3, 3), h + 3, zc + rng(-3, 3)) * CFrame.Angles(rng(-0.3, 0.3), rng(0, 1), side * rng(0.2, 0.5)), color = Kit.mix(GLACIER, { 255, 255, 255 }, 0.3), material = Enum.Material.Ice, transparency = 0.1 })
		end
		-- frozen waterfall pouring down the wing face
		Kit.part(m, { name = "FrozenFall", size = Vector3.new(6, 38, 1.2), cf = CFrame.new(side * 44, 19, front + 1.2), color = Kit.mix(ICE, { 255, 255, 255 }, 0.5), material = Enum.Material.Glass, transparency = 0.3, reflectance = 0.2, collide = false })
		icicles(ctx, m, Vector3.new(side * 30, 0, front - 0.6), Vector3.new(side * 60, 0, front - 0.6), 30, 5, 6)
	end
	-- the gateway: header block, pointed arch ribs and the rose window
	Kit.part(m, { name = "Header", size = Vector3.new(28.5, 30, depth - 4), cf = CFrame.new(0, 37, zc), color = GLACIER, material = Enum.Material.Glacier })
	Kit.part(m, { name = "HeaderSnow", size = Vector3.new(29, 1.4, depth - 3.4), cf = CFrame.new(0, 52.6, zc), color = SNOW, material = Enum.Material.Snow })
	peak(Kit, m, CFrame.new(0, 53, zc), 28, depth - 4, 12, { name = "Gable", color = GLACIER_DEEP, material = Enum.Material.Glacier }, 2)
	for side = -1, 1, 2 do
		local rib = Kit.part(m, { name = "ArchRib", size = Vector3.new(2, 15, 2), cf = CFrame.lookAt(Vector3.new(side * 7, 16.5, front - 1.4), Vector3.new(side * 7, 16.5, front - 5)) * CFrame.Angles(0, 0, side * 0.62), color = Kit.mix(ICE, { 255, 255, 255 }, 0.5), material = Enum.Material.Ice, collide = false })
		rib.CastShadow = false
	end
	local rose = Kit.part(m, { name = "RoseWindow", shape = "Cylinder", size = Vector3.new(0.6, 13, 13), cf = CFrame.new(0, 37, front - 1.5) * CFrame.Angles(0, math.pi / 2, 0), color = COLD, material = Enum.Material.Neon, transparency = 0.1, collide = false })
	Kit.light(rose, COLD, 60, 2)
	Kit.part(m, { name = "RoseFrame", shape = "Cylinder", size = Vector3.new(0.6, 16, 16), cf = CFrame.new(0, 37, front - 1.2) * CFrame.Angles(0, math.pi / 2, 0), color = SNOW, material = Enum.Material.Ice })
	for i = 0, 2 do
		Kit.part(m, { name = "RoseTracery", size = Vector3.new(0.7, 13, 0.4), cf = CFrame.new(0, 37, front - 1.9) * CFrame.Angles(0, 0, i * math.pi / 3), color = SNOW, material = Enum.Material.Ice, collide = false })
	end
	icicles(ctx, m, Vector3.new(-12.5, 0, front + 0.5), Vector3.new(12.5, 0, front + 0.5), 22, 7, 5)
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
	-- ground: deep snow with glacier sheets toward the walls
	---------------------------------------------------------------------
	local cols = { { -75, -45 }, { -45, -13 }, { -13, 13 }, { 13, 45 }, { 45, 75 } }
	local rows = 7
	local rowLen = ctx.length / rows
	for r = 0, rows - 1 do
		for c, span in ipairs(cols) do
			local edge = (c == 1 or c == 5) and (r % 3 == 1)
			Kit.part(f, {
				name = "Ground",
				size = Vector3.new(span[2] - span[1], 4, rowLen),
				cf = CFrame.new((span[1] + span[2]) / 2, -2, z0 + (r + 0.5) * rowLen),
				color = edge and GLACIER or Kit.shade(((r + c) % 2 == 0) and SNOW or SNOW_SHADE, rng(0.98, 1.01)),
				material = edge and Enum.Material.Glacier or Enum.Material.Snow,
			})
		end
	end
	-- packed-snow trail with sheets of ice across it
	local trailEnd = nest.Z - nestGuard + 8
	Kit.part(f, { name = "Trail", size = Vector3.new(ctx.pathWidth - 4, 0.2, trailEnd - z0), cf = CFrame.new(0, 0.06, (z0 + trailEnd) / 2), color = PACKED, material = Enum.Material.Snow, collide = false })
	for i = 0, 5 do
		for side = -1, 1, 2 do
			Kit.part(f, { name = "TrailEdge", size = Vector3.new(rng(2.5, 4), 0.18, rng(12, 18)), cf = CFrame.new(side * (half - 2 + rng(0, 1.5)), 0.05, z0 + 10 + i * (trailEnd - z0 - 10) / 6) * CFrame.Angles(0, rng(-0.3, 0.3), 0), color = Kit.mix(PACKED, SNOW, 0.5), material = Enum.Material.Snow, collide = false })
		end
	end
	for i = 1, 12 do
		local x = rng(-66, 66)
		local z = rng(z0 + 8, z1 - 30)
		Kit.cylinder(f, { name = "IceSheet", height = 0.16, diameter = rng(6, 15), cf = CFrame.new(x, 0.08, z), color = (i % 3 == 0) and GLACIER or ICE, material = (i % 3 == 0) and Enum.Material.Glacier or Enum.Material.Ice, reflectance = 0.2, collide = false, castShadow = false })
	end
	-- a polished ice ring around the nest
	Kit.cylinder(f, { name = "NestIce", height = 0.2, diameter = ctx.nestRadius * 2 + 30, cf = CFrame.new(nest.X, 0.08, nest.Z), color = ICE, material = Enum.Material.Ice, reflectance = 0.25, collide = false, castShadow = false })

	---------------------------------------------------------------------
	-- drifts banked against the walls and along the trail
	---------------------------------------------------------------------
	for i = 0, 6 do
		for side = -1, 1, 2 do
			local z = z0 + 18 + i * 34 + rng(-4, 4)
			local h = rng(4, 8)
			local depth = rng(10, 16)
			drift(ctx, f, Vector3.new(side * (75 - depth / 2), 0, z), Vector3.new(-side, 0, 0), rng(18, 26), h, depth)
		end
	end
	for i = 0, 4 do
		for side = -1, 1, 2 do
			local z = z0 + 14 + i * 24 + rng(-3, 3)
			drift(ctx, f, Vector3.new(side * (half + 4.5), 0, z), Vector3.new(-side, 0, 0), rng(8, 12), rng(1.2, 2), 5)
		end
	end
	for i = 1, 8 do
		local x = (i % 2 == 0 and 1 or -1) * rng(24, 60)
		local z = rng(z0 + 10, z1 - 30)
		if clear(x, z, 4) then
			Kit.ball(f, { name = "SnowMound", diameter = rng(6, 10), cf = CFrame.new(x, -1.5, z), color = SNOW, material = Enum.Material.Snow })
		end
	end

	---------------------------------------------------------------------
	-- snowy pines: big ones near the walls, small ones closer in
	---------------------------------------------------------------------
	local bigPines = {
		{ -58, z0 + 26 }, { 60, z0 + 44 }, { -62, z0 + 84 }, { 56, z0 + 108 },
		{ -60, z0 + 150 }, { 62, z0 + 178 }, { -64, z0 + 208 }, { 34, z0 + 16 },
	}
	for _, p in ipairs(bigPines) do
		if clear(p[1], p[2], 7) then
			pine(ctx, f, Vector3.new(p[1], 0, p[2]), 1.1 + rng(0, 0.35), 3)
		end
	end
	local smallPines = {
		{ -30, z0 + 40 }, { 28, z0 + 66 }, { -36, z0 + 112 }, { 40, z0 + 132 },
		{ -24, z0 + 20 }, { 46, z0 + 82 }, { -44, z0 + 64 }, { 30, z0 + 100 },
	}
	for _, p in ipairs(smallPines) do
		if clear(p[1], p[2], 4) then
			pine(ctx, f, Vector3.new(p[1], 0, p[2]), 0.6 + rng(0, 0.2), 2)
		end
	end

	---------------------------------------------------------------------
	-- jagged ice crystals, some glowing cold blue
	---------------------------------------------------------------------
	local crystals = {
		{ -22, z0 + 58, 1, true }, { 24, z0 + 30, 0.9, false }, { -48, z0 + 128, 1.3, true },
		{ 50, z0 + 150, 1.4, true }, { 22, z0 + 112, 0.8, false }, { -40, z0 + 10, 1, false },
		{ 66, z0 + 234, 1.3, true },
	}
	for _, c in ipairs(crystals) do
		if clear(c[1], c[2], 4 * c[3]) then
			iceCluster(ctx, f, Vector3.new(c[1], 0, c[2]), 3, c[3], c[4])
		end
	end

	---------------------------------------------------------------------
	-- the frozen pond, ringed with snow, reeds caught in the ice
	---------------------------------------------------------------------
	local pond = Vector3.new(-44, 0, z0 + 92)
	Kit.cylinder(f, { name = "FrozenPond", height = 0.4, diameter = 26, cf = CFrame.new(pond.X, 0, pond.Z), color = { 140, 196, 232 }, material = Enum.Material.Ice, reflectance = 0.35 })
	Kit.cylinder(f, { name = "PondDeep", height = 0.42, diameter = 14, cf = CFrame.new(pond.X + 2, 0.01, pond.Z - 1), color = { 90, 150, 205 }, material = Enum.Material.Ice, reflectance = 0.4, collide = false })
	Kit.cylinder(f, { name = "FishingHole", height = 0.44, diameter = 2.2, cf = CFrame.new(pond.X + 5, 0.02, pond.Z + 3), color = { 30, 50, 80 }, material = Enum.Material.Glass, collide = false })
	for i = 0, 8 do
		local a = i / 9 * math.pi * 2
		local p = pond + Vector3.new(math.cos(a), 0, math.sin(a)) * 13.5
		Kit.ball(f, { name = "PondSnow", diameter = rng(3, 5), cf = CFrame.new(p.X, -0.6, p.Z), color = SNOW, material = Enum.Material.Snow })
	end
	for i = 1, 5 do
		local p = pond + Vector3.new(rng(-11, -6), 0, rng(-6, 6))
		Kit.part(f, { name = "FrozenReed", size = Vector3.new(0.25, rng(2, 3.5), 0.25), cf = CFrame.new(p.X, 1.2, p.Z) * CFrame.Angles(rng(-0.2, 0.2), 0, rng(-0.2, 0.2)), color = { 150, 140, 110 }, material = Enum.Material.Grass, collide = false })
	end

	---------------------------------------------------------------------
	-- frost lanterns and an ice arch with icicles over the route
	---------------------------------------------------------------------
	for _, z in ipairs({ z0 + 36, z0 + 96 }) do
		for side = -1, 1, 2 do
			lantern(ctx, f, Vector3.new(side * 16.5, 0, z))
		end
	end
	local archZ = z0 + 70
	local prev
	for i = 0, 6 do
		local th = math.pi * i / 6
		local p = Vector3.new(math.cos(th) * 20, math.sin(th) * 20, archZ)
		if prev then
			local mid = (prev + p) / 2
			Kit.part(f, { name = "IceArch", size = Vector3.new(4, 3, (p - prev).Magnitude + 1.6), cf = CFrame.lookAt(mid, p), color = Kit.mix(ICE, { 255, 255, 255 }, 0.25), material = Enum.Material.Ice, transparency = 0.15, reflectance = 0.15, collide = false })
		end
		prev = p
	end
	icicles(ctx, f, Vector3.new(-9, 0, archZ), Vector3.new(9, 0, archZ), 17.6, 6, 4)

	---------------------------------------------------------------------
	-- hero: the ice cathedral; aurora ribbons and snowfall above
	---------------------------------------------------------------------
	cathedral(ctx, f, z1 - 16)
	for i = 1, 4 do
		local ribbon = Kit.part(f, {
			name = "Aurora",
			size = Vector3.new(70, 12, 0.4),
			cf = CFrame.new(-48 + i * 22, 96 + i * 4, z1 - 2 - i * 8) * CFrame.Angles(0.2, rng(-0.4, 0.4), rng(-0.15, 0.15)),
			color = AURORA[i],
			material = Enum.Material.Neon,
			transparency = 0.7,
			collide = false,
			castShadow = false,
		})
		ribbon.CanQuery = false
	end
	local sky = Kit.part(f, { name = "Snowfall", size = Vector3.new(150, 2, 250), cf = CFrame.new(0, 60, (z0 + z1) / 2), transparency = 1, collide = false, castShadow = false })
	sky.CanQuery = false
	Kit.particles(sky, { color = { 255, 255, 255 }, size = 0.35, sizeEnd = 0.25, transparency = 0.1, rate = 45, lifetime = 12, speed = 1, spread = 30, emission = 0.3, accel = Vector3.new(1.5, -5, 0) })

	clearPlayArea(ctx)

	return {
		palette = {
			accent = { 150, 226, 255 },
			gate = { 196, 220, 240 },
			gateMaterial = Enum.Material.Glacier,
			nest = { 186, 214, 238 },
			nestMaterial = Enum.Material.Ice,
		},
	}
end
