--[[
	Zone 5 — Magma Basin. "The ground is the disaster."
	A scorched basin of basalt and cracked lava rock: a glowing lava river
	cuts across the route under a dark basalt bridge, lava pools simmer at
	the sides, volcanic spires and black obsidian shards jut from the ground,
	steam vents hiss, ash-covered dead trees smoulder and ash drifts down.
	The hero closes the zone: an erupting volcano with a glowing crater,
	lava streaming down its face and a lava-tube tunnel through its base that
	the route runs through.

	Zone builder contract (see docs/ZONE_CONTRACT.md):
	  build(ctx) -> { palette = { accent, gate, gateMaterial, nest, nestMaterial } }
	  ctx: folder, index, zone, z0, z1, length, width, pathWidth, nest (Vector3),
	       nestRadius, rng(a,b), Kit, tree(parent, pos, scale, leafColor)
]]

local BASALT = { 52, 46, 46 }
local BASALT_DARK = { 34, 30, 32 }
local SCORCH = { 72, 52, 44 }
local PATH = { 84, 78, 78 }
local LAVA = { 255, 112, 28 }
local LAVA_HOT = { 255, 190, 60 }
local EMBER = { 255, 84, 24 }
local OBSIDIAN = { 18, 14, 22 }
local ASH = { 150, 144, 140 }
local CHAR = { 44, 38, 36 }

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

-- two-faced chisel point from wedges; `base` is the CFrame at the bottom centre
local function chisel(Kit, parent, base, w, d, h, o)
	for i = 0, 2, 2 do
		Kit.part(parent, {
			name = o.name or "Tip",
			shape = "Wedge",
			size = Vector3.new(w, h, d / 2),
			cf = base * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, h / 2, -d / 4),
			color = o.color,
			material = o.material,
			reflectance = o.reflectance,
			collide = o.collide,
		})
	end
end

-- flowing lava ribbon between points; banks of dark crust where requested
local function lavaRiver(ctx, parent, pts, width, banks, skip)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "LavaRiver")
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		if not (skip and skip(a, b)) then
			local len = (b - a).Magnitude + width * 0.6
			local cf = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0.06, 0), b + Vector3.new(0, 0.06, 0))
			local lava = Kit.part(m, { name = "Lava", size = Vector3.new(width, 0.2, len), cf = cf, color = (i % 2 == 0) and LAVA or EMBER, material = Enum.Material.Neon, collide = false, castShadow = false })
			Kit.part(m, { name = "LavaCore", size = Vector3.new(width * 0.4, 0.24, len * 0.9), cf = cf * CFrame.new(0, 0.02, 0), color = LAVA_HOT, material = Enum.Material.Neon, collide = false, castShadow = false })
			Kit.light(lava, LAVA, width * 2.6, 1.4)
			if banks then
				for side = -1, 1, 2 do
					Kit.part(m, { name = "Crust", size = Vector3.new(1.8, 0.6, len), cf = cf * CFrame.new(side * (width / 2 + 0.7), 0.24, 0), color = BASALT_DARK, material = Enum.Material.Basalt })
				end
			end
		end
	end
	return m
end

local function lavaPool(ctx, parent, pos, d)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "LavaPool")
	local lava = Kit.cylinder(m, { name = "Lava", height = 0.2, diameter = d, cf = CFrame.new(pos + Vector3.new(0, 0.07, 0)), color = LAVA, material = Enum.Material.Neon, collide = false, castShadow = false })
	Kit.cylinder(m, { name = "LavaCore", height = 0.24, diameter = d * 0.5, cf = CFrame.new(pos + Vector3.new(rng(-1, 1), 0.09, rng(-1, 1))), color = LAVA_HOT, material = Enum.Material.Neon, collide = false, castShadow = false })
	Kit.light(lava, LAVA, d * 1.6, 1.6)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2 + rng(-0.3, 0.3)
		local p = pos + Vector3.new(math.cos(a), 0, math.sin(a)) * (d / 2 + 0.6)
		Kit.part(m, { name = "RimRock", size = Vector3.new(rng(3, 5), rng(1, 2.2), rng(2, 3.5)), cf = CFrame.lookAt(Vector3.new(p.X, 0.3, p.Z), Vector3.new(pos.X, 0.3, pos.Z)) * CFrame.Angles(rng(-0.2, 0.2), 0, rng(-0.2, 0.2)), color = BASALT_DARK, material = Enum.Material.Basalt })
	end
	return m
end

