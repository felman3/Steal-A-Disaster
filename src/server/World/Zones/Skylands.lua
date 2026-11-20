--[[
	Zone 8 — Skylands. Floating islands adrift on a sea of cloud, where storms
	are born. The route is a long grassy island with rocky cliffs underneath;
	side islands hang at different heights with waterfalls pouring into the
	clouds, wind-bent trees, crackling storm pylons and drifting rocks. Behind
	the nest a sky temple floats beneath a towering anvil thunderhead.

	Open-air gaps are allowed outside the corridor and nest (docs/ZONE_CONTRACT.md):
	anyone who falls drops through the clouds to the kill plane and goes home.

	Zone builder contract (see docs/ZONE_CONTRACT.md):
	  build(ctx) -> { palette = { accent, gate, gateMaterial, nest, nestMaterial } }
	  ctx: folder, index, zone, z0, z1, length, width, pathWidth, nest (Vector3),
	       nestRadius, rng(a,b), Kit, tree(parent, pos, scale, leafColor)
]]

local GRASS = { 120, 196, 96 }
local GRASS_DARK = { 98, 172, 82 }
local CLIFF = { 132, 126, 140 }
local CLIFF_DARK = { 98, 94, 112 }
local CLOUD = { 248, 250, 255 }
local CLOUD_SHADE = { 214, 222, 240 }
local STORM = { 92, 98, 124 }
local STORM_DARK = { 62, 66, 88 }
local MARBLE = { 236, 238, 246 }
local COPPER = { 196, 120, 70 }
local SPARK = { 190, 220, 255 }
local WATER = { 150, 210, 255 }
local WOOD = { 150, 110, 70 }

-- An island: a grass cap whose top sits at `top`, over tapering rock tiers
-- (`depth` scales how far the rock hangs down).
local function island(ctx, parent, center, radius, top, solid, depth)
	local Kit, rng = ctx.Kit, ctx.rng
	local m = Kit.model(parent, "Island")
	Kit.cylinder(m, { name = "IslandGrass", height = 2, diameter = radius * 2, cf = CFrame.new(center.X, top - 1, center.Z), color = GRASS, material = Enum.Material.Grass, collide = solid })
	local y = top - 2
	local r = radius
	for i = 1, 3 do
		local h = radius * (0.35 + i * 0.12) * (depth or 1)
		r = r * 0.72
		Kit.cylinder(m, {
			name = "IslandRock",
			height = h,
			diameter = r * 2 + 2,
			cf = CFrame.new(center.X + rng(-1, 1), y - h / 2, center.Z + rng(-1, 1)),
			color = (i % 2 == 0) and CLIFF_DARK or CLIFF,
			material = (i == 1) and Enum.Material.Rock or Enum.Material.Slate,
			collide = solid,
		})
		y = y - h
	end
	Kit.ball(m, { name = "IslandTip", diameter = r * 1.4, cf = CFrame.new(center.X, y, center.Z), color = CLIFF_DARK, material = Enum.Material.Slate, collide = false })
	return m
end

-- Waterfall pouring off an island edge into the cloud sea.
local function waterfall(ctx, parent, top, dir, width)
	local Kit = ctx.Kit
	local bottom = -30
	local h = top.Y - bottom
	local cf = CFrame.lookAt(Vector3.new(top.X, top.Y - h / 2, top.Z), Vector3.new(top.X, top.Y - h / 2, top.Z) + dir)
	Kit.part(parent, { name = "Waterfall", size = Vector3.new(width, h, 0.8), cf = cf, color = WATER, material = Enum.Material.Glass, transparency = 0.35, collide = false, castShadow = false })
	Kit.part(parent, { name = "WaterfallSheen", size = Vector3.new(width * 0.35, h, 0.9), cf = cf * CFrame.new(width * 0.15, 0, -0.1), color = { 235, 250, 255 }, material = Enum.Material.Neon, transparency = 0.45, collide = false, castShadow = false })
	Kit.part(parent, { name = "WaterLip", size = Vector3.new(width, 0.3, 3), cf = CFrame.lookAt(top - dir * 1.4 + Vector3.new(0, 0.05, 0), top + dir), color = WATER, material = Enum.Material.Glass, transparency = 0.2, collide = false })
	local mist = Kit.ball(parent, { name = "Mist", diameter = width * 2.2, cf = CFrame.new(top.X, -24, top.Z) + dir * 2, color = CLOUD, material = Enum.Material.SmoothPlastic, transparency = 0.3, collide = false, castShadow = false })
	Kit.particles(mist, { color = { 255, 255, 255 }, size = 1.5, sizeEnd = 4, rate = 4, lifetime = 3, speed = 3, spread = 60, emission = 0.2, transparency = 0.5 })
