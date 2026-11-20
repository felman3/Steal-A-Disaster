--[[
	Zone 9 — Void Realm. The end of the route, where disasters go to die: a
	black obsidian plain split by glowing purple fissures, monoliths humming
	with light, vertical rifts torn in the air, and shattered fragments of
	every earlier zone (a house roof, a frozen spire, a coral, a lava chunk,
	an uprooted tree) drifting overhead. Behind the nest stands a colossal
	cracked portal ring, still swirling.

	Zone builder contract (see docs/ZONE_CONTRACT.md):
	  build(ctx) -> { palette = { accent, gate, gateMaterial, nest, nestMaterial } }
	  ctx: folder, index, zone, z0, z1, length, width, pathWidth, nest (Vector3),
	       nestRadius, rng(a,b), Kit, tree(parent, pos, scale, leafColor)
]]

local VOID_GROUND = { 16, 12, 24 }
local OBSIDIAN = { 30, 22, 46 }
local OBSIDIAN_DARK = { 20, 15, 32 }
local MONOLITH = { 22, 18, 34 }
local PURPLE = { 190, 90, 255 }
local PURPLE_HOT = { 230, 160, 255 }
local MAGENTA = { 255, 90, 220 }

-- Fragment of an earlier zone: a chunk of its ground with a bit of rock under it.
local function chunk(ctx, parent, pos, size, topColor, topMat, tilt)
	local Kit = ctx.Kit
	local cf = CFrame.new(pos) * CFrame.Angles(tilt.X, tilt.Y, tilt.Z)
	Kit.part(parent, { name = "FragmentGround", size = Vector3.new(size.X, 1.2, size.Z), cf = cf, color = topColor, material = topMat, collide = false })
	Kit.part(parent, { name = "FragmentRock", shape = "Wedge", size = Vector3.new(size.X * 0.9, size.Y, size.Z * 0.8), cf = cf * CFrame.new(0, -0.6 - size.Y / 2, 0) * CFrame.Angles(math.pi, 0, 0), color = { 60, 50, 70 }, material = Enum.Material.Slate, collide = false })
	return cf
end

local function brokenRoof(ctx, parent, pos)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "FragmentHouse")
	local cf = chunk(ctx, m, pos, Vector3.new(16, 6, 12), { 108, 178, 78 }, Enum.Material.Grass, Vector3.new(0.25, 0.5, -0.2))
	local wallCf = cf * CFrame.new(-1, 3.4, 0)
	Kit.part(m, { name = "Wall", size = Vector3.new(12, 5.6, 8), cf = wallCf, color = { 240, 180, 180 }, material = Enum.Material.WoodPlanks, collide = false })
	Kit.part(m, { name = "Window", size = Vector3.new(2.6, 2.6, 0.3), cf = wallCf * CFrame.new(2.5, 0.6, -4.05), color = { 170, 220, 255 }, material = Enum.Material.Glass, collide = false })
	Kit.part(m, { name = "Roof", shape = "Wedge", size = Vector3.new(13, 4, 5), cf = wallCf * CFrame.new(0, 4.8, -2.3) * CFrame.Angles(0, math.pi, 0), color = { 150, 70, 60 }, material = Enum.Material.Slate, collide = false })
	Kit.part(m, { name = "Roof", shape = "Wedge", size = Vector3.new(9, 4, 5), cf = wallCf * CFrame.new(-2, 4.8, 2.3) * CFrame.Angles(0, 0, 0.15), color = { 150, 70, 60 }, material = Enum.Material.Slate, collide = false })
	Kit.part(m, { name = "Chimney", size = Vector3.new(1.6, 4, 1.6), cf = wallCf * CFrame.new(4, 6, 1), color = { 160, 80, 60 }, material = Enum.Material.Brick, collide = false })
	-- a loose shingle peeling away
	Kit.part(m, { name = "Shingle", size = Vector3.new(3, 0.3, 2), cf = wallCf * CFrame.new(9, 9, -2) * CFrame.Angles(0.6, 0.4, 0.9), color = { 150, 70, 60 }, material = Enum.Material.Slate, collide = false })
end

