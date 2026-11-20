--[[
	CoreModels — builds the Disaster Core collectibles (the "eggs").

	Every core shares a readable silhouette — a glowing heart inside a
	containment shell held by two dark metal caps. The `shape` from config adds
	a distinct accent so cores read at a distance: Swirl rings, Crystal shards,
	Charged prongs, organic Pod leaves, Spiked shell, Flame petals, Cracked
	rock, Wave crest, Chaos gyro.

	Model contract:
	  * returns a Model whose PrimaryPart "Root" sits at the core's center
	  * all parts anchored, non-colliding, CanTouch false
	  * attributes: CoreId, Mutation, Rarity
	  * parts with attribute "Orbit" (rad/s) are spun around the Root's Y axis
	    by the client animator; the model carries the "Animated" tag
]]

local Config = require(script.Parent.Parent.Config.GameConfig)
local Kit = require(script.Parent.Kit)

local CoreModels = {}

local METAL = { 46, 48, 58 }

local function orbit(part, speed)
	part:SetAttribute("Orbit", speed)
	return part
end

local function ring(model, radius, count, size, color, material, tilt, speed, y)
	for i = 1, count do
		local a = (i - 1) / count * math.pi * 2
		local cf = CFrame.Angles(tilt or 0, 0, 0) * CFrame.new(math.cos(a) * radius, y or 0, math.sin(a) * radius)
		local p = Kit.part(model, {
			name = "Ring",
			size = Vector3.new(size, size * 0.5, size * 1.6),
			cf = cf * CFrame.Angles(0, -a, 0),
			color = color,
			material = material or Enum.Material.Neon,
			collide = false,
		})
		if speed then
			orbit(p, speed)
		end
	end
end

local accents = {}

function accents.Swirl(m, c)
	Kit.cylinder(m, { name = "Disk", height = 0.12, diameter = 3.6, color = c[3], material = Enum.Material.Neon, transparency = 0.55, collide = false })
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		local b = Kit.ball(m, {
			name = "Debris",
			diameter = 0.45,
			cf = CFrame.new(math.cos(a) * 1.9, 0.25 * (i - 2), math.sin(a) * 1.9),
			color = c[2],
			material = Enum.Material.Slate,
			collide = false,
		})
		orbit(b, 2.4)
	end
end

function accents.Crystal(m, c)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		Kit.part(m, {
			name = "Shard",
			size = Vector3.new(0.5, 1.9, 0.5),
			cf = CFrame.new(math.cos(a) * 1.15, -0.1, math.sin(a) * 1.15) * CFrame.Angles(math.sin(a) * 0.5, a, math.cos(a) * 0.5),
			color = c[1],
			material = Enum.Material.Glass,
			transparency = 0.25,
			collide = false,
		})
	end
	Kit.part(m, { name = "Spire", size = Vector3.new(0.55, 1.6, 0.55), cf = CFrame.new(0, 1.7, 0) * CFrame.Angles(0, math.pi / 4, 0), color = c[3], material = Enum.Material.Neon, collide = false })
end

function accents.Charged(m, c)
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		Kit.part(m, {
			name = "Prong",
			size = Vector3.new(0.22, 1.6, 0.22),
			cf = CFrame.new(math.cos(a) * 1.1, 1.0, math.sin(a) * 1.1) * CFrame.Angles(math.sin(a) * 0.45, 0, -math.cos(a) * 0.45),
			color = METAL,
			material = Enum.Material.Metal,
			collide = false,
		})
		Kit.ball(m, { name = "Tip", diameter = 0.38, cf = CFrame.new(math.cos(a) * 1.45, 1.75, math.sin(a) * 1.45), color = c[3], material = Enum.Material.Neon, collide = false })
	end
	-- zig-zag arc
	local pts = { { -1.2, 0.2 }, { -0.4, 0.6 }, { 0.2, 0.0 }, { 1.1, 0.45 } }
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local p0, p1 = Vector3.new(a[1], a[2], 1.25), Vector3.new(b[1], b[2], 1.25)
		Kit.part(m, {
			name = "Arc",
			size = Vector3.new(0.12, 0.12, (p1 - p0).Magnitude),
			cf = CFrame.lookAt((p0 + p1) / 2, p1),
			color = c[3],
			material = Enum.Material.Neon,
			collide = false,
		})
	end
