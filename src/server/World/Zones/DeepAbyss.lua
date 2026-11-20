--[[
	Zone 6 — Deep Abyss. The ocean drained out of this trench long ago and
	forgot to take the pressure with it: a dark slate-and-sand seabed between
	towering rock walls, branching coral that still glows at the tips, giant
	kelp, clams, a broken shipwreck, and the ribcage of a colossal whale
	behind the nest. A rippling "water ceiling" hangs far overhead.

	Zone builder contract (see docs/ZONE_CONTRACT.md):
	  build(ctx) -> { palette = { accent, gate, gateMaterial, nest, nestMaterial } }
	  ctx: folder, index, zone, z0, z1, length, width, pathWidth, nest (Vector3),
	       nestRadius, rng(a,b), Kit, tree(parent, pos, scale, leafColor)
]]

local SEABED = { 46, 56, 74 }
local SEABED_DARK = { 34, 42, 58 }
local SAND_RIPPLE = { 66, 78, 98 }
local TRENCH_LANE = { 30, 37, 52 }
local ROCK = { 38, 46, 62 }
local ROCK_LIGHT = { 52, 62, 82 }
local BONE = { 214, 210, 192 }
local WOOD = { 84, 66, 50 }
local WOOD_DARK = { 62, 48, 38 }
local KELP = { { 58, 112, 58 }, { 74, 128, 54 }, { 52, 98, 66 } }
local CORAL = { { 255, 110, 150 }, { 255, 140, 70 }, { 50, 200, 190 }, { 190, 110, 230 } }
local GLOW = { 80, 230, 255 }

-- Cylinder spanning two points (Roblox cylinders run along local X).
local function limb(Kit, parent, a, b, d, o)
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local cf
	if flat.Magnitude < 0.01 then
		cf = CFrame.new(mid) * CFrame.Angles(0, 0, math.pi / 2)
	else
		cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0)
	end
	return Kit.part(parent, {
		name = o.name or "Limb",
		shape = "Cylinder",
		size = Vector3.new(len, d, d),
		cf = cf,
		color = o.color,
		material = o.material,
		collide = o.collide,
		transparency = o.transparency,
	})
end

-- Branching coral: a trunk that forks into upturned arms with bulbous tips.
local function coral(ctx, parent, pos, scale, color, glowTips)
	local Kit, rng = ctx.Kit, ctx.rng
	local m = Kit.model(parent, "Coral")
	local trunkTop = pos + Vector3.new(0, 4 * scale, 0)
	limb(Kit, m, pos, trunkTop, 1.8 * scale, { name = "CoralTrunk", color = Kit.shade(color, 0.8), material = Enum.Material.Pebble })
	local arms = 4
	local spin = rng(0, math.pi * 2)
	for i = 1, arms do
		local a = spin + i / arms * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local elbow = trunkTop + dir * (2.6 * scale) + Vector3.new(0, (2.5 + rng(0, 1.5)) * scale, 0)
		limb(Kit, m, trunkTop, elbow, 1.2 * scale, { name = "CoralArm", color = color, material = Enum.Material.Pebble })
		local tip = elbow + dir * (1.2 * scale) + Vector3.new(0, (2.5 + rng(0, 2.5)) * scale, 0)
		limb(Kit, m, elbow, tip, 0.9 * scale, { name = "CoralArm", color = color, material = Enum.Material.Pebble })
		local glow = glowTips and i % 2 == 0
		local bulb = Kit.ball(m, {
			name = glow and "CoralGlow" or "CoralTip",
			diameter = 1.3 * scale,
			cf = CFrame.new(tip),
			color = glow and Kit.mix(color, { 255, 255, 255 }, 0.35) or Kit.shade(color, 1.15),
			material = glow and Enum.Material.Neon or Enum.Material.Pebble,
		})
		if glow and i == 2 then
			Kit.light(bulb, color, 14, 0.8)
		end
	end
	return m
end