end

-- Wind-swept tree: a leaning trunk with its crown blown downwind (+X).
local function windTree(ctx, parent, pos, scale, wind)
	local Kit, rng = ctx.Kit, ctx.rng
	local m = Kit.model(parent, "WindTree")
	local lean = 0.35 * wind
	local h = 10 * scale
	Kit.cylinder(m, { name = "Trunk", height = h, diameter = 1.3 * scale, cf = CFrame.new(pos) * CFrame.Angles(0, 0, -lean) * CFrame.new(0, h / 2, 0), color = { 120, 90, 64 }, material = Enum.Material.Wood })
	local crown = pos + Vector3.new(math.sin(lean) * h + wind * 2 * scale, h * math.cos(lean), 0)
	Kit.ball(m, { name = "Leaves", diameter = 5.5 * scale, cf = CFrame.new(crown), color = GRASS_DARK, material = Enum.Material.LeafyGrass, collide = false })
	Kit.ball(m, { name = "Leaves", diameter = 4.5 * scale, cf = CFrame.new(crown + Vector3.new(wind * 3.6 * scale, -0.8 * scale, rng(-1, 1))), color = GRASS, material = Enum.Material.LeafyGrass, collide = false })
	Kit.ball(m, { name = "Leaves", diameter = 3.4 * scale, cf = CFrame.new(crown + Vector3.new(wind * 6.4 * scale, -1.6 * scale, rng(-1, 1))), color = { 140, 210, 110 }, material = Enum.Material.LeafyGrass, collide = false })
	return m
end

-- Storm pylon: a marble column wound with copper coils and a crackling orb.
local function stormPylon(ctx, parent, pos)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "StormPylon")
	Kit.part(m, { name = "PylonBase", size = Vector3.new(3.4, 1, 3.4), cf = CFrame.new(pos + Vector3.new(0, 0.5, 0)), color = MARBLE, material = Enum.Material.Marble })
	Kit.cylinder(m, { name = "PylonColumn", height = 12, diameter = 1.5, cf = CFrame.new(pos + Vector3.new(0, 7, 0)), color = MARBLE, material = Enum.Material.Marble })
	for i = 1, 3 do
		Kit.cylinder(m, { name = "Coil", height = 0.5, diameter = 2.8 - i * 0.3, cf = CFrame.new(pos + Vector3.new(0, 7 + i * 1.6, 0)), color = COPPER, material = Enum.Material.Metal })
	end
	local orb = Kit.ball(m, { name = "StormOrb", diameter = 2.2, cf = CFrame.new(pos + Vector3.new(0, 14.2, 0)), color = SPARK, material = Enum.Material.Neon, collide = false })
	Kit.light(orb, SPARK, 18, 1.3)
	Kit.particles(orb, { color = { 220, 235, 255 }, color2 = { 160, 120, 255 }, size = 0.5, sizeEnd = 0, rate = 8, lifetime = 0.4, speed = 6, emission = 1 })
	-- frozen arcs crackling off the orb
	for k, a in ipairs({ 0.6, 2.7, 4.6 }) do
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p1 = pos + Vector3.new(0, 14.2, 0) + dir * 1.2
		local p2 = p1 + dir * 1.6 + Vector3.new(0, (k % 2 == 0) and 1.4 or -1.2, 0)
		local p3 = p2 + dir * 1.2 + Vector3.new(0, (k % 2 == 0) and -0.6 or 0.8, 0)
		Kit.part(m, { name = "Arc", size = Vector3.new(0.18, 0.18, (p2 - p1).Magnitude), cf = CFrame.lookAt((p1 + p2) / 2, p2), color = SPARK, material = Enum.Material.Neon, collide = false })
		Kit.part(m, { name = "Arc", size = Vector3.new(0.15, 0.15, (p3 - p2).Magnitude), cf = CFrame.lookAt((p2 + p3) / 2, p3), color = SPARK, material = Enum.Material.Neon, collide = false })
	end
	return m