local function frozenSpire(ctx, parent, pos)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "FragmentFrost")
	local cf = chunk(ctx, m, pos, Vector3.new(11, 5, 11), { 235, 242, 255 }, Enum.Material.Snow, Vector3.new(-0.2, 0, 0.3))
	local y = 0.6
	for i = 0, 4 do
		local h = 4
		Kit.cylinder(m, { name = "IceSpire", height = h, diameter = 5 - i * 0.9, cf = cf * CFrame.new(0, y + h / 2, 0), color = Kit.mix({ 170, 225, 255 }, { 225, 245, 255 }, i / 4), material = Enum.Material.Ice, transparency = 0.15, collide = false })
		y = y + h
	end
	Kit.part(m, { name = "IceShard", size = Vector3.new(1.4, 7, 1.4), cf = cf * CFrame.new(3, 3.6, 1) * CFrame.Angles(0.2, 0, -0.45), color = { 190, 235, 255 }, material = Enum.Material.Glacier, collide = false })
	Kit.part(m, { name = "IceShard", size = Vector3.new(1.1, 5, 1.1), cf = cf * CFrame.new(-2.6, 3, -2) * CFrame.Angles(-0.3, 0, 0.4), color = { 190, 235, 255 }, material = Enum.Material.Glacier, collide = false })
end

local function coralFragment(ctx, parent, pos)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "FragmentCoral")
	local cf = chunk(ctx, m, pos, Vector3.new(10, 4, 9), { 46, 56, 74 }, Enum.Material.Sand, Vector3.new(0.3, 1.2, 0.15))
	local pink = { 255, 110, 150 }
	Kit.cylinder(m, { name = "Coral", height = 5, diameter = 1.4, cf = cf * CFrame.new(0, 3, 0), color = pink, material = Enum.Material.Pebble, collide = false })
	for k, a in ipairs({ 0.4, 2.4, 4.3 }) do
		local arm = cf * CFrame.new(0, 5, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, 0.6) * CFrame.new(0, 2.4, 0)
		Kit.cylinder(m, { name = "Coral", height = 4.6, diameter = 1, cf = arm, color = pink, material = Enum.Material.Pebble, collide = false })
		Kit.ball(m, { name = "CoralTip", diameter = 1.3, cf = arm * CFrame.new(0, 2.4, 0), color = (k == 2) and { 120, 255, 230 } or { 255, 160, 190 }, material = (k == 2) and Enum.Material.Neon or Enum.Material.Pebble, collide = false })
	end
end

local function lavaChunk(ctx, parent, pos)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "FragmentMagma")
	local cf = chunk(ctx, m, pos, Vector3.new(10, 6, 8), { 50, 40, 40 }, Enum.Material.Basalt, Vector3.new(-0.35, 0.8, -0.25))
	Kit.part(m, { name = "LavaCrack", size = Vector3.new(7, 0.2, 0.7), cf = cf * CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0.5, 0), color = { 255, 120, 40 }, material = Enum.Material.Neon, collide = false })
	Kit.part(m, { name = "LavaCrack", size = Vector3.new(4, 0.2, 0.5), cf = cf * CFrame.new(-1.5, 0.62, 1.4) * CFrame.Angles(0, -0.6, 0), color = { 255, 120, 40 }, material = Enum.Material.Neon, collide = false })
	Kit.part(m, { name = "MagmaRock", size = Vector3.new(3.4, 3, 3), cf = cf * CFrame.new(2.4, 2, -1.4) * CFrame.Angles(0.3, 0.7, 0.2), color = { 40, 32, 32 }, material = Enum.Material.CrackedLava, collide = false })
end

local function uprootedTree(ctx, parent, pos)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "FragmentTree")
	local cf = CFrame.new(pos) * CFrame.Angles(0.4, 0.3, 2.3)
	Kit.cylinder(m, { name = "Trunk", height = 9, diameter = 1.4, cf = cf, color = { 110, 75, 50 }, material = Enum.Material.Wood, collide = false })
	Kit.ball(m, { name = "RootBall", diameter = 4.4, cf = cf * CFrame.new(0, -5, 0), color = { 90, 70, 50 }, material = Enum.Material.Ground, collide = false })
	Kit.ball(m, { name = "Leaves", diameter = 7, cf = cf * CFrame.new(0, 6, 0), color = { 80, 170, 70 }, material = Enum.Material.Grass, collide = false })
	Kit.ball(m, { name = "Leaves", diameter = 4.6, cf = cf * CFrame.new(1.8, 4.4, 1), color = { 70, 150, 60 }, material = Enum.Material.Grass, collide = false })