local function spire(ctx, parent, pos, h, seam)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "RockSpire")
	local n = 4
	local y = 0
	local w = h * 0.32
	local yaw = rng(0, 1.5)
	for i = 1, n do
		local sh = h / n * 1.15
		local k = 1 - (i - 1) / n * 0.8
		Kit.part(m, { name = "Spire", size = Vector3.new(w * k, sh, w * k * 0.85), cf = CFrame.new(pos + Vector3.new(rng(-0.4, 0.4) * i, y + sh / 2, rng(-0.4, 0.4) * i)) * CFrame.Angles(rng(-0.06, 0.06), yaw + i * 0.4, rng(-0.06, 0.06)), color = (i % 2 == 0) and BASALT or BASALT_DARK, material = Enum.Material.Basalt })
		y = y + sh * 0.85
	end
	if seam then
		local glow = Kit.part(m, { name = "MagmaSeam", size = Vector3.new(0.4, h * 0.55, 0.4), cf = CFrame.new(pos + Vector3.new(0, h * 0.3, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.new(w * 0.5, 0, 0) * CFrame.Angles(0, 0, 0.12), color = EMBER, material = Enum.Material.Neon, collide = false })
		Kit.light(glow, EMBER, 12, 0.9)
	end
	return m
end

local function steamVent(ctx, parent, pos, hot)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "SteamVent")
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		local p = pos + Vector3.new(math.cos(a) * 2.2, 0, math.sin(a) * 2.2)
		Kit.part(m, { name = "VentRock", size = Vector3.new(2.2, rng(1.2, 2.4), 1.6), cf = CFrame.lookAt(Vector3.new(p.X, 0.5, p.Z), Vector3.new(pos.X, 0.5, pos.Z)) * CFrame.Angles(-0.35, 0, 0), color = BASALT, material = Enum.Material.Basalt })
	end
	local mouth = Kit.cylinder(m, { name = "VentMouth", height = 0.3, diameter = 2.6, cf = CFrame.new(pos + Vector3.new(0, 0.2, 0)), color = hot and LAVA or { 30, 26, 26 }, material = hot and Enum.Material.Neon or Enum.Material.Basalt, collide = false })
	Kit.particles(mouth, { color = { 220, 214, 210 }, color2 = { 120, 116, 116 }, size = 2, sizeEnd = 7, transparency = 0.45, rate = 9, lifetime = 3, speed = 9, spread = 12, emission = 0, accel = Vector3.new(0.8, 2, 0), drag = 0.6, texture = "rbxasset://textures/particles/smoke_main.dds" })
	if hot then
		Kit.light(mouth, LAVA, 12, 1.2)
	end
	return m
end

local function obsidian(ctx, parent, pos, scale)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "Obsidian")
	for i = 1, 3 do
		local w = rng(1.4, 2.6) * scale
		local d = w * 0.7
		local h = rng(3.5, 8) * scale * ((i == 1) and 1.3 or 1)
		local off = (i == 1) and Vector3.new(0, 0, 0) or Vector3.new(rng(-2.2, 2.2) * scale, 0, rng(-2.2, 2.2) * scale)
		local base = CFrame.new(pos + off + Vector3.new(0, -0.4, 0)) * CFrame.Angles(rng(-0.4, 0.4), rng(0, 3.14), rng(-0.4, 0.4))
		Kit.part(m, { name = "Shard", size = Vector3.new(w, h, d), cf = base * CFrame.new(0, h / 2, 0), color = OBSIDIAN, material = Enum.Material.Glass, reflectance = 0.35 })
		chisel(Kit, m, base * CFrame.new(0, h, 0), w, d, w * 1.2, { name = "ShardTip", color = OBSIDIAN, material = Enum.Material.Glass, reflectance = 0.35 })
	end
	return m
end

-- a cluster of hexagonal-ish basalt columns, tallest in the middle
local function basaltColumns(ctx, parent, pos, n, tall)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "BasaltColumns")
	for i = 1, n do
		local a = i / n * math.pi * 2
		local r = (i == 1) and 0 or rng(2, 4.5)
		local h = tall * ((i == 1) and 1 or rng(0.35, 0.85))
		local p = pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		Kit.cylinder(m, { name = "Column", height = h, diameter = rng(2.6, 3.4), cf = CFrame.new(p + Vector3.new(0, h / 2, 0)), color = Kit.shade(BASALT, rng(0.75, 1.1)), material = Enum.Material.Basalt })
		if i % 3 == 0 then
			Kit.cylinder(m, { name = "AshCap", height = 0.3, diameter = 2.4, cf = CFrame.new(p + Vector3.new(0, h + 0.1, 0)), color = ASH, material = Enum.Material.Slate, collide = false })
		end
	end
	return m