end

-- Puffy cloud cluster (non-colliding).
local function cloud(ctx, parent, pos, scale, color)
	local Kit, rng = ctx.Kit, ctx.rng
	color = color or CLOUD
	Kit.ball(parent, { name = "Cloud", diameter = 12 * scale, cf = CFrame.new(pos), color = color, material = Enum.Material.SmoothPlastic, collide = false, castShadow = false })
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + rng(0, 1)
		Kit.ball(parent, {
			name = "Cloud",
			diameter = (7 + rng(0, 3)) * scale,
			cf = CFrame.new(pos + Vector3.new(math.cos(a) * 6 * scale, rng(-2, 1) * scale, math.sin(a) * 4 * scale)),
			color = (i == 2) and CLOUD_SHADE or color,
			material = Enum.Material.SmoothPlastic,
			collide = false,
			castShadow = false,
		})
	end
end

-- Floating rock shard: a rough lump with a dangling point.
local function floatingRock(ctx, parent, pos, s)
	local Kit, rng = ctx.Kit, ctx.rng
	Kit.part(parent, { name = "FloatRock", size = Vector3.new(3 * s, 1.6 * s, 2.6 * s), cf = CFrame.new(pos) * CFrame.Angles(rng(-0.3, 0.3), rng(0, 3), rng(-0.3, 0.3)), color = CLIFF, material = Enum.Material.Slate, collide = false })
	Kit.part(parent, { name = "FloatRockTip", shape = "Wedge", size = Vector3.new(2 * s, 2.4 * s, 1.6 * s), cf = CFrame.new(pos + Vector3.new(0, -1.8 * s, 0)) * CFrame.Angles(math.pi, rng(0, 3), 0), color = CLIFF_DARK, material = Enum.Material.Slate, collide = false })
	Kit.part(parent, { name = "FloatRockMoss", size = Vector3.new(2.6 * s, 0.3, 2.2 * s), cf = CFrame.new(pos + Vector3.new(0, 0.85 * s, 0)), color = GRASS, material = Enum.Material.Grass, collide = false })
end

-- Rope-and-plank bridge between two points at ground level (along X).
local function bridge(ctx, parent, x0, x1, z)
	local Kit = ctx.Kit
	local n = math.floor(math.abs(x1 - x0) / 2.2)
	local dir = (x1 > x0) and 1 or -1
	for i = 0, n do
		Kit.part(parent, { name = "BridgePlank", size = Vector3.new(1.9, 0.4, 5), cf = CFrame.new(x0 + dir * (i * 2.2 + 1), -0.2, z) * CFrame.Angles(0, 0, (i % 2 == 0) and 0.02 or -0.02), color = (i % 2 == 0) and WOOD or Kit.shade(WOOD, 0.85), material = Enum.Material.WoodPlanks })
	end
	for _, s in ipairs({ -1, 1 }) do
		for _, x in ipairs({ x0, x1 }) do
			Kit.cylinder(parent, { name = "BridgePost", height = 3.4, diameter = 0.5, cf = CFrame.new(x, 1.7, z + s * 2.6), color = Kit.shade(WOOD, 0.7), material = Enum.Material.Wood })
		end
		Kit.part(parent, { name = "BridgeRope", size = Vector3.new(math.abs(x1 - x0), 0.2, 0.2), cf = CFrame.new((x0 + x1) / 2, 2.6, z + s * 2.6), color = { 200, 180, 140 }, material = Enum.Material.Fabric, collide = false })
	end
end

