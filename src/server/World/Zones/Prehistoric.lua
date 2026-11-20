--[[
	Zone 7 — Prehistoric. A steaming jungle that time forgot: mud trails
	through fern-choked clearings, umbrella-crowned conifers, stubby cycads,
	bubbling tar pits and layered stone ridges. The route runs straight under
	the bleached arch of a sauropod skeleton, and a smoking volcano looms in
	the back corner behind the nest.

	Zone builder contract (see docs/ZONE_CONTRACT.md):
	  build(ctx) -> { palette = { accent, gate, gateMaterial, nest, nestMaterial } }
	  ctx: folder, index, zone, z0, z1, length, width, pathWidth, nest (Vector3),
	       nestRadius, rng(a,b), Kit, tree(parent, pos, scale, leafColor)
]]

local SOIL = { 104, 94, 58 }
local GRASS = { 92, 128, 54 }
local GRASS_DARK = { 74, 108, 46 }
local MUD = { 96, 72, 50 }
local MUD_DARK = { 70, 52, 38 }
local STRATA = { { 150, 118, 84 }, { 126, 100, 74 }, { 168, 138, 98 } }
local BONE = { 232, 222, 196 }
local BONE_OLD = { 206, 190, 152 }
local BARK = { 96, 70, 48 }
local FROND = { { 70, 132, 52 }, { 88, 148, 58 }, { 60, 112, 50 } }
local NEEDLES = { 46, 92, 50 }
local TAR = { 14, 12, 12 }
local LAVA = { 255, 120, 30 }
local AMBER = { 255, 170, 40 }

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