end

-- Monolith: a tall obsidian slab with glowing inlays and a hovering capstone.
local function monolith(ctx, parent, pos, h, yaw)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "Monolith")
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	Kit.part(m, { name = "MonolithBase", size = Vector3.new(8, 1.2, 5), cf = base * CFrame.new(0, 0.6, 0), color = OBSIDIAN_DARK, material = Enum.Material.Slate })
	Kit.part(m, { name = "Monolith", size = Vector3.new(5, h, 2.6), cf = base * CFrame.new(0, 1.2 + h / 2, 0), color = MONOLITH, material = Enum.Material.Glass, reflectance = 0.15 })
	Kit.part(m, { name = "Inlay", size = Vector3.new(0.35, h * 0.7, 0.2), cf = base * CFrame.new(-0.9, 1.2 + h * 0.45, -1.35), color = PURPLE, material = Enum.Material.Neon, collide = false })
	Kit.part(m, { name = "Inlay", size = Vector3.new(0.35, h * 0.45, 0.2), cf = base * CFrame.new(1.0, 1.2 + h * 0.6, -1.35), color = PURPLE, material = Enum.Material.Neon, collide = false })
	Kit.part(m, { name = "Capstone", size = Vector3.new(4, 2.4, 2.2), cf = base * CFrame.new(0, 1.2 + h + 3.4, 0) * CFrame.Angles(0, 0.4, 0.2), color = OBSIDIAN, material = Enum.Material.Glass, collide = false })
	return m
end

-- Rift: a vertical tear in the air, glowing from inside.
local function rift(ctx, parent, pos, h, yaw)
	local Kit = ctx.Kit
	local base = CFrame.new(pos + Vector3.new(0, h / 2 + 2, 0)) * CFrame.Angles(0, yaw, 0)
	Kit.part(parent, { name = "RiftEdge", size = Vector3.new(3.2, h, 0.4), cf = base * CFrame.Angles(0, 0, 0.06), color = { 10, 5, 18 }, material = Enum.Material.Glass, collide = false })
	Kit.part(parent, { name = "RiftEdge", size = Vector3.new(2.4, h * 0.7, 0.45), cf = base * CFrame.new(0.4, -h * 0.1, 0) * CFrame.Angles(0, 0, -0.09), color = { 40, 10, 60 }, material = Enum.Material.Glass, collide = false })
	local core = Kit.part(parent, { name = "RiftCore", size = Vector3.new(0.7, h * 0.9, 0.5), cf = base * CFrame.Angles(0, 0, 0.03), color = PURPLE_HOT, material = Enum.Material.Neon, collide = false })
	Kit.part(parent, { name = "RiftCore", size = Vector3.new(0.4, h * 0.5, 0.55), cf = base * CFrame.new(0.3, h * 0.15, 0) * CFrame.Angles(0, 0, -0.05), color = MAGENTA, material = Enum.Material.Neon, collide = false })
	Kit.light(core, PURPLE, 20, 1.4)
	Kit.particles(core, { color = PURPLE_HOT, color2 = { 80, 30, 160 }, size = 0.4, sizeEnd = 0, rate = 6, lifetime = 2, speed = 1.5, emission = 1, accel = Vector3.new(0, -0.5, 0) })
end

-- Obsidian shard drifting in the air.
local function shard(ctx, parent, pos, s)
	local Kit, rng = ctx.Kit, ctx.rng
	local p = Kit.part(parent, {
		name = "VoidShard",
		shape = (rng() < 0.5) and "Wedge" or "Block",
		size = Vector3.new(1.4 * s, 4 * s, 2 * s),
		cf = CFrame.new(pos) * CFrame.Angles(rng(0, 3), rng(0, 3), rng(0, 3)),
		color = OBSIDIAN,
		material = Enum.Material.Glass,
		reflectance = 0.2,
		collide = false,
	})
	if s > 1.4 then
		Kit.part(parent, { name = "ShardEdge", size = Vector3.new(0.2, 4 * s, 0.2), cf = p.CFrame * CFrame.new(0.7 * s, 0, -1 * s), color = PURPLE, material = Enum.Material.Neon, collide = false })
	end
end