-- The sky temple floating beneath the anvil thunderhead.
local function skyTemple(ctx, parent, pos)
	local Kit, rng = ctx.Kit, ctx.rng
	local m = Kit.model(parent, "SkyTemple")
	island(ctx, m, pos, 15, pos.Y, true, 0.45)
	Kit.cylinder(m, { name = "TempleFloor", height = 1, diameter = 24, cf = CFrame.new(pos + Vector3.new(0, 0.5, 0)), color = MARBLE, material = Enum.Material.Marble })
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local p = pos + Vector3.new(math.cos(a) * 10, 0, math.sin(a) * 10)
		if i ~= 3 then -- one pillar has fallen
			Kit.cylinder(m, { name = "TemplePillar", height = 13, diameter = 1.8, cf = CFrame.new(p + Vector3.new(0, 7.5, 0)), color = MARBLE, material = Enum.Material.Marble })
		else
			Kit.cylinder(m, { name = "BrokenPillar", height = 5, diameter = 1.8, cf = CFrame.new(p + Vector3.new(0, 3.5, 0)), color = MARBLE, material = Enum.Material.Marble })
		end
		Kit.part(m, { name = "PillarCap", size = Vector3.new(2.6, 0.8, 2.6), cf = CFrame.new(p + Vector3.new(0, 14.4, 0)), color = MARBLE, material = Enum.Material.Marble })
	end
	Kit.cylinder(m, { name = "TempleRing", height = 1.6, diameter = 24, cf = CFrame.new(pos + Vector3.new(0, 15.6, 0)), color = MARBLE, material = Enum.Material.Marble })
	Kit.ball(m, { name = "TempleDome", diameter = 18, cf = CFrame.new(pos + Vector3.new(0, 16, 0)), color = { 170, 200, 240 }, material = Enum.Material.Marble })
	Kit.cylinder(m, { name = "DomeBand", height = 0.8, diameter = 12, cf = CFrame.new(pos + Vector3.new(0, 23.6, 0)), color = COPPER, material = Enum.Material.Metal })
	local rod = Kit.cylinder(m, { name = "LightningRod", height = 8, diameter = 0.6, cf = CFrame.new(pos + Vector3.new(0, 28, 0)), color = COPPER, material = Enum.Material.Metal })
	local core = Kit.ball(m, { name = "StormHeart", diameter = 5, cf = CFrame.new(pos + Vector3.new(0, 6.5, 0)), color = SPARK, material = Enum.Material.Neon, collide = false })
	Kit.light(core, { 180, 200, 255 }, 34, 2)
	Kit.particles(core, { color = { 220, 235, 255 }, color2 = { 170, 130, 255 }, size = 0.8, sizeEnd = 0, rate = 12, lifetime = 0.5, speed = 8, emission = 1 })
	-- waterfalls off the temple island's front lip
	for _, x in ipairs({ -8, 9 }) do
		waterfall(ctx, m, Vector3.new(pos.X + x, pos.Y - 0.2, pos.Z - 14), Vector3.new(0, 0, -1), 4)
	end
	return m, rod
end