-- Giant fern: a leafy heart with long fronds arching out low to the ground.
local function fern(ctx, parent, pos, scale)
	local Kit, rng = ctx.Kit, ctx.rng
	local color = FROND[math.floor(rng(1, #FROND + 0.99))]
	Kit.ball(parent, { name = "FernHeart", diameter = 2.4 * scale, cf = CFrame.new(pos + Vector3.new(0, 0.8 * scale, 0)), color = Kit.shade(color, 0.8), material = Enum.Material.LeafyGrass, collide = false })
	local n = 6
	local spin = rng(0, math.pi)
	for i = 1, n do
		local a = spin + i / n * math.pi * 2
		local len = (8 + rng(0, 3)) * scale
		Kit.part(parent, {
			name = "Frond",
			size = Vector3.new(2.4 * scale, 0.3, len),
			cf = CFrame.new(pos + Vector3.new(0, 1.2 * scale, 0)) * CFrame.Angles(0, a, 0) * CFrame.Angles(0.45 + rng(-0.1, 0.15), 0, 0) * CFrame.new(0, 0, -len / 2),
			color = (i % 2 == 0) and color or Kit.shade(color, 1.12),
			material = Enum.Material.LeafyGrass,
			collide = false,
		})
	end
end

-- Cycad: a scaly pineapple trunk with a crown of stiff fronds and a seed cone.
local function cycad(ctx, parent, pos, scale)
	local Kit, rng = ctx.Kit, ctx.rng
	local m = Kit.model(parent, "Cycad")
	local h = 0
	for i = 1, 3 do
		local seg = 1.8 * scale
		Kit.cylinder(m, { name = "CycadTrunk", height = seg, diameter = (3.4 - i * 0.35) * scale, cf = CFrame.new(pos + Vector3.new(0, h + seg / 2, 0)), color = (i % 2 == 0) and BARK or Kit.shade(BARK, 1.2), material = Enum.Material.Wood })
		h = h + seg
	end
	local top = pos + Vector3.new(0, h, 0)
	Kit.ball(m, { name = "SeedCone", diameter = 1.8 * scale, cf = CFrame.new(top + Vector3.new(0, 0.6 * scale, 0)), color = { 220, 130, 50 }, material = Enum.Material.Pebble })
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + rng(0, 0.4)
		local len = 6.5 * scale
		Kit.part(m, {
			name = "CycadFrond",
			size = Vector3.new(1.4 * scale, 0.25, len),
			cf = CFrame.new(top) * CFrame.Angles(0, a, 0) * CFrame.Angles(0.55, 0, 0) * CFrame.new(0, 0, -len / 2),
			color = (i % 2 == 0) and { 64, 116, 48 } or { 80, 134, 54 },
			material = Enum.Material.Grass,
			collide = false,
		})
	end
	return m
end

-- Ancient conifer: tall bare trunk, buttress roots, umbrella tiers of needles.
local function bigTree(ctx, parent, pos, scale)
	local Kit, rng = ctx.Kit, ctx.rng
	local m = Kit.model(parent, "AncientConifer")
	local h = 34 * scale
	Kit.cylinder(m, { name = "Trunk", height = h, diameter = 3.4 * scale, cf = CFrame.new(pos + Vector3.new(0, h / 2, 0)), color = BARK, material = Enum.Material.Wood })
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + rng(0, 1)
		Kit.part(m, {
			name = "Buttress",
			shape = "Wedge",
			size = Vector3.new(1.2 * scale, 6 * scale, 4 * scale),
			cf = CFrame.new(pos) * CFrame.Angles(0, a, 0) * CFrame.new(0, 3 * scale, -(1.6 + 2) * scale) * CFrame.Angles(0, math.pi, 0),
			color = Kit.shade(BARK, 0.9),
			material = Enum.Material.Wood,
		})
	end
	-- umbrella crown: stacked shallow discs, widest at the bottom
	for i = 0, 2 do
		local d = (22 - i * 6) * scale
		Kit.cylinder(m, {
			name = "Canopy",
			height = 2.4 * scale,
			diameter = d,
			cf = CFrame.new(pos + Vector3.new(rng(-0.5, 0.5), h - 4 * scale + i * 3.2 * scale, rng(-0.5, 0.5))),
			color = (i % 2 == 0) and NEEDLES or Kit.shade(NEEDLES, 1.18),
			material = Enum.Material.LeafyGrass,
			collide = false,
		})
	end
	-- a couple of bare branches under the crown
	for _, s in ipairs({ -1, 1 }) do
		local from = pos + Vector3.new(0, h - 9 * scale, 0)
		limb(Kit, m, from, from + Vector3.new(s * 6 * scale, 4 * scale, s * 2 * scale), 0.9 * scale, { name = "Branch", color = BARK, material = Enum.Material.Wood, collide = false })
	end
	return m
end

-- Tar pit: a glossy black pool flush with the mud, bubbles and a doomed bone.
local function tarPit(ctx, parent, pos, d)
	local Kit, rng = ctx.Kit, ctx.rng
	Kit.cylinder(parent, { name = "TarRim", height = 0.3, diameter = d + 5, cf = CFrame.new(pos + Vector3.new(0, 0, 0)), color = MUD_DARK, material = Enum.Material.Mud })
	Kit.cylinder(parent, { name = "TarPit", height = 0.2, diameter = d, cf = CFrame.new(pos + Vector3.new(0, 0.1, 0)), color = TAR, material = Enum.Material.SmoothPlastic, reflectance = 0.35, collide = false })
	for i = 1, 3 do
		local a = rng(0, math.pi * 2)
		local r = rng(0, d * 0.32)
		Kit.ball(parent, { name = "TarBubble", diameter = rng(0.8, 1.8), cf = CFrame.new(pos + Vector3.new(math.cos(a) * r, 0.1, math.sin(a) * r)), color = { 24, 20, 20 }, material = Enum.Material.SmoothPlastic, reflectance = 0.4, collide = false })
	end
	-- a sinking femur and a tusk sticking out of the tar
	Kit.cylinder(parent, { name = "SinkingBone", height = 6, diameter = 0.9, cf = CFrame.new(pos + Vector3.new(d * 0.18, 1.6, -d * 0.12)) * CFrame.Angles(0.5, 0, 0.6), color = BONE_OLD, material = Enum.Material.Limestone, collide = false })
	Kit.ball(parent, { name = "BoneKnob", diameter = 1.5, cf = CFrame.new(pos + Vector3.new(d * 0.18 - 1.7, 4.1, -d * 0.12 - 1.4)), color = BONE_OLD, material = Enum.Material.Limestone, collide = false })
	local fume = Kit.part(parent, { name = "TarFume", size = Vector3.new(d * 0.6, 0.2, d * 0.6), cf = CFrame.new(pos + Vector3.new(0, 0.3, 0)), transparency = 1, collide = false, castShadow = false })
	fume.CanQuery = false
	Kit.particles(fume, { color = { 60, 55, 50 }, size = 1.2, sizeEnd = 3, rate = 2, lifetime = 4, speed = 1.5, spread = 15, accel = Vector3.new(0, 1, 0), emission = 0, transparency = 0.6 })
end

-- Layered rock ridge segment: stacked strata blocks, slightly offset.
local function ridge(ctx, parent, pos, w, d, side)
	local Kit, rng = ctx.Kit, ctx.rng
	local y = 0
	for i = 1, 3 do
		local h = rng(4, 7) * (1.2 - i * 0.15)
		local shrink = (i - 1) * 2.2
		Kit.part(parent, {
			name = "Strata",
			size = Vector3.new(w - shrink, h, d - shrink * 1.5),
			cf = CFrame.new(pos + Vector3.new(side * shrink * 0.6, y + h / 2, rng(-1, 1))) * CFrame.Angles(0, rng(-0.06, 0.06), side * 0.04),
			color = STRATA[(i - 1) % #STRATA + 1],
			material = Enum.Material.Sandstone,
		})
		y = y + h
	end
end

-- The sauropod skeleton: body spanning the route (legs either side of the
-- corridor), long neck rearing up over the left bank, tail sweeping down right.
local function sauropod(ctx, parent, zA)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "SauropodArch")
	local function bone(a, b, d, name)
		-- only bones well outside the corridor collide
		local solid = math.min(math.abs(a.X), math.abs(b.X)) > 17 and math.min(a.Y, b.Y) < 30
		return limb(Kit, m, a, b, d, { name = name, color = BONE, material = Enum.Material.Limestone, collide = solid })
	end
	local spine = {
		Vector3.new(-60, 64, zA), Vector3.new(-54, 61, zA), Vector3.new(-46, 55, zA), Vector3.new(-38, 47, zA),
		Vector3.new(-30, 37, zA), Vector3.new(-21, 28, zA), Vector3.new(-10, 28.5, zA), Vector3.new(0, 29, zA),
		Vector3.new(10, 28, zA), Vector3.new(20, 26, zA), Vector3.new(31, 22, zA), Vector3.new(42, 17, zA),
		Vector3.new(52, 11, zA), Vector3.new(61, 6, zA), Vector3.new(70, 2.4, zA),
	}
	for i = 1, #spine - 1 do
		local d = (i <= 5) and (1.5 + i * 0.25) or math.max(0.9, 3 - (i - 6) * 0.25)
		bone(spine[i], spine[i + 1], d, "Spine")
		if i >= 2 and i <= 12 then
			Kit.part(m, { name = "Vertebra", shape = "Cylinder", size = Vector3.new(1.2, d * 1.8, d * 1.8), cf = CFrame.lookAt(spine[i], spine[i + 1]) * CFrame.Angles(0, math.pi / 2, 0), color = BONE_OLD, material = Enum.Material.Limestone, collide = false })
			Kit.part(m, { name = "NeuralSpike", size = Vector3.new(0.8, d * 1.6, 1.2), cf = CFrame.new(spine[i] + Vector3.new(0, d * 1.1, 0)), color = BONE, material = Enum.Material.Limestone, collide = false })
		end
	end
	-- skull and jaw
	local head = spine[1]
	Kit.part(m, { name = "Skull", size = Vector3.new(6, 3.6, 3.4), cf = CFrame.new(head + Vector3.new(-3.4, 0.4, 0)) * CFrame.Angles(0, 0, -0.25), color = BONE, material = Enum.Material.Limestone, collide = false })
	Kit.part(m, { name = "Jaw", size = Vector3.new(5, 1, 2.8), cf = CFrame.new(head + Vector3.new(-3.8, -1.8, 0)) * CFrame.Angles(0, 0, -0.45), color = BONE_OLD, material = Enum.Material.Limestone, collide = false })
	Kit.ball(m, { name = "EyeSocket", diameter = 1.3, cf = CFrame.new(head + Vector3.new(-3, 1, -1.5)), color = { 30, 26, 22 }, material = Enum.Material.SmoothPlastic, collide = false })
	-- ribs hanging from the back, high above the route
	for i = 0, 8 do
		local x = -16 + i * 4
		local top = Vector3.new(x, 28.6 - math.abs(x) * 0.06, zA)
		local drop = 12 - math.abs(x) * 0.25
		for _, s in ipairs({ -1, 1 }) do
			local mid = top + Vector3.new(0.4, -drop * 0.45, s * 6.5)
			local tip = top + Vector3.new(1, -drop, s * 4.5)
			limb(Kit, m, top, mid, 0.8, { name = "Rib", color = BONE, material = Enum.Material.Limestone, collide = false })
			limb(Kit, m, mid, tip, 0.7, { name = "Rib", color = BONE, material = Enum.Material.Limestone, collide = false })
		end
	end
	-- shoulder blades and pelvis
	for _, s in ipairs({ -1, 1 }) do
		Kit.part(m, { name = "Scapula", size = Vector3.new(7, 4, 0.8), cf = CFrame.new(-20, 23, zA + s * 4.4) * CFrame.Angles(0, 0, 0.9), color = BONE_OLD, material = Enum.Material.Limestone, collide = false })
		Kit.part(m, { name = "Pelvis", size = Vector3.new(8, 5, 0.9), cf = CFrame.new(20, 22.5, zA + s * 4.4) * CFrame.Angles(0, 0, -0.4), color = BONE_OLD, material = Enum.Material.Limestone, collide = false })
	end
	-- four pillar legs, safely outside the corridor
	for _, leg in ipairs({ { x = -21, knee = -1.2 }, { x = 21, knee = 1.6 } }) do
		for _, s in ipairs({ -1, 1 }) do
			local hip = Vector3.new(leg.x, 22, zA + s * 5)
			local knee = Vector3.new(leg.x + leg.knee, 11, zA + s * 5.6)
			local foot = Vector3.new(leg.x, 1.2, zA + s * 6)
			bone(hip, knee, 2.8, "LegBone")
			bone(knee, foot, 2.4, "LegBone")
			Kit.ball(m, { name = "Knee", diameter = 3.4, cf = CFrame.new(knee), color = BONE_OLD, material = Enum.Material.Limestone })
			Kit.part(m, { name = "Foot", size = Vector3.new(5, 1.4, 4.6), cf = CFrame.new(foot + Vector3.new(leg.x > 0 and 0.6 or -0.6, -0.5, 0)), color = BONE_OLD, material = Enum.Material.Limestone })
		end
	end
	return m
end

-- Half-buried ribcage of some other giant, lying along Z on the bank.
local function fossilRibcage(ctx, parent, pos)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "FossilRibcage")
	Kit.part(m, { name = "BuriedSpine", shape = "Cylinder", size = Vector3.new(30, 2.2, 2.2), cf = CFrame.new(pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, math.pi / 2, 0), color = BONE_OLD, material = Enum.Material.Limestone })
	for i = 0, 5 do
		local z = pos.Z - 11 + i * 4.4
		local h = 13 - math.abs(i - 2.5) * 2
		for _, s in ipairs({ -1, 1 }) do
			local a = Vector3.new(pos.X, 1, z)
			local b = Vector3.new(pos.X + s * 5.5, h * 0.7, z + 0.6)
			local c = Vector3.new(pos.X + s * 6.5, h, z + 1.4)
			local d = Vector3.new(pos.X + s * 4.2, h + 3, z + 2)
			limb(Kit, m, a, b, 1.1, { name = "Rib", color = BONE, material = Enum.Material.Limestone })
			limb(Kit, m, b, c, 1.0, { name = "Rib", color = BONE, material = Enum.Material.Limestone })
			limb(Kit, m, c, d, 0.8, { name = "Rib", color = BONE, material = Enum.Material.Limestone })
		end
	end
	-- the skull, nose-down in the dirt
	Kit.part(m, { name = "Skull", size = Vector3.new(6, 5, 9), cf = CFrame.new(pos + Vector3.new(0, 1.6, -18)) * CFrame.Angles(-0.35, 0.2, 0), color = BONE_OLD, material = Enum.Material.Limestone })
	Kit.part(m, { name = "Horn", shape = "Wedge", size = Vector3.new(1.2, 4.5, 2.4), cf = CFrame.new(pos + Vector3.new(0, 5.6, -19)) * CFrame.Angles(0, math.pi, 0), color = BONE, material = Enum.Material.Limestone })
	return m
end

-- The smoking volcano: stacked basalt tiers, a molten crater and lava runs.
local function volcano(ctx, parent, pos)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "Volcano")
	local tiers = 11
	local tierH = 5
	for i = 0, tiers - 1 do
		local t = i / (tiers - 1)
		local d = 38 - t * 26
		Kit.cylinder(m, {
			name = "VolcanoTier",
			height = tierH + 0.4,
			diameter = d,
			cf = CFrame.new(pos + Vector3.new(t * -2, i * tierH + tierH / 2, t * 1.5)),
			color = Kit.mix({ 92, 78, 66 }, { 54, 46, 44 }, t),
			material = (i % 2 == 0) and Enum.Material.Rock or Enum.Material.Basalt,
		})
	end
	local topY = tiers * tierH
	local top = pos + Vector3.new(-2, topY, 1.5)
	local crater = Kit.cylinder(m, { name = "Crater", height = 0.6, diameter = 9, cf = CFrame.new(top + Vector3.new(0, 0.1, 0)), color = LAVA, material = Enum.Material.Neon, collide = false })
	Kit.light(crater, LAVA, 40, 2)
	Kit.particles(crater, { color = { 90, 84, 80 }, color2 = { 160, 150, 140 }, size = 6, sizeEnd = 16, rate = 6, lifetime = 9, speed = 8, spread = 18, accel = Vector3.new(-1.5, 2, 0), emission = 0, transparency = 0.35 })
	-- frozen smoke plume drifting over the jungle
	for i = 1, 5 do
		Kit.ball(m, { name = "SmokePlume", diameter = 9 + i * 3, cf = CFrame.new(top + Vector3.new(-i * 4, 4 + i * 8, -i * 1.5)), color = Kit.mix({ 120, 112, 104 }, { 175, 168, 158 }, i / 5), material = Enum.Material.SmoothPlastic, transparency = 0.25 + i * 0.08, collide = false, castShadow = false })
	end
	-- lava runs down the face toward the route
	for k, ang in ipairs({ -0.5, 0.15, 0.8 }) do
		local dir = Vector3.new(-math.sin(ang), 0, -math.cos(ang))
		local a = top + dir * 5 + Vector3.new(0, -0.5, 0)
		local b = pos + dir * (17 - k) + Vector3.new(0, 2 + k * 2, 0)
		local len = (b - a).Magnitude
		Kit.part(m, { name = "LavaRun", size = Vector3.new(1.4, 0.6, len), cf = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, 0.6, 0), color = LAVA, material = Enum.Material.Neon, collide = false })
	end
	return m