end

local function ashTree(ctx, parent, pos, h)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "AshTree")
	local top = pos + Vector3.new(rng(-1.2, 1.2), h, rng(-1.2, 1.2))
	rod(Kit, m, pos + Vector3.new(0, -0.5, 0), top, 1.4, { name = "CharredTrunk", color = CHAR, material = Enum.Material.Wood })
	Kit.cylinder(m, { name = "AshDrift", height = 1, diameter = 4, cf = CFrame.new(pos + Vector3.new(0, 0.3, 0)), color = ASH, material = Enum.Material.Slate })
	for i = 1, 3 do
		local from = pos:Lerp(top, 0.45 + i * 0.15)
		local a = rng(0, 6.28)
		local len = h * rng(0.28, 0.42)
		local to = from + Vector3.new(math.cos(a) * len, len * rng(0.3, 0.8), math.sin(a) * len)
		rod(Kit, m, from, to, 0.55, { name = "Branch", color = (i == 2) and Kit.mix(CHAR, ASH, 0.5) or CHAR, material = Enum.Material.Wood, collide = false })
		if i == 1 then
			local ember = Kit.ball(m, { name = "Ember", diameter = 0.6, cf = CFrame.new(to), color = EMBER, material = Enum.Material.Neon, collide = false })
			Kit.light(ember, EMBER, 6, 0.8)
		end
	end
	return m
end