end

function accents.Pod(m, c)
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2
		Kit.part(m, {
			name = "Leaf",
			shape = "Wedge",
			size = Vector3.new(0.18, 1.4, 1.1),
			cf = CFrame.new(math.cos(a) * 1.0, -0.85, math.sin(a) * 1.0) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(-0.5, 0, 0),
			color = c[2],
			material = Enum.Material.Grass,
			collide = false,
		})
	end
	Kit.cylinder(m, { name = "Stem", height = 0.9, diameter = 0.3, cf = CFrame.new(0, 1.65, 0), color = c[2], material = Enum.Material.Grass, collide = false })
	Kit.ball(m, { name = "Bud", diameter = 0.55, cf = CFrame.new(0, 2.1, 0), color = c[3], material = Enum.Material.Neon, collide = false })
end

function accents.Spiked(m, c)
	local dirs = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 }, { 0, 0, -1 }, { 0.7, 0.7, 0.7 }, { -0.7, 0.7, -0.7 }, { 0.7, -0.5, -0.7 } }
	for _, d in ipairs(dirs) do
		local dir = Vector3.new(d[1], d[2], d[3]).Unit
		local pos = dir * 1.45
		Kit.part(m, {
			name = "Spike",
			size = Vector3.new(0.35, 0.35, 1.1),
			cf = CFrame.lookAt(pos, pos + dir),
			color = c[2],
			material = Enum.Material.Basalt,
			collide = false,
		})
		Kit.ball(m, { name = "SpikeTip", diameter = 0.24, cf = CFrame.new(dir * 2.0), color = c[3], material = Enum.Material.Neon, collide = false })
	end
end

function accents.Flame(m, c)
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		Kit.part(m, {
			name = "Petal",
			shape = "Wedge",
			size = Vector3.new(0.2, 1.5, 0.9),
			cf = CFrame.new(math.cos(a) * 0.55, 1.55, math.sin(a) * 0.55) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(0.35, 0, 0),
			color = c[3],
			material = Enum.Material.Neon,
			collide = false,
		})
	end
	local core = m:FindFirstChild("Heart")
	if core then
		Kit.particles(core, { color = c[3], color2 = c[1], size = 0.6, rate = 14, speed = 2.5, lifetime = 0.7, spread = 25, accel = Vector3.new(0, 5, 0) })
	end
end

function accents.Cracked(m, c)
	local shell = m:FindFirstChild("Shell")
	if shell then
		shell.Material = Enum.Material.Slate
		shell.Transparency = 0
		shell.Color = Kit.rgb(c[2])
	end
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local dir = Vector3.new(math.cos(a), (i % 2 == 0) and 0.35 or -0.3, math.sin(a)).Unit
		Kit.part(m, {
			name = "Crack",
			size = Vector3.new(0.14, 0.9, 0.08),
			cf = CFrame.lookAt(dir * 1.2, dir * 2.4) * CFrame.Angles(0, 0, a),
			color = c[3],
			material = Enum.Material.Neon,
			collide = false,
		})
	end
end

function accents.Wave(m, c)
	for i = 1, 5 do
		local t = (i - 1) / 4
		local ang = -0.6 + t * 2.2
		Kit.part(m, {
			name = "Crest",
			size = Vector3.new(2.6 - t * 0.9, 0.3, 0.6),
			cf = CFrame.new(0, 0.8, 0) * CFrame.Angles(ang, 0, 0) * CFrame.new(0, 0, -1.25),
			color = (i >= 4) and c[2] or c[1],
			material = (i >= 4) and Enum.Material.SmoothPlastic or Enum.Material.Glass,
			transparency = (i >= 4) and 0 or 0.2,
			collide = false,
		})
	end
	Kit.ball(m, { name = "Foam", diameter = 0.6, cf = CFrame.new(0.5, 1.9, 0.4), color = c[2], collide = false })
	Kit.ball(m, { name = "Foam", diameter = 0.45, cf = CFrame.new(-0.6, 1.8, 0.5), color = c[2], collide = false })