-- The hero: a colossal cracked portal ring on a stepped dais.
local function portal(ctx, parent, center)
	local Kit, rng = ctx.Kit, ctx.rng
	local m = Kit.model(parent, "RiftPortal")
	local R = 30
	local segs = 28
	local missing = { [4] = true, [5] = true }
	for i = 0, segs - 1 do
		local a = i / segs * math.pi * 2
		local radial = Vector3.new(math.cos(a), math.sin(a), 0)
		if missing[i] then
			-- the broken section, its pieces flung outward
			local p = center + radial * (R + 9 + i * 2)
			Kit.part(m, { name = "RingShard", size = Vector3.new(5, 7, 6), cf = CFrame.new(p) * CFrame.Angles(rng(-0.6, 0.6), rng(-0.6, 0.6), a + rng(-0.8, 0.8)), color = OBSIDIAN, material = Enum.Material.Slate, collide = false })
		else
			local wobble = (i % 5 == 2) and 0.12 or 0
			Kit.part(m, {
				name = "RingStone",
				size = Vector3.new(5.5, 7.4, 6),
				cf = CFrame.new(center + radial * (R + 2.75)) * CFrame.Angles(0, 0, a) * CFrame.Angles(wobble, 0, 0),
				color = (i % 2 == 0) and OBSIDIAN or OBSIDIAN_DARK,
				material = Enum.Material.Slate,
			})
			Kit.part(m, {
				name = "RingGlow",
				size = Vector3.new(0.8, 7.0, 6.4),
				cf = CFrame.new(center + radial * (R - 0.2)) * CFrame.Angles(0, 0, a),
				color = (i % 3 == 0) and MAGENTA or PURPLE,
				material = Enum.Material.Neon,
				collide = false,
			})
		end
	end
	-- the swirling surface: layered discs facing the route
	local face = CFrame.new(center) * CFrame.Angles(0, math.pi / 2, 0)
	Kit.part(m, { name = "PortalVeil", shape = "Cylinder", size = Vector3.new(0.4, R * 2, R * 2), cf = face, color = { 120, 40, 200 }, material = Enum.Material.ForceField, transparency = 0.15, collide = false, castShadow = false })
	Kit.part(m, { name = "PortalSwirl", shape = "Cylinder", size = Vector3.new(0.6, R * 1.4, R * 1.4), cf = face * CFrame.new(0.4, 0, 0), color = { 90, 20, 160 }, material = Enum.Material.Neon, transparency = 0.45, collide = false, castShadow = false })
	Kit.part(m, { name = "EventHorizon", shape = "Cylinder", size = Vector3.new(0.8, R * 0.8, R * 0.8), cf = face * CFrame.new(0.8, 0, 0), color = { 8, 0, 18 }, material = Enum.Material.SmoothPlastic, collide = false, castShadow = false })
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * R * 0.55, math.sin(a) * R * 0.55, -1)
		Kit.part(m, { name = "SwirlArm", size = Vector3.new(R * 0.6, 0.6, 0.3), cf = CFrame.new(p) * CFrame.Angles(0, 0, a + 1.1), color = PURPLE_HOT, material = Enum.Material.Neon, transparency = 0.2, collide = false, castShadow = false })
	end
	local heart = Kit.ball(m, { name = "Singularity", diameter = 4, cf = CFrame.new(center + Vector3.new(0, 0, -1.4)), color = { 255, 230, 255 }, material = Enum.Material.Neon, collide = false })
	Kit.light(heart, PURPLE, 60, 2.5)
	Kit.particles(heart, { color = PURPLE_HOT, color2 = { 60, 20, 120 }, size = 1.2, sizeEnd = 0, rate = 14, lifetime = 3, speed = 10, spread = 180, emission = 1 })
	-- stepped dais and the pedestal the ring stands on
	local floorZ = center.Z
	for i = 0, 2 do
		Kit.part(m, { name = "DaisStep", size = Vector3.new(64 - i * 10, 1, 22 - i * 4), cf = CFrame.new(center.X, 0.5 + i, floorZ + i * 1.5), color = (i % 2 == 0) and OBSIDIAN_DARK or OBSIDIAN, material = Enum.Material.Glass, reflectance = 0.15 })
		Kit.part(m, { name = "DaisGlow", size = Vector3.new(64 - i * 10, 0.2, 0.4), cf = CFrame.new(center.X, 1.02 + i, floorZ + i * 1.5 - (11 - i * 2) + 0.2), color = PURPLE, material = Enum.Material.Neon, collide = false })
	end
	Kit.part(m, { name = "RingPedestal", size = Vector3.new(14, center.Y - R - 3.5, 8), cf = CFrame.new(center.X, 3 + (center.Y - R - 6.5) / 2, center.Z), color = OBSIDIAN_DARK, material = Enum.Material.Slate })
	-- flanking obelisks holding the ring with chains of light
	for _, s in ipairs({ -1, 1 }) do
		local x = center.X + s * (R + 16)
		Kit.part(m, { name = "Obelisk", size = Vector3.new(6, 48, 6), cf = CFrame.new(x, 24, center.Z), color = MONOLITH, material = Enum.Material.Glass, reflectance = 0.15 })
		Kit.part(m, { name = "ObeliskTip", shape = "Wedge", size = Vector3.new(6, 8, 6), cf = CFrame.new(x, 52, center.Z) * CFrame.Angles(0, s > 0 and math.pi / 2 or -math.pi / 2, 0), color = MONOLITH, material = Enum.Material.Glass })
		local a = Vector3.new(x - s * 3, 40, center.Z)
		local b = center + Vector3.new(s * (R + 4), 10, 0)
		Kit.part(m, { name = "Tether", size = Vector3.new(0.5, 0.5, (b - a).Magnitude), cf = CFrame.lookAt((a + b) / 2, b), color = PURPLE, material = Enum.Material.Neon, collide = false })
	end
	return m
