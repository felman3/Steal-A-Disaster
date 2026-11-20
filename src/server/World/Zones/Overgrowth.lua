--[[
	Zone 2 — Overgrowth. "Nature fights back."
	An ancient stone road swallowed by the forest: a muddy trail over broken
	cobbles, giant spotted mushrooms (some glowing underneath), crumbling ruin
	pillars and an arch reclaimed by moss, vines and roots arching over the
	route, ferns and fireflies everywhere. Behind the nest stands the hero: a
	colossal ancient tree whose two root-legs form a living archway the route
	runs through, with a glowing heart in its trunk.

	Zone builder contract (see docs/ZONE_CONTRACT.md):
	  build(ctx) -> { palette = { accent, gate, gateMaterial, nest, nestMaterial } }
	  ctx: folder, index, zone, z0, z1, length, width, pathWidth, nest (Vector3),
	       nestRadius, rng(a,b), Kit, tree(parent, pos, scale, leafColor)
]]

local LEAF = { 76, 140, 58 }
local LEAF_DARK = { 52, 104, 44 }
local MOSS = { 110, 170, 70 }
local MUD = { 98, 76, 52 }
local MUD_DARK = { 78, 60, 42 }
local STONE = { 128, 132, 116 }
local STONE_DARK = { 98, 104, 92 }
local BARK = { 92, 66, 44 }
local BARK_DARK = { 70, 50, 34 }
local STEM = { 236, 226, 200 }
local GLOW = { 170, 255, 110 }
local FIREFLY = { 230, 255, 140 }
local CAP_COLORS = { { 200, 60, 50 }, { 150, 70, 170 }, { 60, 150, 160 }, { 220, 130, 50 } }
local GILL_GLOWS = { { 120, 255, 200 }, { 190, 120, 255 }, { 170, 255, 110 } }
local GROUND_MATS = { Enum.Material.LeafyGrass, Enum.Material.Grass, Enum.Material.LeafyGrass, Enum.Material.Mud }

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

