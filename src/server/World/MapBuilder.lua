--[[
	MapBuilder — builds the static world from config at server start:
	lighting baseline, the starting hub (Storm Research Plaza), the long central
	route with a gate arch per zone, a nest per zone and boundaries.
	Per-zone environments are delegated to World/Zones/<ZoneId>.lua (falls back
	to World/Zones/Generic.lua).

	Returns refs used by the services:
	  { root, hub, zones = { [i] = { folder, nestCenter, nestPoints = {Vector3}, gate } } }
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local WorldLayout = require(Shared.Logic.WorldLayout)
local Util = require(Shared.Util)
local Kit = require(Shared.Models.Kit)

local ZonesFolder = script.Parent:WaitForChild("Zones")

local MapBuilder = {}

local W = Config.World

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

local function seededRng(seed)
	local r = Random.new(seed)
	return function(a, b)
		if a then
			return r:NextNumber(a, b)
		end
		return r:NextNumber()
	end
end

---------------------------------------------------------------------------
-- Lighting baseline (the client tweens per-zone moods on top of this)
---------------------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 14.2
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(110, 110, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 165)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true
	Lighting.FogColor = Color3.fromRGB(190, 215, 255)
	Lighting.FogStart = 0
	Lighting.FogEnd = 1200
	Lighting.ExposureCompensation = 0.1

	local function ensure(class, name)
		local e = Lighting:FindFirstChild(name)
		if not e then
			e = Instance.new(class)
			e.Name = name
			e.Parent = Lighting
		end
		return e
	end
	local atm = ensure("Atmosphere", "Atmosphere")
	atm.Density = 0.28
	atm.Offset = 0.15
	atm.Color = Color3.fromRGB(200, 220, 255)
	atm.Decay = Color3.fromRGB(110, 120, 150)
	atm.Glare = 0.2
	atm.Haze = 1.2
	local cc = ensure("ColorCorrectionEffect", "ZoneGrade")
	cc.Saturation = 0.18
	cc.Contrast = 0.06
	cc.Brightness = 0.01
	local bloom = ensure("BloomEffect", "Bloom")
	bloom.Intensity = 0.55
	bloom.Size = 26
	bloom.Threshold = 1.6
	local rays = ensure("SunRaysEffect", "SunRays")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	ensure("Sky", "Sky")
end

---------------------------------------------------------------------------
-- Hub: Storm Research Plaza
---------------------------------------------------------------------------
local HAZARD_Y = { 255, 200, 40 }
local HAZARD_K = { 35, 35, 40 }
local CONCRETE = { 196, 196, 204 }
local DARK = { 46, 50, 62 }

local function hazardStripe(parent, cf, length, width, count)
	-- alternating yellow/black blocks along local X
	local seg = length / count
	for i = 1, count do
		Kit.part(parent, {
			name = "Hazard",
			size = Vector3.new(seg, 0.22, width),
			cf = cf * CFrame.new(-length / 2 + seg * (i - 0.5), 0, 0),
			color = (i % 2 == 0) and HAZARD_K or HAZARD_Y,
			material = Enum.Material.SmoothPlastic,
		})
	end
end

local function signBoard(parent, cf, size, title, subtitle, color)
	local board = Kit.part(parent, { name = "Sign", size = size, cf = cf, color = DARK, material = Enum.Material.Metal })
	local sg = Instance.new("SurfaceGui")
	sg.Name = "SignGui"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Brightness = 1.4
	sg.Parent = board
	Kit.text(sg, { name = "Title", text = title, size = UDim2.new(1, -20, 0.6, 0), position = UDim2.new(0, 10, 0.05, 0), color = color or { 255, 255, 255 }, font = Enum.Font.LuckiestGuy })
	if subtitle then
		Kit.text(sg, { name = "Subtitle", text = subtitle, size = UDim2.new(1, -20, 0.3, 0), position = UDim2.new(0, 10, 0.66, 0), color = { 230, 235, 255 } })
	end
	-- back face too
	local back = sg:Clone()
	back.Face = Enum.NormalId.Back
	back.Parent = board
	return board
end

local function kiosk(parent, pos, title, color, panel)
	local m = Kit.model(parent, title .. "Kiosk")
	local base = Kit.part(m, { name = "Base", size = Vector3.new(12, 1.2, 8), cf = CFrame.new(pos + Vector3.new(0, 0.6, 0)), color = DARK, material = Enum.Material.DiamondPlate })
	Kit.part(m, { name = "Counter", size = Vector3.new(10, 3.6, 2.4), cf = CFrame.new(pos + Vector3.new(0, 3, -1.6)), color = color, material = Enum.Material.SmoothPlastic })
	Kit.part(m, { name = "CounterTop", size = Vector3.new(10.6, 0.4, 3), cf = CFrame.new(pos + Vector3.new(0, 4.9, -1.6)), color = DARK, material = Enum.Material.Metal })
	for _, x in ipairs({ -5.2, 5.2 }) do
		Kit.part(m, { name = "Post", size = Vector3.new(0.6, 9, 0.6), cf = CFrame.new(pos + Vector3.new(x, 5.7, -2.6)), color = DARK, material = Enum.Material.Metal })
	end
	local awning = Kit.part(m, { name = "Awning", shape = "Wedge", size = Vector3.new(11.6, 1.6, 4.6), cf = CFrame.new(pos + Vector3.new(0, 10.6, -1.2)) * CFrame.Angles(0, math.pi, 0), color = color, material = Enum.Material.Fabric })
	signBoard(m, CFrame.new(pos + Vector3.new(0, 8.1, -2.7)), Vector3.new(10, 3.4, 0.4), title, nil, { 255, 255, 255 })
	local screen = Kit.part(m, { name = "Screen", size = Vector3.new(3.4, 2.2, 0.3), cf = CFrame.new(pos + Vector3.new(0, 6.2, -1.6)) * CFrame.Angles(-0.25, 0, 0), color = { 60, 200, 255 }, material = Enum.Material.Neon })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	prompt:SetAttribute("Panel", panel)
	base:SetAttribute("Panel", panel)
	return m, prompt
end

local function stormTower(parent, pos)
	local m = Kit.model(parent, "StormTower")
	Kit.cylinder(m, { name = "Plinth", height = 2, diameter = 22, cf = CFrame.new(pos + Vector3.new(0, 1, 0)), color = DARK, material = Enum.Material.DiamondPlate })
	hazardStripe(m, CFrame.new(pos + Vector3.new(0, 2.1, 10.2)), 16, 1.4, 8)
	Kit.cylinder(m, { name = "Mast", height = 46, diameter = 3, cf = CFrame.new(pos + Vector3.new(0, 25, 0)), color = { 210, 214, 224 }, material = Enum.Material.Metal })
	for i = 1, 4 do
		local y = 8 + i * 9
		Kit.cylinder(m, { name = "Collar", height = 0.8, diameter = 4.4, cf = CFrame.new(pos + Vector3.new(0, y, 0)), color = (i % 2 == 0) and HAZARD_Y or DARK, material = Enum.Material.Metal })
	end
	-- siren horns
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local hp = pos + Vector3.new(0, 40, 0) + dir * 3.2
		Kit.part(m, { name = "Horn", size = Vector3.new(2.6, 2.6, 4), cf = CFrame.lookAt(hp, hp + dir), color = { 220, 60, 50 }, material = Enum.Material.SmoothPlastic })
		Kit.part(m, { name = "HornMouth", size = Vector3.new(2.0, 2.0, 0.2), cf = CFrame.lookAt(hp + dir * 2.05, hp + dir * 3), color = { 30, 30, 35 }, material = Enum.Material.SmoothPlastic })
	end
	-- anemometer (client spins it via Orbit)
	local hubY = 49
	local hub = Kit.cylinder(m, { name = "AnemoHub", height = 1, diameter = 1.4, cf = CFrame.new(pos + Vector3.new(0, hubY, 0)), color = DARK, material = Enum.Material.Metal })
	local anemo = Kit.model(m, "Anemometer")
	local aroot = Kit.part(anemo, { name = "Root", size = Vector3.new(0.5, 0.5, 0.5), cf = CFrame.new(pos + Vector3.new(0, hubY + 0.6, 0)), transparency = 1, collide = false })
	anemo.PrimaryPart = aroot
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local armPos = pos + Vector3.new(0, hubY + 0.6, 0) + dir * 2
		local arm = Kit.part(anemo, { name = "Arm", size = Vector3.new(0.3, 0.3, 4), cf = CFrame.lookAt(armPos, armPos + dir), color = DARK, material = Enum.Material.Metal, collide = false })
		arm:SetAttribute("Orbit", 2.2)
		local cup = Kit.ball(anemo, { name = "Cup", diameter = 1.4, cf = CFrame.new(armPos + dir * 2), color = HAZARD_Y, material = Enum.Material.SmoothPlastic, collide = false })
		cup:SetAttribute("Orbit", 2.2)
	end
	anemo:AddTag("Animated")
	-- event screen (client writes the countdown into it)
	local screen = Kit.part(m, { name = "EventScreen", size = Vector3.new(18, 7, 0.6), cf = CFrame.new(pos + Vector3.new(0, 30, 2.2)), color = { 20, 22, 30 }, material = Enum.Material.SmoothPlastic })
	local sg = Instance.new("SurfaceGui")
	sg.Name = "EventGui"
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Brightness = 2
	sg.Parent = screen
	Kit.text(sg, { name = "Title", text = "NEXT CHAOS FRENZY", size = UDim2.new(1, 0, 0.4, 0), color = { 255, 90, 220 }, font = Enum.Font.LuckiestGuy })
	Kit.text(sg, { name = "Timer", text = "5:00", size = UDim2.new(1, 0, 0.6, 0), position = UDim2.new(0, 0, 0.4, 0), color = { 255, 255, 255 }, font = Enum.Font.LuckiestGuy })
	screen:AddTag("EventScreen")
	local front = sg:Clone()
	front.Face = Enum.NormalId.Front
	front.Parent = screen
	return m
end

local function tree(parent, pos, scale, leafColor)
	scale = scale or 1
	local m = Kit.model(parent, "Tree")
	Kit.cylinder(m, { name = "Trunk", height = 7 * scale, diameter = 1.4 * scale, cf = CFrame.new(pos + Vector3.new(0, 3.5 * scale, 0)), color = { 110, 75, 50 }, material = Enum.Material.Wood })
	local leaf = leafColor or { 80, 170, 70 }
	Kit.ball(m, { name = "Leaves", diameter = 7 * scale, cf = CFrame.new(pos + Vector3.new(0, 9 * scale, 0)), color = leaf, material = Enum.Material.Grass })
	Kit.ball(m, { name = "Leaves", diameter = 5 * scale, cf = CFrame.new(pos + Vector3.new(2 * scale, 7.5 * scale, 1 * scale)), color = Kit.shade(leaf, 0.9), material = Enum.Material.Grass })
	Kit.ball(m, { name = "Leaves", diameter = 4.6 * scale, cf = CFrame.new(pos + Vector3.new(-1.8 * scale, 7.8 * scale, -1.2 * scale)), color = Kit.shade(leaf, 1.08), material = Enum.Material.Grass })
	return m
end
MapBuilder.tree = tree

local function bench(parent, cf)
	Kit.part(parent, { name = "BenchSeat", size = Vector3.new(6, 0.5, 2), cf = cf * CFrame.new(0, 1.6, 0), color = { 170, 110, 60 }, material = Enum.Material.WoodPlanks })
	Kit.part(parent, { name = "BenchBack", size = Vector3.new(6, 1.6, 0.4), cf = cf * CFrame.new(0, 2.6, 0.8), color = { 170, 110, 60 }, material = Enum.Material.WoodPlanks })
	for _, x in ipairs({ -2.6, 2.6 }) do
		Kit.part(parent, { name = "BenchLeg", size = Vector3.new(0.4, 1.4, 1.8), cf = cf * CFrame.new(x, 0.9, 0), color = DARK, material = Enum.Material.Metal })
	end
end

local function planter(parent, pos, size)
	Kit.part(parent, { name = "Planter", size = Vector3.new(size.X, 1.6, size.Z), cf = CFrame.new(pos + Vector3.new(0, 1.0, 0)), color = { 150, 152, 162 }, material = Enum.Material.Concrete })
	Kit.part(parent, { name = "PlanterSoil", size = Vector3.new(size.X - 1, 0.3, size.Z - 1), cf = CFrame.new(pos + Vector3.new(0, 1.85, 0)), color = { 90, 150, 60 }, material = Enum.Material.Grass })
end

local function buildHub(root)
	local hub = Kit.model(root, "Hub")
	local c = Config.World.HubCenter
	local size = Config.World.HubSize
	local cx, cz = c[1], c[3]
	local hubZ0, hubZ1 = cz - size[2] / 2, cz + size[2] / 2
	-- foundation & plaza
	Kit.part(hub, { name = "Ground", size = Vector3.new(size[1], 4, size[2]), cf = CFrame.new(cx, -2, cz), color = { 120, 170, 90 }, material = Enum.Material.Grass })
	Kit.part(hub, { name = "Plaza", size = Vector3.new(150, 0.4, size[2] - 10), cf = CFrame.new(0, 0.2, cz), color = CONCRETE, material = Enum.Material.Concrete })
	-- plaza tile bands (alternate tones, readable scale)
	for i = 0, 18 do
		if i % 2 == 0 then
			Kit.part(hub, { name = "TileBand", size = Vector3.new(150, 0.42, 10), cf = CFrame.new(0, 0.21, hubZ0 + 10 + i * 20), color = { 182, 184, 194 }, material = Enum.Material.Concrete })
		end
	end
	-- central avenue running the full hub toward the route
	Kit.part(hub, { name = "Avenue", size = Vector3.new(W.PathWidth + 6, 0.5, hubZ1 - (hubZ0 + 40)), cf = CFrame.new(0, 0.25, (hubZ1 + hubZ0 + 40) / 2), color = { 70, 72, 82 }, material = Enum.Material.Asphalt })
	for z = hubZ0 + 50, hubZ1 - 20, 16 do
		Kit.part(hub, { name = "Dash", size = Vector3.new(0.8, 0.52, 7), cf = CFrame.new(0, 0.26, z), color = { 255, 255, 255 }, material = Enum.Material.SmoothPlastic })
	end
	for i = 0, 2 do
		Kit.part(hub, { name = "Arrow", shape = "Wedge", size = Vector3.new(8, 0.3, 5), cf = CFrame.new(0, 0.66, hubZ1 - 34 + i * 9) * CFrame.Angles(math.pi / 2, math.pi, 0), color = HAZARD_Y, material = Enum.Material.SmoothPlastic, collide = false })
	end
	hazardStripe(hub, CFrame.new(0, 0.52, hubZ1 - 6), W.PathWidth + 6, 3, 10)

	-- a colored walkway from the avenue to each base (in the base's own color)
	local BaseBuilder = require(script.Parent:WaitForChild("BaseBuilder"))
	for i, slot in ipairs(Config.Bases.Slots) do
		local col = BaseBuilder.SLOT_COLORS[(i - 1) % #BaseBuilder.SLOT_COLORS + 1]
		local x0 = W.PathWidth / 2 + 3
		local x1 = math.abs(slot.x) - Config.Bases.Size / 2 - 2
		local len = x1 - x0
		local sx = (slot.x > 0) and 1 or -1
		Kit.part(hub, { name = "Walkway", size = Vector3.new(len, 0.46, 12), cf = CFrame.new(sx * (x0 + len / 2), 0.23, slot.z), color = col, material = Enum.Material.SmoothPlastic })
		Kit.part(hub, { name = "WalkwayEdge", size = Vector3.new(len, 0.48, 1), cf = CFrame.new(sx * (x0 + len / 2), 0.24, slot.z - 6.5), color = Kit.shade(col, 0.6), material = Enum.Material.SmoothPlastic })
		Kit.part(hub, { name = "WalkwayEdge", size = Vector3.new(len, 0.48, 1), cf = CFrame.new(sx * (x0 + len / 2), 0.24, slot.z + 6.5), color = Kit.shade(col, 0.6), material = Enum.Material.SmoothPlastic })
		-- slot number marker at the avenue end
		local marker = Kit.cylinder(hub, { name = "SlotMarker", height = 0.5, diameter = 7, cf = CFrame.new(sx * (x0 + 4), 0.3, slot.z), color = col, material = Enum.Material.Neon })
		marker.CanCollide = false
	end

	-- landscaping between walkways
	local rng = seededRng(77)
	local gaps = { -195, -105, -15, 75, 150 }
	for _, z in ipairs(gaps) do
		for side = -1, 1, 2 do
			planter(hub, Vector3.new(side * 50, 0.4, z), Vector3.new(22, 0, 14))
			tree(hub, Vector3.new(side * 44, 2, z), 0.8 + rng(0, 0.2))
			tree(hub, Vector3.new(side * 56, 2, z + 2), 0.7 + rng(0, 0.2), { 100, 185, 80 })
			bench(hub, CFrame.new(side * 30, 0.4, z) * CFrame.Angles(0, side > 0 and -math.pi / 2 or math.pi / 2, 0))
		end
	end
	-- lamps & zone-colored flags along the avenue
	for i = 0, 7 do
		local z = hubZ0 + 60 + i * 42
		for side = -1, 1, 2 do
			local x = side * (W.PathWidth / 2 + 6)
			Kit.cylinder(hub, { name = "LampPost", height = 12, diameter = 0.6, cf = CFrame.new(x, 6, z), color = DARK, material = Enum.Material.Metal })
			local bulb = Kit.part(hub, { name = "Lamp", size = Vector3.new(1.6, 1, 1.6), cf = CFrame.new(x, 12.4, z), color = { 255, 240, 200 }, material = Enum.Material.Neon })
			Kit.light(bulb, { 255, 230, 190 }, 22, 1.2)
			local zone = Config.Zones[(i % #Config.Zones) + 1]
			local zc = zone.sky.fog
			Kit.part(hub, { name = "Banner", size = Vector3.new(0.2, 4, 2.4), cf = CFrame.new(x, 9, z + 1.4), color = zc, material = Enum.Material.Fabric, collide = false })
		end
	end

	-- landmarks: storm tower at the far end, kiosks between the first base rows
	stormTower(hub, Vector3.new(0, 0, hubZ0 + 30))
	local _, indexPrompt = kiosk(hub, Vector3.new(-40, 0.4, -105), "DISASTER INDEX", { 150, 80, 230 }, "Index")
	local _, shopPrompt = kiosk(hub, Vector3.new(40, 0.4, -105), "UPGRADES", { 50, 190, 90 }, "Shop")

	-- neutral fallback spawn (players are moved to their base on spawn)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "FallbackSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.6, 8)
	spawn.CFrame = CFrame.new(0, 0.3, 40)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = hub

	-- perimeter fence
	for side = -1, 1, 2 do
		Kit.part(hub, { name = "Fence", size = Vector3.new(1, 5, size[2]), cf = CFrame.new(side * (size[1] / 2 - 0.5), 2.5, cz), color = DARK, material = Enum.Material.Metal })
	end
	Kit.part(hub, { name = "Fence", size = Vector3.new(size[1], 5, 1), cf = CFrame.new(0, 2.5, hubZ0 + 0.5), color = DARK, material = Enum.Material.Metal })
	for side = -1, 1, 2 do
		-- front fence leaves the route gap open
		local w = size[1] / 2 - (W.PathWidth / 2 + 7)
		Kit.part(hub, { name = "Fence", size = Vector3.new(w, 5, 1), cf = CFrame.new(side * (W.PathWidth / 2 + 7 + w / 2), 2.5, hubZ1 - 0.5), color = DARK, material = Enum.Material.Metal })
	end
	for i = 1, 14 do
		local side = (i % 2 == 0) and 1 or -1
		tree(hub, Vector3.new(side * (size[1] / 2 - 6), 0, hubZ0 + 10 + i * 26 + rng(-4, 4)), 1 + rng(-0.1, 0.25))
	end
	return { model = hub, indexPrompt = indexPrompt, shopPrompt = shopPrompt }
end

---------------------------------------------------------------------------
-- Zone gate + nest + boundaries
---------------------------------------------------------------------------
local function rarityLine(zone)
	local parts = {}
	for _, coreId in ipairs(zone.cores) do
		local c = Config.Cores[coreId]
		local col = Config.Rarities[c.rarity].color
		table.insert(parts, string.format('<font color="rgb(%d,%d,%d)">%s</font>', col[1], col[2], col[3], c.name))
	end
	return table.concat(parts, "  •  ")
end

local function buildGate(folder, index, zone, palette)
	local z0 = WorldLayout.zoneStartZ(index)
	local m = Kit.model(folder, "Gate")
	local accent = palette and palette.accent or { 255, 255, 255 }
	local stone = palette and palette.gate or DARK
	local half = W.PathWidth / 2 + 5
	for _, x in ipairs({ -half, half }) do
		Kit.part(m, { name = "Pillar", size = Vector3.new(6, 30, 6), cf = CFrame.new(x, 15, z0), color = stone, material = palette and palette.gateMaterial or Enum.Material.Slate })
		local cap = Kit.part(m, { name = "Cap", size = Vector3.new(7, 2, 7), cf = CFrame.new(x, 31, z0), color = accent, material = Enum.Material.Neon })
		Kit.light(cap, accent, 24, 1.4)
	end
	local header = Kit.part(m, { name = "Header", size = Vector3.new(half * 2 + 6, 9, 2), cf = CFrame.new(0, 26, z0), color = stone, material = palette and palette.gateMaterial or Enum.Material.Slate })
	local sg = Instance.new("SurfaceGui")
	sg.Name = "GateGui"
	sg.Face = Enum.NormalId.Front -- Front = -Z, facing players arriving from the hub
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 28
	sg.LightInfluence = 0
	sg.Brightness = 1.3
	sg.Parent = header
	-- the pillars hide the outer 6 studs of each end, so text stays in the middle 70%
	Kit.text(sg, { name = "Index", text = "ZONE " .. index, size = UDim2.new(0.7, 0, 0.18, 0), position = UDim2.new(0.15, 0, 0.02, 0), color = accent })
	Kit.text(sg, { name = "ZoneName", text = string.upper(zone.name), size = UDim2.new(0.7, 0, 0.42, 0), position = UDim2.new(0.15, 0, 0.18, 0), color = { 255, 255, 255 }, font = Enum.Font.LuckiestGuy })
	local req = zone.speedReq > 0 and ("⚡ " .. Util.formatNumber(zone.speedReq) .. " SPEED TO STEAL") or "⚡ NO SPEED NEEDED"
	Kit.text(sg, { name = "Requirement", text = req, size = UDim2.new(0.7, 0, 0.2, 0), position = UDim2.new(0.15, 0, 0.6, 0), color = { 255, 230, 90 } })
	Kit.text(sg, { name = "Cores", text = rarityLine(zone), size = UDim2.new(0.68, 0, 0.16, 0), position = UDim2.new(0.16, 0, 0.82, 0), rich = true })
	header:SetAttribute("ZoneIndex", index)
	header:AddTag("ZoneGate")
	return m
end

local function buildNest(folder, index, zone, palette)
	local center = v3(WorldLayout.nestCenter(index))
	local m = Kit.model(folder, "Nest")
	local rimColor = palette and palette.nest or { 90, 90, 100 }
	local glow = palette and palette.accent or { 255, 255, 255 }
	Kit.cylinder(m, { name = "NestFloor", height = 0.6, diameter = Config.Spawning.NestRadius * 2 + 16, cf = CFrame.new(center + Vector3.new(0, 0.3, 0)), color = rimColor, material = palette and palette.nestMaterial or Enum.Material.Slate })
	Kit.cylinder(m, { name = "NestRing", height = 0.66, diameter = Config.Spawning.NestRadius * 2 + 2, cf = CFrame.new(center + Vector3.new(0, 0.31, 0)), color = glow, material = Enum.Material.Neon, transparency = 0.35 })
	Kit.cylinder(m, { name = "NestInner", height = 0.7, diameter = Config.Spawning.NestRadius * 2 - 3, cf = CFrame.new(center + Vector3.new(0, 0.33, 0)), color = rimColor, material = palette and palette.nestMaterial or Enum.Material.Slate })
	local points = {}
	for i, p in ipairs(WorldLayout.nestPoints(index)) do
		local pos = v3(p)
		local plinth = Kit.cylinder(m, { name = "Plinth" .. i, height = 2.2, diameter = 4.2, cf = CFrame.new(pos + Vector3.new(0, 1.1, 0)), color = Kit.shade(rimColor, 0.8), material = Enum.Material.Basalt })
		Kit.cylinder(m, { name = "PlinthGlow", height = 0.25, diameter = 4.5, cf = CFrame.new(pos + Vector3.new(0, 2.25, 0)), color = glow, material = Enum.Material.Neon, collide = false })
		table.insert(points, pos + Vector3.new(0, 4.6, 0))
	end
	return center, points
end

local function buildBoundaries(root)
	local total = #Config.Zones * W.ZoneLength
	local zMid = W.RouteStartZ + total / 2
	local inv = Kit.model(root, "Boundaries")
	for side = -1, 1, 2 do
		local wall = Kit.part(inv, { name = "Wall", size = Vector3.new(2, 120, total + 40), cf = CFrame.new(side * (W.ZoneWidth / 2 + 1), 60, zMid), transparency = 1, castShadow = false })
		wall.CanQuery = false
	end
	local endWall = Kit.part(inv, { name = "EndWall", size = Vector3.new(W.ZoneWidth + 4, 120, 2), cf = CFrame.new(0, 60, W.RouteStartZ + total + 1), transparency = 1, castShadow = false })
	endWall.CanQuery = false
	-- connector between hub and zone 1
	Kit.part(root, { name = "RouteLink", size = Vector3.new(W.PathWidth + 6, 4, 30), cf = CFrame.new(0, -2, W.RouteStartZ - 10), color = { 70, 72, 82 }, material = Enum.Material.Asphalt })
end

---------------------------------------------------------------------------
function MapBuilder.build()
	local existing = workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	setupLighting()
	local root = Kit.model(workspace, "World")
	local refs = { root = root, zones = {} }
	refs.hub = buildHub(root)
	buildBoundaries(root)

	local zonesRoot = Kit.folder(root, "Zones")
	for i, zone in ipairs(Config.Zones) do
		local folder = Kit.model(zonesRoot, zone.id)
		local builder = ZonesFolder:FindFirstChild(zone.id) or ZonesFolder:FindFirstChild("Generic")
		local build = require(builder)
		local z0 = WorldLayout.zoneStartZ(i)
		local ctx = {
			folder = folder,
			index = i,
			zone = zone,
			z0 = z0,
			z1 = z0 + W.ZoneLength,
			length = W.ZoneLength,
			width = W.ZoneWidth,
			pathWidth = W.PathWidth,
			nest = v3(WorldLayout.nestCenter(i)),
			nestRadius = Config.Spawning.NestRadius,
			rng = seededRng(1000 + i * 17),
			Kit = Kit,
			tree = tree,
		}
		local ok, result = pcall(build, ctx)
		if not ok then
			warn("[MapBuilder] zone builder " .. zone.id .. " failed: " .. tostring(result))
			result = nil
		end
		local palette = type(result) == "table" and result.palette or nil
		local gate = buildGate(folder, i, zone, palette)
		local nestCenter, points = buildNest(folder, i, zone, palette)
		refs.zones[i] = { folder = folder, gate = gate, nestCenter = nestCenter, nestPoints = points, palette = palette }
	end
	-- scenery beyond the playable strip (decorative; never allowed to break the world)
	local okB, errB = pcall(function()
		require(script.Parent:WaitForChild("Backdrop")).build(root, seededRng(4242))
	end)
	if not okB then
		warn("[MapBuilder] backdrop failed: " .. tostring(errB))
	end
	return refs
end

return MapBuilder
