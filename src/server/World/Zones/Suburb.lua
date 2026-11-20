--[[
	Zone 1 — Suburb. A quiet cul-de-sac that's clearly been through some
	weather: pastel houses, picket fences, a road that loops around the core
	nest, a tornado-flattened backyard behind it.

	Zone builder contract (see docs/ZONE_CONTRACT.md):
	  build(ctx) -> { palette = { accent, gate, gateMaterial, nest, nestMaterial } }
	  ctx: folder, index, zone, z0, z1, length, width, pathWidth, nest (Vector3),
	       nestRadius, rng(a,b), Kit, tree(parent, pos, scale, leafColor)
]]

local GRASS = { 108, 178, 78 }
local GRASS_DARK = { 92, 160, 66 }
local ASPHALT = { 64, 66, 74 }
local SIDEWALK = { 205, 205, 200 }
local WHITE = { 245, 245, 240 }
local HOUSE_COLORS = { { 245, 214, 170 }, { 170, 210, 235 }, { 240, 180, 180 }, { 200, 230, 180 }, { 230, 220, 250 }, { 250, 235, 160 } }
local ROOF_COLORS = { { 150, 70, 60 }, { 70, 80, 100 }, { 110, 60, 50 }, { 60, 90, 70 } }

local function house(ctx, parent, pos, facing, colorIdx)
	local Kit = ctx.Kit
	local m = Kit.model(parent, "House")
	local wallColor = HOUSE_COLORS[(colorIdx - 1) % #HOUSE_COLORS + 1]
	local roofColor = ROOF_COLORS[(colorIdx - 1) % #ROOF_COLORS + 1]
	-- local frame: front of the house faces the road (`facing` = +1 means front toward -X)
	local base = CFrame.new(pos) * CFrame.Angles(0, facing > 0 and math.pi / 2 or -math.pi / 2, 0)
	local w, d, h = 20, 14, 10
	Kit.part(m, { name = "Foundation", size = Vector3.new(w + 1, 1, d + 1), cf = base * CFrame.new(0, 0.5, 0), color = { 150, 150, 150 }, material = Enum.Material.Concrete })
	Kit.part(m, { name = "Walls", size = Vector3.new(w, h, d), cf = base * CFrame.new(0, 1 + h / 2, 0), color = wallColor, material = Enum.Material.WoodPlanks })
	-- gabled roof from two wedges
	local roofH = 6
	Kit.part(m, { name = "Roof", shape = "Wedge", size = Vector3.new(w + 2, roofH, d / 2 + 1), cf = base * CFrame.new(0, 1 + h + roofH / 2, -(d / 4 + 0.5)) * CFrame.Angles(0, math.pi, 0), color = roofColor, material = Enum.Material.Slate })
	Kit.part(m, { name = "Roof", shape = "Wedge", size = Vector3.new(w + 2, roofH, d / 2 + 1), cf = base * CFrame.new(0, 1 + h + roofH / 2, d / 4 + 0.5), color = roofColor, material = Enum.Material.Slate })
	Kit.part(m, { name = "Chimney", size = Vector3.new(2.2, 5, 2.2), cf = base * CFrame.new(w / 2 - 4, 1 + h + 4, 2), color = { 160, 80, 60 }, material = Enum.Material.Brick })
	-- front (local -Z) details
	local front = -d / 2 - 0.1
	Kit.part(m, { name = "Door", size = Vector3.new(3.4, 6.4, 0.4), cf = base * CFrame.new(-3, 4.2, front), color = { 120, 70, 50 }, material = Enum.Material.Wood })
	Kit.ball(m, { name = "Knob", diameter = 0.4, cf = base * CFrame.new(-1.8, 4.2, front - 0.3), color = { 230, 190, 60 }, material = Enum.Material.Metal })
	for _, x in ipairs({ 3.5, 7 }) do
		local win = Kit.part(m, { name = "Window", size = Vector3.new(2.8, 3, 0.3), cf = base * CFrame.new(x, 6, front), color = { 170, 220, 255 }, material = Enum.Material.Glass, transparency = 0.15, reflectance = 0.2 })
		Kit.part(m, { name = "Frame", size = Vector3.new(3.4, 0.4, 0.5), cf = base * CFrame.new(x, 7.6, front), color = WHITE, material = Enum.Material.SmoothPlastic })
		Kit.part(m, { name = "Frame", size = Vector3.new(3.4, 0.4, 0.5), cf = base * CFrame.new(x, 4.4, front), color = WHITE, material = Enum.Material.SmoothPlastic })
	end
	-- porch light
	local lamp = Kit.part(m, { name = "PorchLight", size = Vector3.new(0.6, 0.8, 0.6), cf = base * CFrame.new(-5.4, 7.4, front - 0.3), color = { 255, 230, 170 }, material = Enum.Material.Neon })
	Kit.light(lamp, { 255, 220, 160 }, 14, 0.9)
	return m, base
end

local function picketFence(ctx, parent, from, to)
	local Kit = ctx.Kit
	local dir = (to - from)
	local len = dir.Magnitude
	local n = math.floor(len / 2.2)
	local cf = CFrame.lookAt(from, to)
	Kit.part(parent, { name = "Rail", size = Vector3.new(0.3, 0.4, len), cf = cf * CFrame.new(0, 2.2, -len / 2), color = WHITE, material = Enum.Material.WoodPlanks })
	Kit.part(parent, { name = "Rail", size = Vector3.new(0.3, 0.4, len), cf = cf * CFrame.new(0, 1.2, -len / 2), color = WHITE, material = Enum.Material.WoodPlanks })
	for i = 0, n do
		Kit.part(parent, { name = "Picket", size = Vector3.new(0.4, 3, 0.9), cf = cf * CFrame.new(0, 1.5, -i * (len / math.max(1, n))), color = WHITE, material = Enum.Material.WoodPlanks })
	end
end

local function mailbox(ctx, parent, pos, color)
	local Kit = ctx.Kit
	Kit.part(parent, { name = "MailPost", size = Vector3.new(0.4, 3.4, 0.4), cf = CFrame.new(pos + Vector3.new(0, 1.7, 0)), color = { 120, 85, 55 }, material = Enum.Material.Wood })
	Kit.part(parent, { name = "Mailbox", size = Vector3.new(1.2, 1.1, 2), cf = CFrame.new(pos + Vector3.new(0, 3.8, 0)), color = color, material = Enum.Material.Metal })
	Kit.part(parent, { name = "Flag", size = Vector3.new(0.1, 0.9, 0.3), cf = CFrame.new(pos + Vector3.new(0.65, 4.2, 0.4)), color = { 220, 50, 50 }, material = Enum.Material.SmoothPlastic })
end

local function streetLamp(ctx, parent, pos, armDir)
	local Kit = ctx.Kit
	Kit.cylinder(parent, { name = "LampPost", height = 13, diameter = 0.6, cf = CFrame.new(pos + Vector3.new(0, 6.5, 0)), color = { 50, 55, 65 }, material = Enum.Material.Metal })
	Kit.part(parent, { name = "LampArm", size = Vector3.new(3.5, 0.4, 0.4), cf = CFrame.new(pos + Vector3.new(armDir * 1.75, 13, 0)), color = { 50, 55, 65 }, material = Enum.Material.Metal })
	local bulb = Kit.part(parent, { name = "LampHead", size = Vector3.new(1.6, 0.6, 1.2), cf = CFrame.new(pos + Vector3.new(armDir * 3.3, 12.7, 0)), color = { 255, 240, 200 }, material = Enum.Material.Neon })
	Kit.light(bulb, { 255, 230, 190 }, 24, 1.2)
end

return function(ctx)
	local Kit = ctx.Kit
	local f = ctx.folder
	local z0, z1, W = ctx.z0, ctx.z1, ctx.width
	local zm = (z0 + z1) / 2
	local rng = ctx.rng
	local nest = ctx.nest
	local road = ctx.pathWidth

	-- ground: two-tone lawn stripes (mowed look)
	for i = 0, 12 do
		Kit.part(f, {
			name = "Lawn",
			size = Vector3.new(W, 4, ctx.length / 13),
			cf = CFrame.new(0, -2, z0 + (i + 0.5) * ctx.length / 13),
			color = (i % 2 == 0) and GRASS or GRASS_DARK,
			material = Enum.Material.Grass,
		})
	end

	-- road up to the cul-de-sac, with curbs, sidewalks and a dashed center line
	local roadEnd = nest.Z - 20
	local roadLen = roadEnd - z0
	Kit.part(f, { name = "Road", size = Vector3.new(road, 0.3, roadLen), cf = CFrame.new(0, 0.15, z0 + roadLen / 2), color = ASPHALT, material = Enum.Material.Asphalt })
	Kit.cylinder(f, { name = "CulDeSac", height = 0.3, diameter = ctx.nestRadius * 2 + 34, cf = CFrame.new(nest.X, 0.15, nest.Z), color = ASPHALT, material = Enum.Material.Asphalt })
	for i = 0, math.floor((nest.Z - (ctx.nestRadius + 17) - z0) / 10) - 1 do
		Kit.part(f, { name = "Dash", size = Vector3.new(0.6, 0.32, 5), cf = CFrame.new(0, 0.16, z0 + 5 + i * 10), color = { 250, 210, 60 }, material = Enum.Material.SmoothPlastic })
	end
	-- sidewalks stop where the cul-de-sac circle begins
	local culR = ctx.nestRadius + 17
	local walkLen = (nest.Z - math.sqrt(culR * culR - (road / 2 + 6) ^ 2)) - z0
	for side = -1, 1, 2 do
		local x = side * (road / 2 + 3)
		Kit.part(f, { name = "Sidewalk", size = Vector3.new(6, 0.6, walkLen), cf = CFrame.new(x, 0.3, z0 + walkLen / 2), color = SIDEWALK, material = Enum.Material.Concrete })
		Kit.part(f, { name = "Curb", size = Vector3.new(0.6, 0.7, walkLen), cf = CFrame.new(side * (road / 2 + 0.3), 0.35, z0 + walkLen / 2), color = { 170, 170, 165 }, material = Enum.Material.Concrete })
	end

	-- houses along both sides, facing the road
	local houseZ = { z0 + 22, z0 + 62, z0 + 100 }
	local colorIdx = 1
	for side = -1, 1, 2 do
		for i, hz in ipairs(houseZ) do
			local hx = side * 46
			house(ctx, f, Vector3.new(hx, 0, hz), side, colorIdx)
			colorIdx = colorIdx + 1
			-- driveway & mailbox
			Kit.part(f, { name = "Driveway", size = Vector3.new(22, 0.35, 7), cf = CFrame.new(side * (road / 2 + 14), 0.18, hz + 9), color = { 150, 150, 150 }, material = Enum.Material.Concrete })
			mailbox(ctx, f, Vector3.new(side * (road / 2 + 6.5), 0, hz + 4), HOUSE_COLORS[(colorIdx % #HOUSE_COLORS) + 1])
			-- front-yard picket fence segment (leaves the driveway open)
			picketFence(ctx, f, Vector3.new(side * (road / 2 + 7), 0, hz - 18), Vector3.new(side * (road / 2 + 7), 0, hz + 4))
			-- yard tree
			ctx.tree(f, Vector3.new(side * 66, 0, hz - 12 + rng(-3, 3)), 1.1 + rng(0, 0.3))
			if i < #houseZ then
				streetLamp(ctx, f, Vector3.new(side * (road / 2 + 4.5), 0.6, hz + 24), -side)
			end
		end
	end

	-- hydrant + trash cans for scale
	for side = -1, 1, 2 do
		local hz = z0 + 50
		Kit.cylinder(f, { name = "Hydrant", height = 2.4, diameter = 1.2, cf = CFrame.new(side * (road / 2 + 5), 1.8, hz), color = { 220, 50, 40 }, material = Enum.Material.Metal })
		Kit.ball(f, { name = "HydrantCap", diameter = 1.2, cf = CFrame.new(side * (road / 2 + 5), 3, hz), color = { 220, 50, 40 }, material = Enum.Material.Metal })
		Kit.cylinder(f, { name = "Bin", height = 3.2, diameter = 2.2, cf = CFrame.new(side * (road / 2 + 5.4), 2.2, z0 + 96), color = { 60, 120, 70 }, material = Enum.Material.SmoothPlastic })
	end

	-- hedge ring around the cul-de-sac (gaps left for the road and escape)
	local ringR = ctx.nestRadius + 26
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		-- skip the segment where the road arrives (dir.z < -0.8) to keep the escape open
		if dir.Z > -0.75 then
			local p = nest + dir * ringR
			Kit.part(f, { name = "Hedge", size = Vector3.new(11, 5, 3.2), cf = CFrame.lookAt(Vector3.new(p.X, 2.5, p.Z), Vector3.new(nest.X, 2.5, nest.Z)), color = { 60, 130, 55 }, material = Enum.Material.Grass })
		end
	end

	-- the flattened backyard: proof something passed through
	local by = z1 - 18
	Kit.part(f, { name = "Shingle", size = Vector3.new(4, 0.3, 3), cf = CFrame.new(-20, 0.3, by) * CFrame.Angles(0.1, 0.6, 0.15), color = { 150, 70, 60 }, material = Enum.Material.Slate })
	Kit.part(f, { name = "Shingle", size = Vector3.new(3, 0.3, 2.5), cf = CFrame.new(-14, 0.2, by + 4) * CFrame.Angles(-0.1, 1.4, 0.05), color = { 150, 70, 60 }, material = Enum.Material.Slate })
	Kit.part(f, { name = "Plank", size = Vector3.new(0.4, 0.4, 6), cf = CFrame.new(16, 0.4, by - 2) * CFrame.Angles(0, 0.4, 0.2), color = WHITE, material = Enum.Material.WoodPlanks })
	-- fallen tree
	Kit.cylinder(f, { name = "FallenTrunk", height = 14, diameter = 1.6, cf = CFrame.new(30, 1, by + 2) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(0.3, 0, 0), color = { 110, 75, 50 }, material = Enum.Material.Wood })
	Kit.ball(f, { name = "FallenLeaves", diameter = 7, cf = CFrame.new(37, 3, by + 4), color = { 90, 150, 60 }, material = Enum.Material.Grass })
	-- overturned trampoline
	Kit.cylinder(f, { name = "Trampoline", height = 0.4, diameter = 12, cf = CFrame.new(-36, 3, by + 6) * CFrame.Angles(0.9, 0, 0.2), color = { 30, 30, 40 }, material = Enum.Material.Fabric })
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2
		Kit.ball(f, { name = "Debris", diameter = 0.8 + rng(0, 0.6), cf = CFrame.new(rng(-55, 55), 0.4, by + rng(-6, 10)), color = { 120, 110, 100 }, material = Enum.Material.Slate })
	end
	-- back tree line
	for i = 0, 8 do
		ctx.tree(f, Vector3.new(-64 + i * 16 + rng(-3, 3), 0, z1 - 5 + rng(-2, 2)), 1.2 + rng(0, 0.4))
	end
	-- side tree lines along the boundaries
	for i = 0, 6 do
		for side = -1, 1, 2 do
			ctx.tree(f, Vector3.new(side * 71, 0, z0 + 15 + i * 36 + rng(-4, 4)), 0.9 + rng(0, 0.3), { 70, 150, 60 })
		end
	end

	return {
		palette = {
			accent = { 120, 200, 255 },
			gate = { 175, 90, 70 },
			gateMaterial = Enum.Material.Brick,
			nest = { 90, 92, 100 },
			nestMaterial = Enum.Material.Concrete,
		},
	}
end