local function mushroom(ctx, parent, pos, h, capD, colorIdx, glow)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "GiantMushroom")
	local capColor = CAP_COLORS[(colorIdx - 1) % #CAP_COLORS + 1]
	local base = CFrame.new(pos) * CFrame.Angles(rng(-0.08, 0.08), rng(0, 6.28), rng(-0.08, 0.08))
	local stemD = math.max(1.6, capD * 0.17)
	local small = capD < 6
	if not small then
		Kit.ball(m, { name = "StemBulb", diameter = stemD * 1.7, cf = base * CFrame.new(0, stemD * 0.35, 0), color = Kit.shade(STEM, 0.92), material = Enum.Material.Plastic })
	end
	Kit.cylinder(m, { name = "Stem", height = h, diameter = stemD, cf = base * CFrame.new(0, h / 2, 0), color = STEM, material = Enum.Material.Plastic })
	local capH = math.max(1.6, capD * 0.15)
	local gillColor = glow and GILL_GLOWS[(colorIdx - 1) % #GILL_GLOWS + 1] or { 225, 205, 180 }
	local gills = Kit.cylinder(m, { name = "Gills", height = 0.4, diameter = capD * 0.86, cf = base * CFrame.new(0, h - capH / 2 - 0.15, 0), color = gillColor, material = glow and Enum.Material.Neon or Enum.Material.Plastic })
	if glow then
		Kit.light(gills, gillColor, capD * 1.3, 1.1)
	end
	Kit.cylinder(m, { name = "Cap", height = capH, diameter = capD, cf = base * CFrame.new(0, h, 0), color = capColor, material = Enum.Material.SmoothPlastic })
	Kit.cylinder(m, { name = "CapDome", height = capH * 0.8, diameter = capD * 0.72, cf = base * CFrame.new(0, h + capH * 0.85, 0), color = Kit.shade(capColor, 1.06), material = Enum.Material.SmoothPlastic })
	Kit.cylinder(m, { name = "CapTop", height = capH * 0.6, diameter = capD * 0.38, cf = base * CFrame.new(0, h + capH * 1.5, 0), color = Kit.shade(capColor, 1.12), material = Enum.Material.SmoothPlastic })
	for i = 1, small and 0 or 3 do
		local a = i / 3 * math.pi * 2 + rng(-0.4, 0.4)
		local r = capD * 0.42
		Kit.ball(m, { name = "Spot", diameter = capD * 0.13, cf = base * CFrame.new(math.cos(a) * r, h + capH * 0.4, math.sin(a) * r), color = { 250, 245, 230 }, material = Enum.Material.SmoothPlastic, collide = false })
	end
	return m
end

local function ruinPillar(ctx, parent, pos, h, broken)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "RuinPillar")
	Kit.part(m, { name = "Plinth", size = Vector3.new(5.5, 1.6, 5.5), cf = CFrame.new(pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, rng(0, 1.5), 0.04), color = STONE_DARK, material = Enum.Material.Cobblestone })
	Kit.cylinder(m, { name = "Shaft", height = h, diameter = 3.6, cf = CFrame.new(pos + Vector3.new(0, 1.4 + h / 2, 0)), color = STONE, material = Enum.Material.Cobblestone })
	if broken then
		-- the snapped-off drum leans against the base
		Kit.cylinder(m, { name = "Drum", height = 3, diameter = 3.6, cf = CFrame.new(pos + Vector3.new(3.2, 1.6, 1.5)) * CFrame.Angles(0.3, 0, 1.2), color = STONE, material = Enum.Material.Cobblestone })
		Kit.part(m, { name = "Moss", size = Vector3.new(3.8, 0.5, 3.8), cf = CFrame.new(pos + Vector3.new(0, 1.5 + h, 0)) * CFrame.Angles(0.15, 0, -0.12), color = MOSS, material = Enum.Material.LeafyGrass })
	else
		Kit.part(m, { name = "Capital", size = Vector3.new(5, 1.4, 5), cf = CFrame.new(pos + Vector3.new(0, 2.1 + h, 0)), color = STONE_DARK, material = Enum.Material.Cobblestone })
		Kit.part(m, { name = "Moss", size = Vector3.new(5.4, 0.6, 5.4), cf = CFrame.new(pos + Vector3.new(0, 3, 0) + Vector3.new(0, h, 0)), color = MOSS, material = Enum.Material.LeafyGrass })
	end
	-- ivy creeping up the shaft
	rod(Kit, m, pos + Vector3.new(1.7, 0, 0.4), pos + Vector3.new(-0.6, h * 0.8, 1.7), 0.5, { name = "Ivy", color = LEAF_DARK, material = Enum.Material.LeafyGrass, collide = false })
	return m
end

local function fern(ctx, parent, pos, scale)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local col = (rng() < 0.5) and LEAF or MOSS
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + rng(-0.3, 0.3)
		local len = 4.2 * scale
		Kit.part(parent, {
			name = "Frond",
			size = Vector3.new(1.3 * scale, 0.15, len),
			cf = CFrame.new(pos) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.9 * scale, -len / 2 + 0.3) * CFrame.Angles(0.55 + rng(-0.15, 0.15), 0, 0),
			color = Kit.shade(col, rng(0.85, 1.1)),
			material = Enum.Material.Grass,
			collide = false,
		})
	end
end