end

return function(ctx)
	local Kit = ctx.Kit
	local f = ctx.folder
	local z0, z1, W, L = ctx.z0, ctx.z1, ctx.width, ctx.length
	local zm = (z0 + z1) / 2
	local rng = ctx.rng
	local nest = ctx.nest
	local clearR = ctx.nestRadius + 14

	local function nearNest(x, z, pad)
		return (Vector3.new(x, 0, z) - Vector3.new(nest.X, 0, nest.Z)).Magnitude < clearR + (pad or 0)
	end

	-- ground: black slate bedrock under glassy obsidian plates
	Kit.part(f, { name = "Bedrock", size = Vector3.new(W, 4, L), cf = CFrame.new(0, -2, zm), color = VOID_GROUND, material = Enum.Material.Slate })
	for i = 1, 20 do
		Kit.part(f, {
			name = "ObsidianPlate",
			size = Vector3.new(rng(14, 30), 0.3, rng(12, 26)),
			cf = CFrame.new(rng(-62, 62), 0.0, z0 + (i - 0.5) * L / 20 + rng(-5, 5)) * CFrame.Angles(0, rng(0, math.pi), 0),
			color = (i % 2 == 0) and OBSIDIAN or OBSIDIAN_DARK,
			material = Enum.Material.Glass,
			reflectance = 0.2,
		})
	end

	-- the causeway: polished tiles edged with light
	local causeEnd = nest.Z - (ctx.nestRadius + 6)
	local tileLen = 10
	for i = 0, math.floor((causeEnd - z0) / tileLen) - 1 do
		Kit.part(f, { name = "CausewayTile", size = Vector3.new(22, 0.4, tileLen - 0.4), cf = CFrame.new(0, 0.1, z0 + (i + 0.5) * tileLen), color = (i % 2 == 0) and { 38, 30, 58 } or { 28, 22, 44 }, material = Enum.Material.Glass, reflectance = 0.25 })
	end
	for side = -1, 1, 2 do
		local len = causeEnd - z0
		Kit.part(f, { name = "CausewayEdge", size = Vector3.new(0.5, 0.2, len), cf = CFrame.new(side * 11.4, 0.32, z0 + len / 2), color = PURPLE, material = Enum.Material.Neon, collide = false })
	end

	-- fissures: jagged glowing cracks crawling across the plain
	for i = 1, 11 do
		local side = (i % 2 == 0) and 1 or -1
		local p = Vector3.new(side * rng(14, 30), 0.26, z0 + rng(8, 250))
		local heading = rng(0, math.pi * 2)
		for s = 1, 5 do
			heading = heading + rng(-0.9, 0.9)
			local len = rng(4, 9)
			local q = p + Vector3.new(math.cos(heading) * len, 0, math.sin(heading) * len)
			if math.abs(q.X) > 72 or q.Z < z0 + 3 or q.Z > z1 - 3 or nearNest(q.X, q.Z, -6) then
				break
			end
			Kit.part(f, { name = "Fissure", size = Vector3.new(0.5 + (5 - s) * 0.12, 0.12, len + 0.4), cf = CFrame.lookAt((p + q) / 2, q), color = (s == 1) and PURPLE_HOT or PURPLE, material = Enum.Material.Neon, collide = false, castShadow = false })
			p = q
		end
		if i % 4 == 1 then
			local glow = Kit.part(f, { name = "FissureGlow", size = Vector3.new(0.4, 0.2, 0.4), cf = CFrame.new(p), transparency = 1, collide = false, castShadow = false })
			glow.CanQuery = false
			Kit.light(glow, PURPLE, 16, 1)
		end
	end

	-- monoliths along the walls
	for side = -1, 1, 2 do
		for i = 0, 4 do
			local x = side * rng(46, 66)
			local z = z0 + 18 + i * 52 + rng(-6, 6) + ((side > 0) and 20 or 0)
			if not nearNest(x, z, 6) and z < z1 - 8 then
				monolith(ctx, f, Vector3.new(x, 0, z), rng(22, 38), rng(-0.4, 0.4) + (side > 0 and math.pi / 2 or -math.pi / 2))
			end
		end
	end

	-- rifts torn open beside the route
	for _, r in ipairs({ { -28, 30, 0.4 }, { 30, 76, -0.3 }, { -34, 120, 0.2 }, { 64, 196, 1.2 }, { -62, 214, -1.1 } }) do
		rift(ctx, f, Vector3.new(r[1], 0, z0 + r[2]), rng(12, 18), r[3])
	end

	-- debris of earlier zones drifting overhead
	brokenRoof(ctx, f, Vector3.new(-40, 34, z0 + 70))
	frozenSpire(ctx, f, Vector3.new(44, 42, z0 + 40))
	coralFragment(ctx, f, Vector3.new(-54, 48, z0 + 160))
	lavaChunk(ctx, f, Vector3.new(50, 30, z0 + 140))
	uprootedTree(ctx, f, Vector3.new(26, 58, z0 + 100))
	for i = 1, 22 do
		local side = (i % 2 == 0) and 1 or -1
		shard(ctx, f, Vector3.new(side * rng(16, 72), rng(14, 70), z0 + rng(10, 250)), rng(0.6, 2.2))
	end
	-- low shards half-sunk into the ground near the walls
	for i = 1, 8 do
		local side = (i % 2 == 0) and 1 or -1
		local x, z = side * rng(30, 60), z0 + rng(10, 250)
		if not nearNest(x, z, 4) then
			Kit.part(f, { name = "GroundShard", shape = "Wedge", size = Vector3.new(rng(2, 4), rng(4, 9), rng(3, 6)), cf = CFrame.new(x, 2, z) * CFrame.Angles(rng(-0.3, 0.3), rng(0, 3), rng(-0.3, 0.3)), color = OBSIDIAN, material = Enum.Material.Glass, reflectance = 0.2 })
		end
	end

	-- hero: the cracked portal behind the nest
	portal(ctx, f, Vector3.new(0, 38, z1 - 14))

	-- starfield: a few fixed stars plus slow glittering dust
	for i = 1, 24 do
		Kit.ball(f, { name = "Star", diameter = rng(0.4, 1.1), cf = CFrame.new(rng(-76, 76), rng(90, 118), z0 + rng(4, 256)), color = (i % 4 == 0) and PURPLE_HOT or { 255, 255, 255 }, material = Enum.Material.Neon, collide = false, castShadow = false })
	end
	local dust = Kit.part(f, { name = "StarDust", size = Vector3.new(W - 10, 40, L - 10), cf = CFrame.new(0, 40, zm), transparency = 1, collide = false, castShadow = false })
	dust.CanQuery = false
	Kit.particles(dust, { color = { 255, 255, 255 }, color2 = PURPLE_HOT, size = 0.3, sizeEnd = 0, rate = 20, lifetime = 6, speed = 0.3, emission = 1, transparency = 0.1, texture = "rbxasset://textures/particles/sparkles_main.dds" })

	return {
		palette = {
			accent = { 200, 100, 255 },
			gate = { 30, 24, 46 },
			gateMaterial = Enum.Material.Basalt,
			nest = { 32, 24, 50 },
			nestMaterial = Enum.Material.Glass,
		},
	}
end