-- Sea fan: a flat lattice disc on a stub, standing edge-on like a hand of lace.
local function seaFan(ctx, parent, pos, scale, color, yaw)
	local Kit = ctx.Kit
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	Kit.cylinder(parent, { name = "FanStub", height = 2 * scale, diameter = 0.8 * scale, cf = base * CFrame.new(0, 1 * scale, 0), color = Kit.shade(color, 0.7), material = Enum.Material.Pebble })
	Kit.part(parent, { name = "SeaFan", shape = "Cylinder", size = Vector3.new(0.3, 9 * scale, 9 * scale), cf = base * CFrame.new(0, 6 * scale, 0), color = color, material = Enum.Material.Fabric, transparency = 0.1 })
	Kit.part(parent, { name = "SeaFan", shape = "Cylinder", size = Vector3.new(0.35, 5 * scale, 5 * scale), cf = base * CFrame.new(0, 8.5 * scale, 2.5 * scale), color = Kit.shade(color, 1.1), material = Enum.Material.Fabric })
end

-- Tube sponge cluster: open-topped stubby tubes.
local function sponges(ctx, parent, pos, color)
	local Kit, rng = ctx.Kit, ctx.rng
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + rng(0, 1)
		local p = pos + Vector3.new(math.cos(a) * 1.6, 0, math.sin(a) * 1.6)
		local h = rng(2.5, 6)
		Kit.cylinder(parent, { name = "Sponge", height = h, diameter = 1.6, cf = CFrame.new(p + Vector3.new(0, h / 2, 0)), color = color, material = Enum.Material.Sand })
		Kit.cylinder(parent, { name = "SpongeMouth", height = 0.2, diameter = 1.1, cf = CFrame.new(p + Vector3.new(0, h + 0.01, 0)), color = Kit.shade(color, 0.35), material = Enum.Material.SmoothPlastic, collide = false })
	end
end