end

function accents.Chaos(m, c)
	ring(m, 1.9, 10, 0.32, c[1], Enum.Material.Neon, 0.5, 2.8)
	ring(m, 1.65, 8, 0.28, c[2], Enum.Material.Neon, -0.9, -3.4)
	local core = m:FindFirstChild("Heart")
	if core then
		Kit.particles(core, { color = c[1], color2 = c[2], size = 0.5, rate = 20, speed = 3, lifetime = 1 })
	end
end

local function mutationFx(m, root, mutationId)
	local mut = mutationId and Config.Mutations[mutationId]
	if not mut then
		return
	end
	local aura = Kit.ball(m, {
		name = "MutationAura",
		diameter = 4.2,
		color = mut.color,
		material = Enum.Material.ForceField,
		transparency = 0.15,
		collide = false,
		castShadow = false,
	})
	aura.CFrame = root.CFrame
	Kit.particles(root, { color = mut.color, size = 0.35, rate = 8, speed = 1.5, lifetime = 1.2, emission = 1 })
	if mutationId == "Golden" then
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "Cap" then
				d.Color = Kit.rgb({ 255, 200, 40 })
				d.Material = Enum.Material.Foil
				d.Reflectance = 0.3
			end
		end
	end
end

--[[
	CoreModels.build(coreId, mutationId, sizeMult?) -> Model
]]
function CoreModels.build(coreId, mutationId, sizeMult)
	local def = Config.Cores[coreId]
	if not def then
		error("Unknown core " .. tostring(coreId))
	end
	local c = def.colors
	local rarity = Config.Rarities[def.rarity]
	local m = Instance.new("Model")
	m.Name = def.name

	local root = Kit.part(m, { name = "Root", size = Vector3.new(0.4, 0.4, 0.4), transparency = 1, collide = false })
	m.PrimaryPart = root

	local heart = Kit.ball(m, { name = "Heart", diameter = 1.5, color = c[3], material = Enum.Material.Neon, collide = false })
	Kit.light(heart, c[3], 10, 1.6)
	Kit.ball(m, { name = "Shell", diameter = 2.5, color = c[1], material = Enum.Material.Glass, transparency = 0.55, collide = false, castShadow = false })
	Kit.cylinder(m, { name = "Cap", height = 0.35, diameter = 1.7, cf = CFrame.new(0, 1.2, 0), color = METAL, material = Enum.Material.Metal, collide = false })
	Kit.cylinder(m, { name = "Cap", height = 0.35, diameter = 1.7, cf = CFrame.new(0, -1.2, 0), color = METAL, material = Enum.Material.Metal, collide = false })
	-- rarity band around the equator: readable rarity color from any angle
	Kit.cylinder(m, { name = "Band", height = 0.22, diameter = 2.62, color = rarity.color, material = Enum.Material.Neon, collide = false, castShadow = false })

	local accent = accents[def.shape] or accents.Swirl
	accent(m, c)
	mutationFx(m, root, mutationId)

	-- slight bigger cores for higher rarity
	local scale = (1 + (rarity.rank - 1) * 0.07) * (sizeMult or 1)
	if scale ~= 1 then
		m:ScaleTo(scale)
	end

	m:SetAttribute("CoreId", coreId)
	m:SetAttribute("Rarity", def.rarity)
	if mutationId then
		m:SetAttribute("Mutation", mutationId)
	end
	m:SetAttribute("AnimBob", 0.35)
	m:SetAttribute("AnimSpin", 0.8)
	Kit.setCollide(m, false)
	return m
end

return CoreModels