-- vine or root bowing over the corridor; never collides
local function overArch(ctx, parent, z, span, apex, d, color, material, hangers)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "OverArch")
	local n = 8
	local prev
	local tw = rng(-3, 3)
	for i = 0, n do
		local t = i / n
		local th = math.pi * t
		local p = Vector3.new(math.cos(th) * span, math.sin(th) * apex - 1 + (1 - math.sin(th)) * 0, z + math.sin(th * 2) * tw)
		if prev then
			local seg = rod(Kit, m, prev, p, d * (1 - 0.35 * math.sin(th)), { name = "ArchSeg", color = color, material = material, collide = false })
			seg.CastShadow = true
		end
		prev = p
	end
	-- leaves / hanging strands from the top of the arch
	for i = 1, hangers do
		local x = (i / (hangers + 1) - 0.5) * span * 1.2
		local topY = math.sqrt(math.max(0, 1 - (x / span) ^ 2)) * apex - 1
		local len = rng(3, 6)
		rod(Kit, m, Vector3.new(x, topY, z), Vector3.new(x + rng(-0.4, 0.4), topY - len, z + rng(-0.4, 0.4)), 0.35, { name = "HangingVine", color = LEAF, material = Enum.Material.LeafyGrass, collide = false })
		Kit.ball(m, { name = "Leaves", diameter = rng(1.6, 2.4), cf = CFrame.new(x, topY + 0.4, z), color = Kit.shade(LEAF, rng(0.85, 1.1)), material = Enum.Material.LeafyGrass, collide = false })
	end
	return m
end

local function ruinArch(ctx, parent, z)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "RuinArch")
	for side = -1, 1, 2 do
		local x = side * 17.8
		Kit.part(m, { name = "Plinth", size = Vector3.new(5.6, 1.6, 5.6), cf = CFrame.new(x, 0.6, z), color = STONE_DARK, material = Enum.Material.Cobblestone })
		Kit.part(m, { name = "Pillar", size = Vector3.new(4.2, 13.6, 4.2), cf = CFrame.new(x, 8.2, z) * CFrame.Angles(0, 0, side * 0.015), color = STONE, material = Enum.Material.Cobblestone })
		Kit.part(m, { name = "Capital", size = Vector3.new(5.4, 1.4, 5.4), cf = CFrame.new(x, 15.4, z), color = STONE_DARK, material = Enum.Material.Cobblestone })
		rod(Kit, m, Vector3.new(x - side * 2.2, 0, z - 1.5), Vector3.new(x + side * 0.5, 14, z - 2.3), 0.6, { name = "Ivy", color = LEAF_DARK, material = Enum.Material.LeafyGrass, collide = false })
	end
	Kit.part(m, { name = "Lintel", size = Vector3.new(42, 3.2, 4.6), cf = CFrame.new(0, 17.7, z) * CFrame.Angles(0, 0, 0.02), color = STONE, material = Enum.Material.Cobblestone })
	Kit.part(m, { name = "LintelMoss", size = Vector3.new(36, 0.8, 5), cf = CFrame.new(-2, 19.6, z) * CFrame.Angles(0, 0, 0.03), color = MOSS, material = Enum.Material.LeafyGrass })
	-- glowing rune carved into the face, the forest's mark
	local rune = Kit.part(m, { name = "Rune", size = Vector3.new(5, 1.4, 0.2), cf = CFrame.new(0, 17.7, z - 2.35), color = GLOW, material = Enum.Material.Neon, collide = false })
	Kit.light(rune, GLOW, 16, 0.8)
	for i = 1, 6 do
		local x = -16 + i * 4.6 + ctx.rng(-1, 1)
		rod(Kit, m, Vector3.new(x, 19.3, z - 2.4), Vector3.new(x, 19.3 - ctx.rng(4, 6.5), z - 2.6), 0.35, { name = "HangingVine", color = LEAF, material = Enum.Material.LeafyGrass, collide = false })
	end
	return m
end