-- The anvil thunderhead: a churning column with a flat top that overhangs the nest.
local function anvilCloud(ctx, parent, base, rodTop)
	local Kit, rng = ctx.Kit, ctx.rng
	local m = Kit.model(parent, "AnvilCloud")
	for i = 0, 4 do
		local y = base.Y + i * 6
		local d = 26 + math.sin(i * 0.9) * 4 + i * 0.6
		Kit.ball(m, { name = "StormColumn", diameter = d, cf = CFrame.new(base.X + rng(-4, 4), y, base.Z + rng(-3, 3)), color = Kit.mix(STORM_DARK, STORM, i / 4), material = Enum.Material.SmoothPlastic, collide = false, castShadow = false })
		Kit.ball(m, { name = "StormColumn", diameter = d * 0.7, cf = CFrame.new(base.X + ((i % 2 == 0) and 12 or -12), y + 3, base.Z + rng(-2, 4)), color = Kit.mix(STORM_DARK, STORM, math.min(1, i / 4 + 0.1)), material = Enum.Material.SmoothPlastic, collide = false, castShadow = false })
	end
	-- the anvil: a wide flat sheet of puffs, spreading in X and toward the route
	local topY = base.Y + 32
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local rx, rz = 58, 34
		local x = math.cos(a) * rx * rng(0.75, 1)
		local z = base.Z - 16 + math.sin(a) * rz * rng(0.75, 1)
		z = math.min(z, base.Z + 4)
		Kit.ball(m, { name = "Anvil", diameter = rng(16, 24), cf = CFrame.new(x, topY + rng(-2, 3), z), color = (i % 3 == 0) and CLOUD_SHADE or { 196, 204, 226 }, material = Enum.Material.SmoothPlastic, collide = false, castShadow = false })
	end
	for _, p in ipairs({ { 0, -16, 34 }, { -26, -12, 26 }, { 26, -18, 26 }, { 0, -36, 24 } }) do
		Kit.ball(m, { name = "AnvilCore", diameter = p[3], cf = CFrame.new(p[1], topY + 2, base.Z + p[2]), color = { 206, 212, 232 }, material = Enum.Material.SmoothPlastic, collide = false, castShadow = false })
	end
	-- lightning: frozen zig-zag bolts from the cloud down to the temple rod and the clouds
	local function bolt(from, to, segs, seed)
		local prev = from
		for s = 1, segs do
			local t = s / segs
			local p = from:Lerp(to, t)
			if s < segs then
				p = p + Vector3.new(math.sin(seed + s * 2.1) * 3, 0, math.cos(seed + s * 1.7) * 2)
			end
			Kit.part(m, { name = "Lightning", size = Vector3.new(0.45, 0.45, (p - prev).Magnitude), cf = CFrame.lookAt((prev + p) / 2, p), color = { 235, 240, 255 }, material = Enum.Material.Neon, collide = false, castShadow = false })
			prev = p
		end
	end
	bolt(Vector3.new(base.X + 4, base.Y - 2, base.Z - 4), rodTop, 2, 1)
	bolt(Vector3.new(-30, topY - 6, base.Z - 30), Vector3.new(-62, 54, base.Z - 17), 4, 3)
	bolt(Vector3.new(36, topY - 6, base.Z - 24), Vector3.new(64, 46, base.Z - 15), 4, 5)
	local flash = Kit.ball(m, { name = "StormGlow", diameter = 6, cf = CFrame.new(base + Vector3.new(0, 4, -8)), color = { 200, 180, 255 }, material = Enum.Material.Neon, transparency = 0.4, collide = false, castShadow = false })
	Kit.light(flash, { 190, 170, 255 }, 60, 2.2)
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

	-- the route island: grass cap at y = 0 over stepped cliffs
	local routeLen = nest.Z - z0
	local routeW = 48
	Kit.part(f, { name = "RouteGrass", size = Vector3.new(routeW, 2, routeLen), cf = CFrame.new(0, -1, z0 + routeLen / 2), color = GRASS, material = Enum.Material.Grass })
	Kit.part(f, { name = "RouteCliff", size = Vector3.new(routeW - 2, 9, routeLen - 2), cf = CFrame.new(0, -6.5, z0 + routeLen / 2 + 1), color = CLIFF, material = Enum.Material.Rock })
	Kit.part(f, { name = "RouteCliff", size = Vector3.new(routeW - 14, 10, routeLen - 16), cf = CFrame.new(1, -16, z0 + routeLen / 2 + 6), color = CLIFF_DARK, material = Enum.Material.Slate })
	Kit.part(f, { name = "RouteCliff", size = Vector3.new(routeW - 28, 9, routeLen - 50), cf = CFrame.new(-1, -25, z0 + routeLen / 2 + 14), color = CLIFF_DARK, material = Enum.Material.Slate, collide = false })
	-- grassy outcrops bulging off the island edges
	for i = 0, 7 do
		for side = -1, 1, 2 do
			local z = z0 + 10 + i * 18 + rng(-3, 3) + ((side > 0) and 8 or 0)
			if z < nest.Z - 50 then
				local w = rng(8, 13)
				local d = rng(12, 20)
				Kit.part(f, { name = "Outcrop", size = Vector3.new(w, 2, d), cf = CFrame.new(side * (routeW / 2 + w / 2 - 2), -1, z), color = (i % 2 == 0) and GRASS_DARK or GRASS, material = Enum.Material.Grass })
				Kit.part(f, { name = "OutcropRock", shape = "Wedge", size = Vector3.new(w - 1, 8, d - 2), cf = CFrame.new(side * (routeW / 2 + w / 2 - 2.5), -6, z) * CFrame.Angles(math.pi, 0, 0), color = CLIFF, material = Enum.Material.Rock })
			end
		end
	end
	-- a pale stone path down the middle of the island
	for z = z0 + 4, nest.Z - 44, 8 do
		Kit.part(f, { name = "PathStone", size = Vector3.new(rng(5, 7), 0.3, rng(4.5, 6)), cf = CFrame.new(rng(-1.5, 1.5), 0.1, z) * CFrame.Angles(0, rng(-0.3, 0.3), 0), color = { 222, 224, 232 }, material = Enum.Material.Marble })
	end

	-- the nest island, and a back terrace leading on to the next zone
	island(ctx, f, Vector3.new(nest.X, 0, nest.Z), 64, 0, true)
	Kit.part(f, { name = "BackTerrace", size = Vector3.new(44, 2, z1 - (nest.Z + 40)), cf = CFrame.new(0, -1, (z1 + nest.Z + 40) / 2), color = GRASS, material = Enum.Material.Grass })
	Kit.part(f, { name = "BackCliff", size = Vector3.new(40, 12, z1 - (nest.Z + 44)), cf = CFrame.new(0, -8, (z1 + nest.Z + 44) / 2), color = CLIFF, material = Enum.Material.Rock })
	-- marble rim around the nest island edge
	for i = 0, 19 do
		local a = i / 20 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		if math.abs(dir.X) > 0.45 then -- leave the route ends open
			local p = nest + dir * 61
			Kit.part(f, { name = "Balustrade", size = Vector3.new(1.4, 2.6, 8), cf = CFrame.lookAt(Vector3.new(p.X, 1.3, p.Z), Vector3.new(p.X, 1.3, p.Z) + Vector3.new(-dir.Z, 0, dir.X)), color = MARBLE, material = Enum.Material.Marble })
		end
	end

	-- side islands at ground level, reached by rope bridges
	island(ctx, f, Vector3.new(-50, 0, z0 + 66), 16, 0, true)
	bridge(ctx, f, -routeW / 2 + 1, -35, z0 + 66)
	island(ctx, f, Vector3.new(52, 0, z0 + 118), 14, 0, true)
	bridge(ctx, f, routeW / 2 - 1, 39, z0 + 118)
	waterfall(ctx, f, Vector3.new(-62, -0.2, z0 + 74), Vector3.new(-0.6, 0, 0.8).Unit, 5)
	waterfall(ctx, f, Vector3.new(60, -0.2, z0 + 128), Vector3.new(0.5, 0, 0.85).Unit, 4)
	windTree(ctx, f, Vector3.new(-52, 0, z0 + 60), 1.3, 1)
	windTree(ctx, f, Vector3.new(-44, 0, z0 + 74), 0.9, 1)
	windTree(ctx, f, Vector3.new(50, 0, z0 + 114), 1.1, 1)
	stormPylon(ctx, f, Vector3.new(-56, 0, z0 + 72))
	stormPylon(ctx, f, Vector3.new(56, 0, z0 + 124))

	-- islands floating at different heights, each spilling a waterfall
	local floaters = {
		{ -58, 16, 18, 12 }, { 60, 26, 52, 10 }, { -60, 34, 150, 13 }, { 62, 12, 176, 11 },
		{ -24, 48, 30, 7 }, { 34, 58, 96, 8 }, { -66, 52, 236, 9 }, { 66, 44, 238, 9 },
	}
	for i, fl in ipairs(floaters) do
		local x, y, z, r = fl[1], fl[2], z0 + fl[3], fl[4]
		local solid = not nearNest(x, z, r + 2)
		island(ctx, f, Vector3.new(x, 0, z), r, y, solid)
		if i % 2 == 1 then
			windTree(ctx, f, Vector3.new(x + rng(-2, 2), y, z + rng(-2, 2)), 0.8 + rng(0, 0.3), 1)
		end
		if i <= 4 then
			local dir = Vector3.new((x > 0) and -0.3 or 0.3, 0, -1).Unit
			waterfall(ctx, f, Vector3.new(x, y - 0.2, z) + dir * (r - 1), dir, 3.5)
		end
	end

	-- storm pylons lining the route
	for i = 0, 3 do
		local z = z0 + 20 + i * 30
		for side = -1, 1, 2 do
			stormPylon(ctx, f, Vector3.new(side * 19, 0, z + ((side > 0) and 6 or 0)))
		end
	end
	-- wind-bent trees on the outcrops
	for i, s in ipairs({ { -30, 24 }, { 31, 48 }, { -31, 96 }, { 30, 84 } }) do
		windTree(ctx, f, Vector3.new(s[1], 0, z0 + s[2]), 1 + (i % 2) * 0.2, 1)
	end
	-- trees around the nest island rim
	for _, a in ipairs({ 0.3, 2.8, 3.5, 5.9 }) do
		local p = nest + Vector3.new(math.cos(a), 0, math.sin(a)) * 56
		windTree(ctx, f, p, 1.1, 1)
	end

	-- drifting rocks
	for i = 1, 12 do
		local side = (i % 2 == 0) and 1 or -1
		floatingRock(ctx, f, Vector3.new(side * rng(28, 72), rng(8, 60), z0 + rng(10, 250)), rng(0.8, 2))
	end

	-- the cloud sea below, and fair-weather clouds above
	Kit.part(f, { name = "CloudSea", size = Vector3.new(W + 10, 4, L), cf = CFrame.new(0, -34, zm), color = CLOUD, material = Enum.Material.SmoothPlastic, collide = false, castShadow = false })
	for i = 0, 25 do
		local x = -70 + (i % 6) * 28 + rng(-6, 6)
		local z = z0 + 10 + math.floor(i / 6) * 58 + rng(-10, 10)
		Kit.ball(f, { name = "CloudSeaPuff", diameter = rng(16, 30), cf = CFrame.new(x, rng(-30, -22), z), color = (i % 3 == 0) and CLOUD_SHADE or CLOUD, material = Enum.Material.SmoothPlastic, collide = false, castShadow = false })
	end
	for _, c in ipairs({ { -60, 70, 20 }, { 54, 84, 70 }, { -44, 92, 120 }, { 66, 66, 150 }, { -66, 78, 200 }, { 40, 100, 30 } }) do
		cloud(ctx, f, Vector3.new(c[1], c[2], z0 + c[3]), 1 + rng(0, 0.6))
	end

	-- hero: the sky temple beneath the anvil thunderhead
	local templePos = Vector3.new(0, 42, z1 - 14)
	local _, rod = skyTemple(ctx, f, templePos)
	anvilCloud(ctx, f, Vector3.new(0, 80, z1 - 8), rod.Position + Vector3.new(0, 4, 0))

	-- wind streaks blowing across the route
	-- (emitter's top face turned to blow toward +X)
	local wind = Kit.part(f, { name = "Wind", size = Vector3.new(4, 30, L - 20), cf = CFrame.new(-70, 15, zm) * CFrame.Angles(0, 0, -math.pi / 2), transparency = 1, collide = false, castShadow = false })
	wind.CanQuery = false
	Kit.particles(wind, { color = { 255, 255, 255 }, size = 0.3, sizeEnd = 0.1, rate = 14, lifetime = 5, speed = 28, spread = 4, emission = 0.6, transparency = 0.5 })

	return {
		palette = {
			accent = { 170, 210, 255 },
			gate = MARBLE,
			gateMaterial = Enum.Material.Marble,
			nest = { 206, 212, 230 },
			nestMaterial = Enum.Material.Marble,
		},
	}
end