-- hero: a truncated volcano cone facing the gate, lava tube through its base
local function volcano(ctx, parent, zc)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "Volcano")
	local depth = 30
	local front = zc - depth / 2
	local tube = 14 -- half-width of the lava tube (the route runs through it)
	local tubeH = 16
	local k = 70 / 75 -- flank slope
	local rimY = k * (75 - tube)
	-- flanks: wedges rising from the side walls to the crater rim
	for side = -1, 1, 2 do
		local c = Vector3.new(side * (75 + tube) / 2, rimY / 2, zc)
		Kit.part(m, { name = "Flank", shape = "Wedge", size = Vector3.new(depth, rimY, 75 - tube), cf = CFrame.lookAt(c, c + Vector3.new(side, 0, 0)), color = (side < 0) and BASALT or Kit.shade(BASALT, 0.9), material = Enum.Material.Basalt })
		-- tube walls: dark basalt frame at the tunnel mouth
		Kit.part(m, { name = "TubeFrame", size = Vector3.new(3, tubeH + 1, 3), cf = CFrame.new(side * (tube + 2.5), (tubeH + 1) / 2, front - 0.5), color = BASALT_DARK, material = Enum.Material.Basalt })
		local glow = Kit.part(m, { name = "TubeGlow", size = Vector3.new(0.4, 1.2, 18), cf = CFrame.new(side * (tube + 0.3), 9, zc), color = LAVA, material = Enum.Material.Neon, collide = false })
		Kit.light(glow, LAVA, 22, 1.5)
		-- lava streaming down the face into a pool at the foot
		local pts = {
			Vector3.new(side * 9, rimY, front - 0.6),
			Vector3.new(side * 16, rimY - 14, front - 0.8),
			Vector3.new(side * 22, rimY - 28, front - 0.8),
			Vector3.new(side * 30, rimY - 42, front - 0.8),
			Vector3.new(side * 36, 0.4, front - 1.6),
		}
		for i = 1, 4 do
			rod(Kit, m, pts[i], pts[i + 1], 2.2 - i * 0.2, { name = "LavaFlow", color = (i % 2 == 0) and LAVA or LAVA_HOT, material = Enum.Material.Neon, collide = false, castShadow = false })
		end
		-- craggy boulders on the lower slopes
		for i = 1, 3 do
			local x = side * (24 + i * 12)
			local y = k * (75 - math.abs(x)) * rng(0.2, 0.5)
			Kit.part(m, { name = "Crag", size = Vector3.new(rng(6, 9), rng(5, 8), rng(4, 6)), cf = CFrame.new(x, y, front + 1) * CFrame.Angles(rng(-0.3, 0.3), rng(-0.5, 0.5), rng(-0.4, 0.4)), color = BASALT_DARK, material = Enum.Material.Basalt })
		end
		-- crater rim
		Kit.part(m, { name = "Rim", size = Vector3.new(6, 4, depth - 2), cf = CFrame.new(side * (tube - 1), rimY + 1.2, zc) * CFrame.Angles(0, 0, side * 0.25), color = BASALT_DARK, material = Enum.Material.Basalt })
	end
	-- mass above the tube, crater lip front/back
	Kit.part(m, { name = "Crown", size = Vector3.new(tube * 2, rimY - tubeH, depth), cf = CFrame.new(0, tubeH + (rimY - tubeH) / 2, zc), color = SCORCH, material = Enum.Material.CrackedLava })
	Kit.part(m, { name = "TubeLintel", size = Vector3.new(tube * 2 + 8, 3, 3), cf = CFrame.new(0, tubeH + 0.5, front + 0.5), color = BASALT_DARK, material = Enum.Material.Basalt })
	for side = -1, 1, 2 do
		Kit.part(m, { name = "Lip", size = Vector3.new(tube * 2 - 2, 2.4, 3), cf = CFrame.new(0, rimY + 0.8, zc + side * (depth / 2 - 2)) * CFrame.Angles(side * 0.2, 0, 0), color = BASALT_DARK, material = Enum.Material.Basalt })
	end
	-- the glowing crater: magma lake, fountain blobs, smoke and embers
	local crater = Kit.part(m, { name = "Crater", size = Vector3.new(tube * 2 - 4, 0.6, depth - 6), cf = CFrame.new(0, rimY + 0.2, zc), color = LAVA, material = Enum.Material.Neon, collide = false })
	Kit.light(crater, LAVA, 60, 3)
	Kit.part(m, { name = "CraterCore", size = Vector3.new(tube, 0.7, depth * 0.45), cf = CFrame.new(0, rimY + 0.3, zc), color = LAVA_HOT, material = Enum.Material.Neon, collide = false })
	for i = 1, 5 do
		Kit.ball(m, { name = "LavaBlob", diameter = rng(1.5, 3), cf = CFrame.new(rng(-6, 6), rimY + 3 + i * 2.2, zc + rng(-5, 5)), color = (i % 2 == 0) and LAVA_HOT or LAVA, material = Enum.Material.Neon, collide = false, castShadow = false })
	end
	local plume = Kit.part(m, { name = "Plume", size = Vector3.new(16, 2, 16), cf = CFrame.new(0, rimY + 3, zc), transparency = 1, collide = false, castShadow = false })
	plume.CanQuery = false
	Kit.particles(plume, { color = { 70, 62, 60 }, color2 = { 30, 28, 30 }, size = 8, sizeEnd = 22, transparency = 0.3, rate = 10, lifetime = 7, speed = 14, spread = 14, emission = 0, accel = Vector3.new(2, 1.5, 0), drag = 0.3, texture = "rbxasset://textures/particles/smoke_main.dds" })
	Kit.particles(plume, { color = LAVA_HOT, color2 = EMBER, size = 0.6, sizeEnd = 0.1, transparency = 0, rate = 30, lifetime = 2.5, speed = 26, spread = 25, emission = 1, accel = Vector3.new(0, -18, 0) })
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
	-- ground: basalt and cracked lava rock, a paved basalt causeway
	---------------------------------------------------------------------
	local cols = { { -75, -45 }, { -45, -13 }, { -13, 13 }, { 13, 45 }, { 45, 75 } }
	local rows = 7
	local rowLen = ctx.length / rows
	for r = 0, rows - 1 do
		for c, span in ipairs(cols) do
			local lavaRock = (c ~= 3) and ((r + c) % 3 == 0)
			Kit.part(f, {
				name = "Ground",
				size = Vector3.new(span[2] - span[1], 4, rowLen),
				cf = CFrame.new((span[1] + span[2]) / 2, -2, z0 + (r + 0.5) * rowLen),
				color = lavaRock and SCORCH or Kit.shade(((r + c) % 2 == 0) and BASALT or BASALT_DARK, rng(0.95, 1.08)),
				material = lavaRock and Enum.Material.CrackedLava or Enum.Material.Basalt,
			})
		end
	end
	local pathEnd = nest.Z - nestGuard + 8
	Kit.part(f, { name = "Causeway", size = Vector3.new(ctx.pathWidth - 4, 0.24, pathEnd - z0), cf = CFrame.new(0, 0.07, (z0 + pathEnd) / 2), color = PATH, material = Enum.Material.Slate, collide = false })
	for side = -1, 1, 2 do
		Kit.part(f, { name = "CausewayEdge", size = Vector3.new(1, 0.5, pathEnd - z0 - 4), cf = CFrame.new(side * (half - 1.5), 0.2, (z0 + pathEnd) / 2), color = BASALT_DARK, material = Enum.Material.Basalt, collide = false })
	end
	-- glowing fault lines scattered over the basin and ringing the nest
	for i = 1, 14 do
		local p = Vector3.new(rng(-70, 70), 0, rng(z0 + 8, z1 - 40))
		local a = rng(0, 6.28)
		for s = 1, 3 do
			a = a + rng(-0.6, 0.6)
			local len = rng(4, 7)
			local q = p + Vector3.new(math.cos(a) * len, 0, math.sin(a) * len)
			q = Vector3.new(math.clamp(q.X, -73, 73), 0, math.clamp(q.Z, z0 + 2, z1 - 2))
			local mid = (p + q) / 2
			if (q - p).Magnitude > 0.5 then
				Kit.part(f, { name = "FaultGlow", size = Vector3.new(0.35, 0.12, (q - p).Magnitude + 0.3), cf = CFrame.lookAt(Vector3.new(mid.X, 0.04, mid.Z), Vector3.new(q.X, 0.04, q.Z)), color = (s == 2) and LAVA_HOT or EMBER, material = Enum.Material.Neon, collide = false, castShadow = false })
			end
			p = q
		end
	end
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2 + rng(-0.15, 0.15)
		local p = nest + Vector3.new(math.cos(a), 0, math.sin(a)) * (ctx.nestRadius + 9)
		local q = nest + Vector3.new(math.cos(a + 0.12), 0, math.sin(a + 0.12)) * (ctx.nestRadius + 17)
		local mid = (p + q) / 2
		Kit.part(f, { name = "NestFault", size = Vector3.new(0.5, 0.12, (q - p).Magnitude), cf = CFrame.lookAt(Vector3.new(mid.X, 0.04, mid.Z), Vector3.new(q.X, 0.04, q.Z)), color = EMBER, material = Enum.Material.Neon, collide = false, castShadow = false })
	end

	---------------------------------------------------------------------
	-- the lava river across the route, spanned by a basalt bridge
	---------------------------------------------------------------------
	local riverZ = z0 + 62
	local bridgeHalf = half + 2
	lavaRiver(ctx, f, {
		Vector3.new(-80, 0, riverZ + 14), Vector3.new(-50, 0, riverZ + 8), Vector3.new(-bridgeHalf - 2, 0, riverZ),
		Vector3.new(bridgeHalf + 2, 0, riverZ), Vector3.new(46, 0, riverZ - 6), Vector3.new(80, 0, riverZ - 12),
	}, 9, true, function(a, b)
		return math.abs(a.X) < bridgeHalf + 3 and math.abs(b.X) < bridgeHalf + 3
	end)
	local bridge = Kit.model(f, "BasaltBridge")
	Kit.part(bridge, { name = "Deck", size = Vector3.new(bridgeHalf * 2 + 6, 1, 15), cf = CFrame.new(0, 0.1, riverZ), color = BASALT_DARK, material = Enum.Material.Basalt })
	for side = -1, 1, 2 do
		for i = -1, 1 do
			Kit.part(bridge, { name = "Post", size = Vector3.new(1.4, 3.4, 1.4), cf = CFrame.new(side * (half + 1.6), 2.2, riverZ + i * 6.4), color = BASALT, material = Enum.Material.Basalt })
		end
		Kit.part(bridge, { name = "Rail", size = Vector3.new(1, 0.8, 14.2), cf = CFrame.new(side * (half + 1.6), 3.6, riverZ), color = BASALT_DARK, material = Enum.Material.Basalt })
		local brazier = Kit.part(bridge, { name = "Brazier", size = Vector3.new(1, 0.8, 1), cf = CFrame.new(side * (half + 1.6), 4.4, riverZ - 6.4), color = LAVA_HOT, material = Enum.Material.Neon, collide = false })
		Kit.light(brazier, LAVA, 16, 1.2)
	end

	---------------------------------------------------------------------
	-- lava pools at the sides and a lava creek along the left wall
	---------------------------------------------------------------------
	for _, p in ipairs({ { -46, z0 + 22, 14 }, { 52, z0 + 112, 18 }, { -56, z0 + 128, 12 }, { 58, z0 + 204, 14 }, { 38, z0 + 28, 10 } }) do
		lavaPool(ctx, f, Vector3.new(p[1], 0, p[2]), p[3])
	end
	lavaRiver(ctx, f, {
		Vector3.new(-36, 0, z1 - 30), Vector3.new(-56, 0, z1 - 52), Vector3.new(-66, 0, z1 - 86),
		Vector3.new(-64, 0, z1 - 112), Vector3.new(-58, 0, z1 - 130),
	}, 6, false)

	---------------------------------------------------------------------
	-- volcanic spires, obsidian, steam vents, ash trees
	---------------------------------------------------------------------
	local spires = {
		{ -30, z0 + 40, 22, true }, { 32, z0 + 84, 26, false }, { -64, z0 + 70, 34, true }, { 66, z0 + 40, 30, false },
		{ 66, z0 + 150, 38, true }, { -68, z0 + 190, 32, false }, { 28, z0 + 16, 16, false }, { -36, z0 + 104, 18, true },
		{ 68, z0 + 236, 28, true }, { 62, z0 + 82, 20, false },
	}
	for _, s in ipairs(spires) do
		if clear(s[1], s[2], s[3] * 0.2) then
			spire(ctx, f, Vector3.new(s[1], 0, s[2]), s[3], s[4])
		end
	end
	local shards = { { 22, z0 + 50, 1 }, { -22, z0 + 78, 1.2 }, { 44, z0 + 64, 1.4 }, { -44, z0 + 60, 1 }, { 58, z0 + 172, 1.5 }, { -24, z0 + 124, 0.9 }, { 22, z0 + 112, 0.9 } }
	for _, s in ipairs(shards) do
		if clear(s[1], s[2], 3 * s[3]) then
			obsidian(ctx, f, Vector3.new(s[1], 0, s[2]), s[3])
		end
	end
	for i, v in ipairs({ { -20, z0 + 30 }, { 21, z0 + 96 }, { -52, z0 + 92 }, { 46, z0 + 140 }, { -62, z0 + 228 }, { 22, z0 + 70 } }) do
		if clear(v[1], v[2], 3) then
			steamVent(ctx, f, Vector3.new(v[1], 0, v[2]), i % 2 == 1)
		end
	end
	for _, c in ipairs({ { -60, z0 + 12, 14 }, { 60, z0 + 126, 18 }, { -66, z0 + 112, 12 }, { 66, z0 + 96, 16 }, { -66, z0 + 156, 20 }, { 64, z0 + 214, 14 }, { 30, z0 + 128, 8 } }) do
		if clear(c[1], c[2], 6) then
			basaltColumns(ctx, f, Vector3.new(c[1], 0, c[2]), 7, c[3])
		end
	end
	for _, t in ipairs({ { 40, z0 + 14, 11 }, { -54, z0 + 46, 13 }, { 48, z0 + 92, 10 }, { -48, z0 + 152, 12 }, { 54, z0 + 186, 11 }, { -30, z0 + 16, 9 } }) do
		if clear(t[1], t[2], 3) then
			ashTree(ctx, f, Vector3.new(t[1], 0, t[2]), t[3])
		end
	end

	---------------------------------------------------------------------
	-- hero: the erupting volcano; ash falling over the whole basin
	---------------------------------------------------------------------
	volcano(ctx, f, z1 - 18)
	local sky = Kit.part(f, { name = "Ashfall", size = Vector3.new(150, 2, 250), cf = CFrame.new(0, 55, (z0 + z1) / 2), transparency = 1, collide = false, castShadow = false })
	sky.CanQuery = false
	Kit.particles(sky, { color = { 120, 114, 112 }, color2 = { 80, 76, 76 }, size = 0.3, sizeEnd = 0.2, transparency = 0.2, rate = 30, lifetime = 12, speed = 1, spread = 30, emission = 0, accel = Vector3.new(1, -4, 0) })
	Kit.particles(sky, { color = LAVA_HOT, color2 = EMBER, size = 0.2, sizeEnd = 0, transparency = 0, rate = 8, lifetime = 10, speed = 1, spread = 40, emission = 1, accel = Vector3.new(0.5, -3, 0) })

	clearPlayArea(ctx)

	return {
		palette = {
			accent = { 255, 128, 44 },
			gate = { 52, 44, 44 },
			gateMaterial = Enum.Material.Basalt,
			nest = { 72, 50, 42 },
			nestMaterial = Enum.Material.CrackedLava,
		},
	}
end