local function brokenArch(ctx, parent, z)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "BrokenArch")
	-- left side still stands with a stub of lintel
	Kit.part(m, { name = "Plinth", size = Vector3.new(5.6, 1.6, 5.6), cf = CFrame.new(-17.8, 0.6, z), color = STONE_DARK, material = Enum.Material.Cobblestone })
	Kit.part(m, { name = "Pillar", size = Vector3.new(4.2, 13.6, 4.2), cf = CFrame.new(-17.8, 8.2, z), color = STONE, material = Enum.Material.Cobblestone })
	Kit.part(m, { name = "LintelStub", size = Vector3.new(11, 3.2, 4.6), cf = CFrame.new(-14.5, 16.4, z) * CFrame.Angles(0, 0, -0.12), color = STONE, material = Enum.Material.Cobblestone })
	Kit.part(m, { name = "Moss", size = Vector3.new(9, 0.7, 5), cf = CFrame.new(-15, 18.3, z) * CFrame.Angles(0, 0, -0.12), color = MOSS, material = Enum.Material.LeafyGrass })
	-- right side snapped; the lintel lies in the undergrowth beside the road
	Kit.part(m, { name = "Plinth", size = Vector3.new(5.6, 1.6, 5.6), cf = CFrame.new(17.8, 0.6, z), color = STONE_DARK, material = Enum.Material.Cobblestone })
	Kit.part(m, { name = "PillarStump", size = Vector3.new(4.2, 4.5, 4.2), cf = CFrame.new(17.8, 3.4, z) * CFrame.Angles(0.05, 0, 0.08), color = STONE, material = Enum.Material.Cobblestone })
	Kit.part(m, { name = "FallenLintel", size = Vector3.new(4.6, 3.2, 26), cf = CFrame.new(26, 1.3, z + 6) * CFrame.Angles(0.06, 0.25, 0.1), color = STONE, material = Enum.Material.Cobblestone })
	Kit.part(m, { name = "FallenMoss", size = Vector3.new(5, 0.6, 18), cf = CFrame.new(26.3, 3, z + 7) * CFrame.Angles(0.06, 0.25, 0.1), color = MOSS, material = Enum.Material.LeafyGrass })
	Kit.part(m, { name = "FallenPillar", size = Vector3.new(4.2, 9, 4.2), cf = CFrame.new(31, 2.1, z - 8) * CFrame.Angles(0, 0.6, math.pi / 2), color = STONE, material = Enum.Material.Cobblestone })
	return m
end