end

-- Pteranodon silhouette gliding overhead.
local function pteranodon(ctx, parent, pos, yaw)
	local Kit = ctx.Kit
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local c = { 120, 84, 70 }
	Kit.part(parent, { name = "PteroBody", size = Vector3.new(1.4, 1.2, 5), cf = base, color = c, material = Enum.Material.SmoothPlastic, collide = false })
	Kit.part(parent, { name = "PteroCrest", shape = "Wedge", size = Vector3.new(0.4, 2, 4), cf = base * CFrame.new(0, 1, -3.2) * CFrame.Angles(0, math.pi, 0), color = Kit.shade(c, 0.8), material = Enum.Material.SmoothPlastic, collide = false })
	for _, s in ipairs({ -1, 1 }) do
		Kit.part(parent, { name = "PteroWing", size = Vector3.new(9, 0.2, 3.4), cf = base * CFrame.new(s * 5, 0.6, 0.3) * CFrame.Angles(0, s * 0.25, s * 0.18), color = Kit.shade(c, 1.15), material = Enum.Material.Fabric, collide = false })
	end
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

	-- ground: packed soil, lush grass patches, mud wallows
	Kit.part(f, { name = "Soil", size = Vector3.new(W, 4, L), cf = CFrame.new(0, -2, zm), color = SOIL, material = Enum.Material.Ground })
	for i = 1, 18 do
		local side = (i % 2 == 0) and 1 or -1
		Kit.part(f, {
			name = "GrassPatch",
			size = Vector3.new(rng(18, 34), 0.3, rng(18, 34)),
			cf = CFrame.new(side * rng(26, 58), 0.05, z0 + (i - 0.5) * L / 18 + rng(-4, 4)) * CFrame.Angles(0, rng(0, math.pi), 0),
			color = (i % 3 == 0) and GRASS_DARK or GRASS,
			material = Enum.Material.Grass,
		})
	end
	for i = 1, 5 do
		local side = (i % 2 == 0) and 1 or -1
		Kit.cylinder(f, { name = "MudWallow", height = 0.3, diameter = rng(10, 16), cf = CFrame.new(side * rng(24, 40), 0.08, z0 + i * 40 + rng(-6, 6)), color = MUD, material = Enum.Material.Mud })
	end

	-- the trail: a slightly wandering mud path toward the nest
	local trailEnd = nest.Z - (ctx.nestRadius + 6)
	local segLen = 20
	local nSeg = math.floor((trailEnd - z0) / segLen)
	for i = 0, nSeg - 1 do
		local z = z0 + segLen * (i + 0.5)
		local x = math.sin(i * 0.9) * 2.5
		Kit.part(f, { name = "Trail", size = Vector3.new(ctx.pathWidth - 6 + (i % 2) * 2, 0.35, segLen + 3), cf = CFrame.new(x, 0.1, z) * CFrame.Angles(0, math.sin(i * 1.7) * 0.06, 0), color = (i % 2 == 0) and MUD or Kit.shade(MUD, 1.08), material = Enum.Material.Mud })
	end
	-- three-toed footprints along the trail
	for i = 0, 6 do
		local z = z0 + 18 + i * 15
		local x = ((i % 2 == 0) and -4 or 4) + math.sin(i) * 1.5
		for k = -1, 1 do
			Kit.part(f, { name = "Footprint", size = Vector3.new(0.9, 0.38, 2.6), cf = CFrame.new(x + k * 0.9, 0.11, z) * CFrame.Angles(0, k * 0.45, 0), color = MUD_DARK, material = Enum.Material.Mud, collide = false })
		end
	end

	-- stone ridges along both walls
	for side = -1, 1, 2 do
		for i = 0, 8 do
			local z = z0 + 14 + i * 29 + rng(-4, 4)
			ridge(ctx, f, Vector3.new(side * rng(66, 70), 0, z), rng(12, 18), rng(20, 28), side)
		end
	end

	-- ancient conifers framing the route
	for _, s in ipairs({ { -54, 26 }, { 58, 18 }, { -60, 120 }, { 52, 92 }, { -62, 222 }, { -38, 150 } }) do
		if not nearNest(s[1], z0 + s[2], 10) then
			bigTree(ctx, f, Vector3.new(s[1], 0, z0 + s[2]), 1 + rng(-0.1, 0.25))
		end
	end

	-- fern thickets and cycads, dense near the walls, thinning toward the trail
	local fernSpots = {
		{ -24, 14 }, { 26, 36 }, { -32, 48 }, { 22, 66 }, { -44, 72 }, { 38, 70 }, { -26, 110 }, { 30, 118 },
		{ -50, 96 }, { 46, 134 }, { -56, 166 }, { 60, 160 }, { -50, 246 }, { 30, 246 }, { 64, 104 }, { -20, 248 },
	}
	for _, s in ipairs(fernSpots) do
		if not nearNest(s[1], z0 + s[2], 4) then
			fern(ctx, f, Vector3.new(s[1] + rng(-2, 2), 0, z0 + s[2] + rng(-2, 2)), 0.9 + rng(0, 0.6))
		end
	end
	for _, s in ipairs({ { 34, 22 }, { -36, 30 }, { 28, 100 }, { -30, 126 }, { 60, 196 }, { -60, 196 } }) do
		if not nearNest(s[1], z0 + s[2], 4) then
			cycad(ctx, f, Vector3.new(s[1], 0, z0 + s[2]), 1 + rng(0, 0.5))
		end
	end

	-- tar pits on the banks, well away from the trail and the nest
	tarPit(ctx, f, Vector3.new(40, 0.02, z0 + 48), 16)
	tarPit(ctx, f, Vector3.new(-42, 0.02, z0 + 136), 14)
	tarPit(ctx, f, Vector3.new(58, 0.02, z0 + 236), 12)

	-- fossils: a half-buried ribcage and scattered bones
	fossilRibcage(ctx, f, Vector3.new(-46, 0, z0 + 52))
	for i = 1, 6 do
		local side = (i % 2 == 0) and 1 or -1
		local x, z = side * rng(20, 56), z0 + rng(10, 250)
		if not nearNest(x, z, 2) then
			Kit.cylinder(f, { name = "Bone", height = rng(3, 6), diameter = 0.7, cf = CFrame.new(x, 0.35, z) * CFrame.Angles(math.pi / 2, rng(0, 3), 0), color = BONE_OLD, material = Enum.Material.Limestone, collide = false })
		end
	end

	-- amber nuggets glowing in the ridges (sparingly lit)
	for i, s in ipairs({ { -60, 40 }, { 60, 74 }, { -60, 180 }, { 60, 140 } }) do
		local amber = Kit.part(f, { name = "Amber", size = Vector3.new(1.6, 2.2, 1.6), cf = CFrame.new(s[1], 1.4, z0 + s[2]) * CFrame.Angles(0.3, i, 0.4), color = AMBER, material = Enum.Material.Neon, transparency = 0.1, collide = false })
		Kit.light(amber, AMBER, 14, 0.9)
	end

	-- the sauropod arch over the route, and the volcano behind the nest
	sauropod(ctx, f, z0 + 88)
	volcano(ctx, f, Vector3.new(46, 0, z1 - 17))
	-- a rubble field and fallen boulders at the volcano's foot
	for i = 1, 6 do
		local x, z = rng(18, 70), z1 - rng(4, 30)
		if not nearNest(x, z, 3) then
			Kit.ball(f, { name = "VolcanicBoulder", diameter = rng(3, 6), cf = CFrame.new(x, 0.6, z), color = { 60, 52, 48 }, material = Enum.Material.Basalt })
		end
	end
	-- the far left corner stays jungle: a last pair of conifers and ferns
	bigTree(ctx, f, Vector3.new(-40, 0, z1 - 10), 1.2)
	fern(ctx, f, Vector3.new(-56, 0, z1 - 20), 1.4)

	-- pteranodons riding the thermals
	pteranodon(ctx, f, Vector3.new(-24, 70, z0 + 140), 0.6)
	pteranodon(ctx, f, Vector3.new(14, 82, z0 + 196), -0.9)
	pteranodon(ctx, f, Vector3.new(40, 64, z0 + 60), 2.2)

	-- humid jungle haze drifting through
	local haze = Kit.part(f, { name = "Haze", size = Vector3.new(W - 20, 4, L - 20), cf = CFrame.new(0, 4, zm), transparency = 1, collide = false, castShadow = false })
	haze.CanQuery = false
	Kit.particles(haze, { color = { 255, 240, 200 }, size = 0.2, sizeEnd = 0.05, rate = 10, lifetime = 6, speed = 0.5, accel = Vector3.new(0, 0.2, 0), emission = 0.8, transparency = 0.3 })

	return {
		palette = {
			accent = { 255, 180, 70 },
			gate = { 128, 104, 74 },
			gateMaterial = Enum.Material.Rock,
			nest = { 98, 82, 58 },
			nestMaterial = Enum.Material.Ground,
		},
	}
end