-- Giant kelp: a slightly zig-zagging ribbon with blades and a float at the top.
local function kelp(ctx, parent, pos, height)
	local Kit, rng = ctx.Kit, ctx.rng
	local color = KELP[math.floor(rng(1, #KELP + 0.99))]
	local segs = 4
	local segH = height / segs
	local lean = rng(-0.12, 0.12)
	local prev = pos
	for i = 1, segs do
		local nextP = pos + Vector3.new(math.sin(i * 1.3) * 0.9 + lean * i * segH, i * segH, math.cos(i * 1.1) * 0.6)
		local mid = (prev + nextP) / 2
		Kit.part(parent, {
			name = "Kelp",
			size = Vector3.new(1.6, 0.5, (nextP - prev).Magnitude + 0.4),
			cf = CFrame.lookAt(mid, nextP),
			color = color,
			material = Enum.Material.Grass,
			collide = false,
		})
		if i == 2 or i == 3 then
			local side = (i == 2) and 1 or -1
			Kit.part(parent, {
				name = "KelpBlade",
				size = Vector3.new(0.2, segH * 0.8, 2.6),
				cf = CFrame.new(mid + Vector3.new(0, 0, side * 1.4)) * CFrame.Angles(side * 0.5, 0, 0),
				color = Kit.shade(color, 1.15),
				material = Enum.Material.Grass,
				collide = false,
			})
		end
		prev = nextP
	end
	Kit.ball(parent, { name = "KelpFloat", diameter = 1.4, cf = CFrame.new(prev + Vector3.new(0, 0.6, 0)), color = { 150, 140, 60 }, material = Enum.Material.SmoothPlastic, collide = false })
end

-- Giant clam: two ribbed shells hinged at the back, a glowing pearl inside.
local function clam(ctx, parent, pos, yaw, pearl)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "Clam")
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local shell = { 226, 196, 206 }
	Kit.cylinder(m, { name = "ShellLower", height = 1.2, diameter = 6.5, cf = base * CFrame.new(0, 0.6, 0), color = shell, material = Enum.Material.Marble })
	Kit.cylinder(m, { name = "ShellFlesh", height = 0.3, diameter = 5.4, cf = base * CFrame.new(0, 1.3, 0), color = { 120, 70, 130 }, material = Enum.Material.SmoothPlastic, collide = false })
	Kit.cylinder(m, {
		name = "ShellUpper",
		height = 1.0,
		diameter = 6.5,
		cf = base * CFrame.new(0, 1.4, 3) * CFrame.Angles(0.75, 0, 0) * CFrame.new(0, 0, -3),
		color = Kit.shade(shell, 0.92),
		material = Enum.Material.Marble,
	})
	if pearl then
		local p = Kit.ball(m, { name = "Pearl", diameter = 1.6, cf = base * CFrame.new(0, 2.1, -0.6), color = { 210, 250, 255 }, material = Enum.Material.Neon, collide = false })
		Kit.light(p, GLOW, 12, 0.9)
		Kit.particles(p, { color = { 200, 240, 255 }, size = 0.35, sizeEnd = 0.6, rate = 2, lifetime = 3, speed = 2, spread = 12, accel = Vector3.new(0, 3, 0), transparency = 0.4 })
	end
	return m
end

-- Broken hull section: curved planks over a keel, lying tilted in the silt.
local function hullSection(ctx, parent, cf, length)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "Shipwreck")
	local r = 8
	Kit.part(m, { name = "Keel", size = Vector3.new(1.6, 1.6, length + 4), cf = cf * CFrame.new(0, -r + 0.8, 0), color = WOOD_DARK, material = Enum.Material.Wood })
	for i = 0, 6 do
		local a = math.rad(-160 + i * 23.3)
		if i ~= 4 then -- one plank torn away
			local px, py = math.cos(a) * r, math.sin(a) * r
			local plankLen = length - ((i % 3) * 3)
			Kit.part(m, {
				name = "HullPlank",
				size = Vector3.new(0.8, 3.4, plankLen),
				cf = cf * CFrame.new(px, py, (i % 2) * 1.5) * CFrame.Angles(0, 0, a),
				color = (i % 2 == 0) and WOOD or WOOD_DARK,
				material = Enum.Material.WoodPlanks,
			})
		end
	end
	-- ribs of the frame poking past the planks
	for k = -1, 1 do
		for _, sgn in ipairs({ -1, 1 }) do
			local a = math.rad(sgn > 0 and -20 or -160)
			Kit.part(m, {
				name = "HullRib",
				size = Vector3.new(0.7, 6, 0.9),
				cf = cf * CFrame.new(math.cos(a) * (r + 1.8), math.sin(a) * (r + 1.8) + 2.4, k * length * 0.32) * CFrame.Angles(0, 0, a + sgn * 0.15),
				color = WOOD_DARK,
				material = Enum.Material.Wood,
			})
		end
	end
	-- a torn deck beam across the top
	Kit.part(m, { name = "DeckBeam", size = Vector3.new(2 * r + 3, 0.9, 1.4), cf = cf * CFrame.new(0, 0.6, length * 0.2) * CFrame.Angles(0, 0, 0.12), color = WOOD, material = Enum.Material.WoodPlanks })
	return m
end

-- The whale skeleton: spine arching along X, ribs falling to the seabed on
-- both sides, a huge blocky skull on the -X end and tail flukes on +X.
local function whaleSkeleton(ctx, parent, zc)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "WhaleSkeleton")
	local spine = {}
	for i = 0, 15 do
		local x = -42 + i * 7
		local t = i / 15
		local y = 9 + 24 * math.sin(math.min(1, t * 1.35) * math.pi * 0.85) * (1 - t * 0.55)
		table.insert(spine, Vector3.new(x, y, zc))
	end
	for i = 1, #spine do
		local p = spine[i]
		local taper = 1 - (i / #spine) * 0.6
		if i < #spine then
			limb(Kit, m, p, spine[i + 1], 2.8 * taper, { name = "Spine", color = BONE, material = Enum.Material.Limestone })
		end
		Kit.part(m, { name = "Vertebra", shape = "Cylinder", size = Vector3.new(1.6, 5 * taper, 5 * taper), cf = CFrame.new(p), color = Kit.shade(BONE, 0.95), material = Enum.Material.Limestone })
		Kit.part(m, { name = "SpinalSpike", size = Vector3.new(0.9, 3.2 * taper, 1.4), cf = CFrame.new(p + Vector3.new(0, 2.6 * taper, 0)) * CFrame.Angles(0, 0, -0.35), color = BONE, material = Enum.Material.Limestone })
	end
	-- ribs: quarter ellipses down to the seabed on both sides. The middle
	-- ribs have collapsed, leaving the way on to the next zone open.
	for i = 2, 10 do
		local top = spine[i]
		local rz = 6 + top.Y * 0.28
		for _, side in ipairs((math.abs(top.X) >= 12) and { -1, 1 } or {}) do
			local prev = top
			for s = 1, 3 do
				local t = s / 3 * math.pi / 2
				local p = Vector3.new(top.X + s * 0.6, 0.8 + (top.Y - 0.8) * math.cos(t), zc + side * rz * math.sin(t))
				limb(Kit, m, prev, p, 1.3, { name = "Rib", color = BONE, material = Enum.Material.Limestone })
				prev = p
			end
		end
	end
	for _, s in ipairs({ { -6, -9, 0.5 }, { 5, 7, -0.4 } }) do
		Kit.part(m, { name = "FallenRib", shape = "Cylinder", size = Vector3.new(14, 1.2, 1.2), cf = CFrame.new(s[1], 0.3, zc + s[2]) * CFrame.Angles(0, s[3], 0), color = Kit.shade(BONE, 0.9), material = Enum.Material.Limestone, collide = false })
	end
	-- skull: cranium, long rostrum and a lower jaw lying in the sand
	local head = spine[1]
	Kit.part(m, { name = "Cranium", size = Vector3.new(13, 11, 15), cf = CFrame.new(head + Vector3.new(-6, 0, 0)) * CFrame.Angles(0, 0, -0.2), color = BONE, material = Enum.Material.Limestone })
	Kit.part(m, { name = "Brow", size = Vector3.new(6, 3, 17), cf = CFrame.new(head + Vector3.new(-8, 5, 0)) * CFrame.Angles(0, 0, -0.3), color = Kit.shade(BONE, 1.04), material = Enum.Material.Limestone })
	Kit.part(m, { name = "Rostrum", shape = "Wedge", size = Vector3.new(10, 5, 24), cf = CFrame.new(head + Vector3.new(-23, -4, 0)) * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.Angles(-0.1, 0, 0), color = Kit.shade(BONE, 0.96), material = Enum.Material.Limestone })
	Kit.part(m, { name = "Jaw", size = Vector3.new(28, 2, 2), cf = CFrame.new(head.X - 20, 1.2, zc - 5) * CFrame.Angles(0, -0.12, 0.08), color = Kit.shade(BONE, 0.9), material = Enum.Material.Limestone })
	Kit.part(m, { name = "Jaw", size = Vector3.new(28, 2, 2), cf = CFrame.new(head.X - 20, 1.2, zc + 5) * CFrame.Angles(0, 0.12, -0.08), color = Kit.shade(BONE, 0.9), material = Enum.Material.Limestone })
	local eye = Kit.ball(m, { name = "EyeGlow", diameter = 2.4, cf = CFrame.new(head + Vector3.new(-9, 1, -7.4)), color = GLOW, material = Enum.Material.Neon, collide = false })
	Kit.light(eye, GLOW, 22, 1.2)
	-- pectoral fin bones (fanned fingers) and tail flukes
	local shoulder = spine[4]
	for _, side in ipairs({ -1, 1 }) do
		local elbow = Vector3.new(shoulder.X - 2, 3, zc + side * 11)
		limb(Kit, m, Vector3.new(shoulder.X, shoulder.Y - 6, zc + side * 4), elbow, 1.4, { name = "FinBone", color = BONE, material = Enum.Material.Limestone })
		for k = -1, 1 do
			limb(Kit, m, elbow, Vector3.new(elbow.X + k * 3, 0.8, elbow.Z + side * 5), 0.8, { name = "FinFinger", color = BONE, material = Enum.Material.Limestone })
		end
	end
	local tail = spine[#spine]
	for _, side in ipairs({ -1, 1 }) do
		Kit.part(m, { name = "Fluke", shape = "Wedge", size = Vector3.new(1, 3, 9), cf = CFrame.new(tail + Vector3.new(3, 0, side * 4.5)) * CFrame.Angles(0, side > 0 and 0 or math.pi, 0), color = BONE, material = Enum.Material.Limestone })
	end
	-- teal glow pooled under the ribcage
	for _, x in ipairs({ -18, 6 }) do
		local orb = Kit.ball(m, { name = "Biolume", diameter = 1.6, cf = CFrame.new(x, 0.5, zc + 2), color = GLOW, material = Enum.Material.Neon, collide = false })
		Kit.light(orb, GLOW, 26, 1.4)
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
	local laneHalf = ctx.pathWidth / 2

	local function nearNest(x, z, pad)
		return (Vector3.new(x, 0, z) - Vector3.new(nest.X, 0, nest.Z)).Magnitude < clearR + (pad or 0)
	end

	-- seabed: dark sand slab, slate plates and silt ripples on top
	Kit.part(f, { name = "Seabed", size = Vector3.new(W, 4, L), cf = CFrame.new(0, -2, zm), color = SEABED, material = Enum.Material.Sand })
	for i = 1, 16 do
		local x = rng(-62, 62)
		local z = rng(z0 + 6, z1 - 6)
		Kit.part(f, {
			name = "SlatePlate",
			size = Vector3.new(rng(10, 24), 0.3, rng(8, 18)),
			cf = CFrame.new(x, 0.05, z) * CFrame.Angles(0, rng(0, math.pi), 0),
			color = (i % 2 == 0) and SEABED_DARK or Kit.shade(SEABED_DARK, 1.12),
			material = Enum.Material.Slate,
		})
	end
	for i = 1, 12 do
		local side = (i % 2 == 0) and 1 or -1
		Kit.part(f, {
			name = "SiltRipple",
			size = Vector3.new(rng(14, 26), 0.35, 1.2),
			cf = CFrame.new(side * rng(24, 58), 0.1, rng(z0 + 10, z1 - 10)) * CFrame.Angles(0, rng(-0.3, 0.3), 0),
			color = SAND_RIPPLE,
			material = Enum.Material.Sand,
		})
	end

	-- the trench lane: darker gravel with glowing markers leading to the nest
	local laneEnd = nest.Z - (ctx.nestRadius + 8)
	Kit.part(f, { name = "TrenchLane", size = Vector3.new(ctx.pathWidth - 2, 0.3, laneEnd - z0), cf = CFrame.new(0, 0.1, (z0 + laneEnd) / 2), color = TRENCH_LANE, material = Enum.Material.Pebble })
	for z = z0 + 14, laneEnd - 6, 22 do
		for side = -1, 1, 2 do
			local dot = Kit.cylinder(f, { name = "LaneGlow", height = 0.2, diameter = 1.1, cf = CFrame.new(side * (laneHalf - 0.5), 0.3, z), color = GLOW, material = Enum.Material.Neon, collide = false })
			dot.CastShadow = false
		end
	end

	-- trench walls: towering slate slabs leaning in from both sides
	for side = -1, 1, 2 do
		for i = 0, 9 do
			local z = z0 + 13 + i * 26 + rng(-3, 3)
			local h = rng(22, 42)
			Kit.part(f, {
				name = "TrenchWall",
				size = Vector3.new(rng(10, 15), h, rng(24, 32)),
				cf = CFrame.new(side * 71, h / 2 - 2, z) * CFrame.Angles(rng(-0.06, 0.06), rng(-0.15, 0.15), side * rng(0.05, 0.14)),
				color = (i % 2 == 0) and ROCK or ROCK_LIGHT,
				material = Enum.Material.Slate,
			})
			Kit.ball(f, { name = "Boulder", diameter = rng(5, 9), cf = CFrame.new(side * rng(60, 64), 0.5, z + rng(-8, 8)), color = ROCK, material = Enum.Material.Slate })
			if i % 3 == 1 then
				-- glowing polyps clinging to the wall face
				local polyp = Kit.ball(f, { name = "Polyp", diameter = 0.9, cf = CFrame.new(side * 64.2, rng(4, 12), z + rng(-6, 6)), color = { 120, 255, 220 }, material = Enum.Material.Neon, collide = false })
				Kit.ball(f, { name = "Polyp", diameter = 0.6, cf = polyp.CFrame * CFrame.new(0, 1.3, 0.8), color = { 120, 255, 220 }, material = Enum.Material.Neon, collide = false })
			end
		end
	end

	-- coral gardens along both sides of the lane
	local coralSpots = {
		{ -30, 22 }, { 34, 30 }, { -46, 58 }, { 28, 76 }, { -26, 104 }, { 48, 112 },
		{ -54, 140 }, { 58, 160 }, { -60, 196 }, { 56, 212 }, { -36, 248 }, { 40, 250 },
	}
	for i, s in ipairs(coralSpots) do
		local x, z = s[1], z0 + s[2]
		if not nearNest(x, z, 6) then
			coral(ctx, f, Vector3.new(x, 0, z), 1 + rng(0, 0.6), CORAL[(i - 1) % #CORAL + 1], i % 2 == 1)
			if i % 3 == 0 then
				sponges(ctx, f, Vector3.new(x + rng(4, 7), 0, z + rng(-4, 4)), CORAL[i % #CORAL + 1])
			end
		end
	end
	local fanSpots = { { -20, 44 }, { 22, 54 }, { 38, 96 }, { -40, 86 }, { 20, 120 }, { -64, 168 }, { 66, 186 } }
	for i, s in ipairs(fanSpots) do
		if not nearNest(s[1], z0 + s[2], 4) then
			seaFan(ctx, f, Vector3.new(s[1], 0, z0 + s[2]), 0.9 + rng(0, 0.4), (i % 2 == 0) and { 200, 80, 170 } or { 255, 120, 90 }, rng(-0.5, 0.5))
		end
	end

	-- giant kelp forests in the back corners of each bank
	local kelpSpots = { { -58, 34 }, { 60, 50 }, { -36, 128 }, { 40, 138 }, { -62, 226 }, { 64, 236 } }
	for _, s in ipairs(kelpSpots) do
		for k = 1, 3 do
			local x = s[1] + rng(-6, 6)
			local z = z0 + s[2] + rng(-6, 6)
			if not nearNest(x, z) then
				kelp(ctx, f, Vector3.new(x, 0, z), rng(18, 34))
			end
		end
	end

	-- clams scattered in the silt (pearls glow)
	local clamSpots = { { -22, 30 }, { 20, 66 }, { -34, 118 }, { 30, 98 }, { -20, 154 }, { 64, 120 } }
	for i, s in ipairs(clamSpots) do
		if not nearNest(s[1], z0 + s[2], 2) then
			clam(ctx, f, Vector3.new(s[1], 0, z0 + s[2]), rng(-0.6, 0.6) + ((s[1] > 0) and math.pi / 2 or -math.pi / 2), i % 2 == 1)
		end
	end

	-- shipwreck: a broken hull on the left bank, the stern on the right
	hullSection(ctx, f, CFrame.new(-44, 7, z0 + 78) * CFrame.Angles(0, 0.35, -0.42), 28)
	Kit.cylinder(f, { name = "BrokenMast", height = 34, diameter = 1.6, cf = CFrame.new(-34, 2.5, z0 + 104) * CFrame.Angles(0, 0.9, 0) * CFrame.Angles(0, 0, math.pi / 2 - 0.12), color = WOOD_DARK, material = Enum.Material.Wood })
	Kit.part(f, { name = "Sail", size = Vector3.new(0.2, 9, 14), cf = CFrame.new(-36, 2.2, z0 + 112) * CFrame.Angles(0.3, 0.9, 1.3), color = { 150, 150, 135 }, material = Enum.Material.Fabric, collide = false })
	hullSection(ctx, f, CFrame.new(50, 6.5, z0 + 40) * CFrame.Angles(0, -0.6, 0.5), 20)
	for i = 1, 3 do
		local bp = Vector3.new(36 + i * 3.4, 0, z0 + 58 + i * 2)
		if i == 2 then
			Kit.part(f, { name = "Barrel", shape = "Cylinder", size = Vector3.new(3, 2.4, 2.4), cf = CFrame.new(bp + Vector3.new(0, 1.2, 1)) * CFrame.Angles(0, 0.7, 0), color = WOOD, material = Enum.Material.WoodPlanks })
		else
			Kit.cylinder(f, { name = "Barrel", height = 3, diameter = 2.4, cf = CFrame.new(bp + Vector3.new(0, 1.5, 0)), color = WOOD, material = Enum.Material.WoodPlanks })
		end
	end
	-- the anchor, half-buried
	Kit.part(f, { name = "AnchorShank", size = Vector3.new(1, 10, 1), cf = CFrame.new(40, 4, z0 + 124) * CFrame.Angles(0, 0.4, 0.35), color = { 70, 80, 90 }, material = Enum.Material.CorrodedMetal })
	Kit.part(f, { name = "AnchorArm", size = Vector3.new(7, 1, 1), cf = CFrame.new(38.6, 0.4, z0 + 124.6) * CFrame.Angles(0, 0.4, -0.2), color = { 70, 80, 90 }, material = Enum.Material.CorrodedMetal })
	Kit.cylinder(f, { name = "AnchorRing", height = 0.6, diameter = 2.4, cf = CFrame.new(43.3, 8.4, z0 + 122.6) * CFrame.Angles(math.pi / 2, 0.4, 0), color = { 70, 80, 90 }, material = Enum.Material.CorrodedMetal })

	-- hydrothermal vents: short chimneys breathing bubbles
	for _, s in ipairs({ { -24, 70 }, { 24, 18 }, { 52, 196 }, { -50, 214 } }) do
		local x, z = s[1], z0 + s[2]
		if not nearNest(x, z, 2) then
			Kit.cylinder(f, { name = "Vent", height = 4, diameter = 3.2, cf = CFrame.new(x, 2, z), color = { 28, 30, 36 }, material = Enum.Material.Basalt })
			local mouth = Kit.cylinder(f, { name = "VentMouth", height = 0.3, diameter = 2, cf = CFrame.new(x, 4.05, z), color = { 60, 200, 230 }, material = Enum.Material.Neon, collide = false })
			Kit.particles(mouth, { color = { 190, 235, 255 }, size = 0.5, sizeEnd = 0.9, rate = 5, lifetime = 5, speed = 3, spread = 10, accel = Vector3.new(0, 3, 0), transparency = 0.35 })
		end
	end

	-- hero: the whale skeleton behind the nest
	whaleSkeleton(ctx, f, z1 - 16)

	-- water ceiling far overhead, with faint light shafts
	Kit.part(f, { name = "WaterCeiling", size = Vector3.new(W + 10, 1, L), cf = CFrame.new(0, 82, zm), color = { 40, 110, 170 }, material = Enum.Material.Glass, transparency = 0.55, collide = false, castShadow = false })
	Kit.part(f, { name = "WaterSurface", size = Vector3.new(W + 10, 0.4, L), cf = CFrame.new(0, 79, zm), color = { 70, 170, 230 }, material = Enum.Material.ForceField, transparency = 0.3, collide = false, castShadow = false })
	for i = 0, 5 do
		local x = -50 + i * 20 + rng(-4, 4)
		local z = z0 + 24 + i * 38
		Kit.part(f, {
			name = "LightShaft",
			size = Vector3.new(4 + rng(0, 3), 76, 4 + rng(0, 3)),
			cf = CFrame.new(x, 40, z) * CFrame.Angles(0.18, 0, 0.12),
			color = { 130, 210, 255 },
			material = Enum.Material.SmoothPlastic,
			transparency = 0.9,
			collide = false,
			castShadow = false,
		})
	end
	-- drifting plankton motes
	local motes = Kit.part(f, { name = "Plankton", size = Vector3.new(W - 20, 30, L - 20), cf = CFrame.new(0, 30, zm), transparency = 1, collide = false, castShadow = false })
	motes.CanQuery = false
	Kit.particles(motes, { color = { 150, 230, 255 }, size = 0.25, sizeEnd = 0.1, rate = 18, lifetime = 8, speed = 0.4, accel = Vector3.new(0, 0.3, 0), emission = 1, transparency = 0.3 })

	return {
		palette = {
			accent = GLOW,
			gate = { 70, 92, 104 },
			gateMaterial = Enum.Material.CorrodedMetal,
			nest = { 48, 64, 86 },
			nestMaterial = Enum.Material.Slate,
		},
	}
end