local function heroTree(ctx, parent, zt)
	local Kit = ctx.Kit
	local rng = ctx.rng
	local m = Kit.model(parent, "AncientTree")
	-- two root-legs bow inward to carry the trunk over the route
	for side = -1, 1, 2 do
		local pts = {
			Vector3.new(side * 32, -1, zt - 1),
			Vector3.new(side * 26.5, 11, zt),
			Vector3.new(side * 19, 22, zt + 1),
			Vector3.new(side * 9, 31, zt),
		}
		local ds = { 12, 10.5, 9.5 }
		for i = 1, 3 do
			rod(Kit, m, pts[i], pts[i + 1], ds[i], { name = "RootLeg", color = (i == 2) and BARK_DARK or BARK, material = Enum.Material.Wood })
		end
		Kit.ball(m, { name = "Knee", diameter = 10.5, cf = CFrame.new(pts[2]), color = BARK, material = Enum.Material.Wood })
		Kit.ball(m, { name = "Knee", diameter = 9.5, cf = CFrame.new(pts[3]), color = BARK_DARK, material = Enum.Material.Wood })
		-- root flares sprawling over the ground
		rod(Kit, m, Vector3.new(side * 30, 2.5, zt - 2), Vector3.new(side * 47, -0.6, zt - 9), 4.4, { name = "RootFlare", color = BARK, material = Enum.Material.Wood })
		rod(Kit, m, Vector3.new(side * 31, 2.5, zt + 2), Vector3.new(side * 44, -0.6, zt + 13), 4, { name = "RootFlare", color = BARK_DARK, material = Enum.Material.Wood })
		rod(Kit, m, Vector3.new(side * 27, 2.5, zt - 3), Vector3.new(side * 30, -0.6, zt - 17), 3.6, { name = "RootFlare", color = BARK, material = Enum.Material.Wood })
		-- moss on the knees
		Kit.part(m, { name = "Moss", size = Vector3.new(8, 1, 8), cf = CFrame.new(pts[2] + Vector3.new(0, 4.6, 0)) * CFrame.Angles(0, 0, side * 0.4), color = MOSS, material = Enum.Material.LeafyGrass, collide = false })
	end
	-- trunk
	Kit.cylinder(m, { name = "Trunk", height = 40, diameter = 24, cf = CFrame.new(0, 48, zt), color = BARK, material = Enum.Material.Wood })
	Kit.cylinder(m, { name = "TrunkUpper", height = 20, diameter = 17, cf = CFrame.new(0, 76, zt + 1), color = BARK_DARK, material = Enum.Material.Wood })
	Kit.cylinder(m, { name = "TrunkBase", height = 6, diameter = 20, cf = CFrame.new(0, 30, zt), color = BARK_DARK, material = Enum.Material.Wood })
	-- the glowing heart in the bark, visible from the gate
	Kit.ball(m, { name = "Hollow", diameter = 9, cf = CFrame.new(0, 46, zt - 9.6), color = { 40, 30, 22 }, material = Enum.Material.Wood })
	local heart = Kit.ball(m, { name = "Heart", diameter = 5.5, cf = CFrame.new(0, 46, zt - 12.4), color = GLOW, material = Enum.Material.Neon, collide = false })
	Kit.light(heart, GLOW, 45, 2.2)
	Kit.particles(heart, { color = GLOW, color2 = { 255, 255, 200 }, size = 0.5, sizeEnd = 0, rate = 8, lifetime = 2.5, speed = 1.5, emission = 1 })
	-- branches
	local tips = {
		Vector3.new(-32, 86, zt - 4), Vector3.new(32, 86, zt + 3),
		Vector3.new(-14, 96, zt - 8), Vector3.new(16, 98, zt + 6),
	}
	for _, tip in ipairs(tips) do
		rod(Kit, m, Vector3.new(0, 74, zt), tip, 4.5, { name = "Branch", color = BARK, material = Enum.Material.Wood, collide = false })
	end
	-- canopy
	local crowns = {
		{ Vector3.new(0, 100, zt), 36 },
		{ Vector3.new(-32, 90, zt - 4), 28 },
		{ Vector3.new(32, 90, zt + 3), 28 },
		{ Vector3.new(-54, 80, zt + 4), 22 },
		{ Vector3.new(54, 81, zt - 2), 22 },
		{ Vector3.new(-16, 106, zt + 6), 24 },
		{ Vector3.new(18, 107, zt - 6), 24 },
		{ Vector3.new(0, 86, zt - 16), 22 },
		{ Vector3.new(-40, 76, zt - 14), 16 },
		{ Vector3.new(42, 77, zt - 12), 16 },
	}
	for i, c in ipairs(crowns) do
		Kit.ball(m, { name = "Canopy", diameter = c[2], cf = CFrame.new(c[1]), color = Kit.shade((i % 2 == 0) and LEAF or LEAF_DARK, rng(0.9, 1.08)), material = Enum.Material.LeafyGrass, collide = false })
	end
	-- glowing seed pods hanging on long vines from the canopy
	for i = 1, 6 do
		local x = -48 + i * 13.7 + rng(-3, 3)
		local z = zt - 10 + rng(-4, 4)
		local top = 74 + rng(0, 4)
		local bottom = top - rng(10, 18)
		rod(Kit, m, Vector3.new(x, top, z), Vector3.new(x, bottom, z), 0.4, { name = "PodVine", color = LEAF_DARK, material = Enum.Material.LeafyGrass, collide = false })
		local pod = Kit.ball(m, { name = "SeedPod", diameter = 1.8, cf = CFrame.new(x, bottom - 0.8, z), color = GILL_GLOWS[(i % #GILL_GLOWS) + 1], material = Enum.Material.Neon, collide = false })
		if i % 2 == 0 then
			Kit.light(pod, GLOW, 14, 0.9)
		end
	end
	-- a curtain of moss hanging under the arch the runners pass through
	for i = 1, 6 do
		local x = -10 + i * 2.9 + rng(-0.6, 0.6)
		local top = 27 - math.abs(x) * 0.25
		rod(Kit, m, Vector3.new(x, top, zt - 3), Vector3.new(x + rng(-0.3, 0.3), top - rng(5, 9), zt - 3.4), 0.5, { name = "MossCurtain", color = MOSS, material = Enum.Material.LeafyGrass, collide = false })
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

	-- is a prop of radius r at (x, z) clear of the corridor, nest and gate?
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
	-- ground: patchwork of leafy grass, grass and mud; a mud trail runs over
	-- the cracked cobbles of the old road
	---------------------------------------------------------------------
	local cols = { { -75, -45 }, { -45, -13 }, { -13, 13 }, { 13, 45 }, { 45, 75 } }
	local rows = 8
	local rowLen = ctx.length / rows
	for r = 0, rows - 1 do
		for c, span in ipairs(cols) do
			local mat, col
			if c == 3 then
				mat, col = Enum.Material.Mud, Kit.shade(MUD, rng(0.92, 1.05))
			else
				mat = GROUND_MATS[math.floor(rng(1, #GROUND_MATS + 0.999))]
				col = (mat == Enum.Material.Mud) and Kit.shade(MUD_DARK, rng(0.95, 1.1)) or Kit.shade(((r + c) % 2 == 0) and LEAF or LEAF_DARK, rng(0.9, 1.08))
			end
			Kit.part(f, { name = "Ground", size = Vector3.new(span[2] - span[1], 4, rowLen), cf = CFrame.new((span[1] + span[2]) / 2, -2, z0 + (r + 0.5) * rowLen), color = col, material = mat })
		end
	end
	-- trail edges: ragged mud tongues spilling into the grass
	local trailEnd = nest.Z - nestGuard + 6
	for i = 0, 6 do
		local z = z0 + 8 + i * (trailEnd - z0 - 8) / 7
		for side = -1, 1, 2 do
			Kit.part(f, { name = "TrailEdge", size = Vector3.new(rng(4, 7), 0.2, rng(11, 17)), cf = CFrame.new(side * (half + rng(-0.5, 1.5)), 0.05, z) * CFrame.Angles(0, rng(-0.5, 0.5), 0), color = Kit.shade(MUD, rng(0.85, 1)), material = Enum.Material.Mud, collide = false })
		end
	end
	-- broken cobbles of the old road poking through the mud
	for i = 1, 14 do
		local x = rng(-half + 2, half - 2)
		local z = rng(z0 + 8, trailEnd)
		Kit.part(f, { name = "Cobble", size = Vector3.new(rng(2.5, 4.5), 0.3, rng(2.5, 4.5)), cf = CFrame.new(x, 0.12, z) * CFrame.Angles(0, rng(0, 1.5), 0), color = Kit.shade(STONE, rng(0.85, 1.05)), material = Enum.Material.Cobblestone })
	end
	-- moss patches everywhere (flat, decorative)
	for i = 1, 16 do
		local x = rng(-70, 70)
		local z = rng(z0 + 6, z1 - 6)
		Kit.cylinder(f, { name = "MossPatch", height = 0.2, diameter = rng(5, 14), cf = CFrame.new(x, 0.06, z), color = Kit.shade(MOSS, rng(0.85, 1.1)), material = Enum.Material.LeafyGrass, collide = false })
	end
	-- a ring of wildflower moss around the nest
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local p = nest + Vector3.new(math.cos(a), 0, math.sin(a)) * (ctx.nestRadius + 10)
		Kit.cylinder(f, { name = "NestMoss", height = 0.2, diameter = rng(8, 12), cf = CFrame.new(p.X, 0.07, p.Z), color = Kit.shade(MOSS, rng(0.95, 1.15)), material = Enum.Material.LeafyGrass, collide = false })
	end

	---------------------------------------------------------------------
	-- ruins: an arch the route still runs through, a broken one, pillars
	---------------------------------------------------------------------
	ruinArch(ctx, f, z0 + 64)
	brokenArch(ctx, f, z0 + 112)
	local pillarSpots = {
		{ -30, z0 + 22, 11, false }, { 34, z0 + 40, 13, true }, { -38, z0 + 88, 9, true },
		{ 40, z0 + 90, 14, false }, { -62, z0 + 140, 12, false }, { 63, z0 + 160, 10, true },
		{ -60, z0 + 200, 15, false }, { 60, z0 + 212, 8, true },
	}
	for _, s in ipairs(pillarSpots) do
		ruinPillar(ctx, f, Vector3.new(s[1], 0, s[2]), s[3], s[4])
	end
	-- fallen drums half sunk in the moss
	for _, d in ipairs({ { -24, z0 + 48, 0.4 }, { 28, z0 + 74, -0.9 }, { -55, z0 + 170, 1.2 }, { 52, z0 + 120, 0.2 } }) do
		Kit.cylinder(f, { name = "FallenDrum", height = 5, diameter = 3.6, cf = CFrame.new(d[1], 1.2, d[2]) * CFrame.Angles(0, d[3], math.pi / 2), color = STONE, material = Enum.Material.Cobblestone })
	end

	---------------------------------------------------------------------
	-- giant mushrooms: the recurring silhouette, biggest near the walls
	---------------------------------------------------------------------
	local shrooms = {
		{ -26, z0 + 30, 13, 13, true }, { 27, z0 + 18, 10, 11, false }, { -50, z0 + 40, 22, 19, false },
		{ 54, z0 + 56, 20, 18, true }, { 24, z0 + 100, 12, 12, true }, { -27, z0 + 128, 14, 12, false },
		{ -56, z0 + 96, 18, 16, true }, { 58, z0 + 104, 24, 20, false }, { -64, z0 + 160, 16, 14, true },
		{ 64, z0 + 186, 19, 15, true }, { -48, z0 + 236, 12, 12, true }, { 50, z0 + 240, 14, 12, true },
		{ -66, z0 + 70, 11, 10, false }, { 68, z0 + 26, 13, 12, false },
	}
	for i, s in ipairs(shrooms) do
		mushroom(ctx, f, Vector3.new(s[1], 0, s[2]), s[3], s[4], i, s[5])
	end
	-- little mushroom clusters along the trail edge
	for i = 1, 7 do
		local side = (i % 2 == 0) and 1 or -1
		local x = side * rng(18, 23)
		local z = z0 + 14 + i * 15
		if clear(x, z, 2) then
			mushroom(ctx, f, Vector3.new(x, 0, z), rng(2.5, 4), rng(3, 4.5), i + 2, i % 3 == 0)
		end
	end

	---------------------------------------------------------------------
	-- vines and roots bowing over the route (non-colliding)
	---------------------------------------------------------------------
	overArch(ctx, f, z0 + 30, 21, 21, 1.4, LEAF_DARK, Enum.Material.LeafyGrass, 4)
	overArch(ctx, f, z0 + 88, 23, 18, 2.6, BARK, Enum.Material.Wood, 3)
	overArch(ctx, f, z0 + 98, 20, 23, 1.2, LEAF, Enum.Material.LeafyGrass, 3)
	overArch(ctx, f, z0 + 124, 22, 20, 2.2, BARK_DARK, Enum.Material.Wood, 4)

	-- gnarled roots snaking along the ground at the sides
	for i = 1, 10 do
		local side = (i % 2 == 0) and 1 or -1
		local x = side * rng(20, 66)
		local z = rng(z0 + 10, z1 - 12)
		if clear(x, z, 6) then
			local a = Vector3.new(x - 5, -0.6, z + rng(-3, 3))
			local b = Vector3.new(x + 5, -0.6, z + rng(-3, 3))
			rod(Kit, f, a, Vector3.new(x, 1.2, z), 2.2, { name = "Root", color = BARK, material = Enum.Material.Wood })
			rod(Kit, f, Vector3.new(x, 1.2, z), b, 1.8, { name = "Root", color = BARK_DARK, material = Enum.Material.Wood })
		end
	end

	---------------------------------------------------------------------
	-- ferns & bushes: dense near the walls, a frond line along the trail
	---------------------------------------------------------------------
	local placed = 0
	for i = 1, 60 do
		if placed >= 13 then
			break
		end
		local side = (i % 2 == 0) and 1 or -1
		local x = side * rng(17, 72)
		local z = rng(z0 + 8, z1 - 8)
		if math.abs(x) > half + 3 and (Vector3.new(x, 0, z) - nest).Magnitude > ctx.nestRadius + 9 then
			fern(ctx, f, Vector3.new(x, 0, z), rng(0.8, 1.4))
			placed = placed + 1
		end
	end
	for i = 1, 12 do
		local side = (i % 2 == 0) and 1 or -1
		local x = side * rng(46, 70)
		local z = rng(z0 + 10, z1 - 10)
		if clear(x, z, 4) then
			local col = Kit.shade(LEAF_DARK, rng(0.85, 1.15))
			Kit.ball(f, { name = "Bush", diameter = rng(5, 7.5), cf = CFrame.new(x, 1.6, z), color = col, material = Enum.Material.LeafyGrass })
			Kit.ball(f, { name = "Bush", diameter = rng(3.5, 5), cf = CFrame.new(x + rng(-3, 3), 1.3, z + rng(-3, 3)), color = Kit.shade(col, 1.12), material = Enum.Material.LeafyGrass })
		end
	end
	-- old forest trees packed against the side walls
	for i = 0, 5 do
		for side = -1, 1, 2 do
			local z = z0 + 14 + i * 40 + rng(-5, 5)
			if clear(side * 71, z, 4) then
				ctx.tree(f, Vector3.new(side * 71, 0, z), 1.5 + rng(0, 0.5), Kit.shade(LEAF_DARK, rng(0.9, 1.1)))
			end
		end
	end

	---------------------------------------------------------------------
	-- fireflies: drifting sparkles over the undergrowth, a few lit motes
	---------------------------------------------------------------------
	for _, a in ipairs({ { -42, z0 + 60 }, { 42, z0 + 60 }, { -45, z0 + 170 }, { 45, z0 + 170 }, { 0, z0 + 70 } }) do
		local carrier = Kit.part(f, { name = "Fireflies", size = Vector3.new(34, 8, 60), cf = CFrame.new(a[1], 5, a[2]), transparency = 1, collide = false, castShadow = false })
		carrier.CanQuery = false
		Kit.particles(carrier, { color = FIREFLY, color2 = GLOW, size = 0.3, sizeEnd = 0.1, rate = 5, lifetime = 3, speed = 0.6, emission = 1, transparency = 0.1 })
	end
	for i = 1, 18 do
		local x = rng(-66, 66)
		local z = rng(z0 + 10, z1 - 10)
		local mote = Kit.ball(f, { name = "Firefly", diameter = 0.35, cf = CFrame.new(x, rng(1.5, 8), z), color = FIREFLY, material = Enum.Material.Neon, collide = false, castShadow = false })
		if i % 5 == 0 then
			Kit.light(mote, FIREFLY, 8, 0.8)
		end
	end

	---------------------------------------------------------------------
	-- hero: the colossal ancient tree arching over the route behind the nest
	---------------------------------------------------------------------
	heroTree(ctx, f, z1 - 14)

	clearPlayArea(ctx)

	return {
		palette = {
			accent = GLOW,
			gate = { 96, 112, 86 },
			gateMaterial = Enum.Material.Cobblestone,
			nest = { 92, 74, 52 },
			nestMaterial = Enum.Material.Mud,
		},
	}
end
