--[[
	BaseBuilder — the physical player base: a "storm shelter lab" on a raised
	concrete pad with walls on three sides, open front toward the avenue,
	incubator pods along the back, display pedestals in the middle, a treadmill,
	an upgrade terminal, a shield (lock) button, an owner sign and decor that
	unlocks as the base is upgraded.

	Local frame: origin = base center at ground level, +X = toward the avenue.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local WorldLayout = require(Shared.Logic.WorldLayout)
local Kit = require(Shared.Models.Kit)

local BaseBuilder = {}

BaseBuilder.FLOOR_TOP = 1

local CONCRETE = { 188, 190, 198 }
local TRIM = { 255, 196, 40 }
local DARK = { 44, 48, 60 }
local METAL = { 150, 156, 170 }
local PLATE = { 120, 124, 136 }

local SLOT_COLORS = {
	{ 255, 90, 90 },
	{ 255, 170, 60 },
	{ 255, 230, 80 },
	{ 110, 220, 100 },
	{ 70, 200, 255 },
	{ 90, 120, 255 },
	{ 190, 100, 255 },
	{ 255, 110, 200 },
}
BaseBuilder.SLOT_COLORS = SLOT_COLORS

local function baseCF(slotIndex)
	local slot = Config.Bases.Slots[slotIndex]
	return CFrame.new(slot.x, 0, slot.z) * CFrame.Angles(0, slot.face == 1 and 0 or math.pi, 0)
end
BaseBuilder.baseCF = baseCF

local function worldPos(t, yOffset)
	return Vector3.new(t[1], t[2] + (yOffset or 0), t[3])
end

local function lockLabel(adornee, text)
	local bb = Kit.billboard(adornee, { name = "LockLabel", size = UDim2.new(0, 120, 0, 44), offset = Vector3.new(0, 3.2, 0), maxDistance = 60 })
	Kit.text(bb, { name = "Text", text = text, color = { 230, 230, 240 } })
	return bb
end

local function buildPod(model, pos, slotColor)
	local m = Kit.model(model, "Pod")
	local root = Kit.cylinder(m, { name = "PodBase", height = 1.4, diameter = 6, cf = CFrame.new(pos + Vector3.new(0, 0.7, 0)), color = DARK, material = Enum.Material.DiamondPlate })
	Kit.cylinder(m, { name = "PodRing", height = 0.3, diameter = 6.3, cf = CFrame.new(pos + Vector3.new(0, 1.3, 0)), color = slotColor, material = Enum.Material.Neon, collide = false })
	local glass = Kit.cylinder(m, { name = "Capsule", height = 7, diameter = 4.6, cf = CFrame.new(pos + Vector3.new(0, 4.9, 0)), color = { 200, 235, 255 }, material = Enum.Material.Glass, transparency = 0.65, castShadow = false })
	glass.CanCollide = false
	Kit.cylinder(m, { name = "Cap", height = 1, diameter = 5.4, cf = CFrame.new(pos + Vector3.new(0, 8.9, 0)), color = METAL, material = Enum.Material.Metal })
	local fill = Kit.cylinder(m, { name = "Fill", height = 0.05, diameter = 4.2, cf = CFrame.new(pos + Vector3.new(0, 1.45, 0)), color = { 120, 255, 200 }, material = Enum.Material.Neon, transparency = 0.45, collide = false, castShadow = false })
	-- pipes into the back wall
	Kit.part(m, { name = "Pipe", size = Vector3.new(0.7, 0.7, 4), cf = CFrame.new(pos + Vector3.new(0, 8.2, 0)) * CFrame.new(0, 0, 0), color = METAL, material = Enum.Material.Metal, collide = false })
	local anchor = CFrame.new(pos + Vector3.new(0, 4.6, 0))
	m.PrimaryPart = root
	return { model = m, root = root, fill = fill, capsule = glass, anchor = anchor, basePos = pos }
end

local function buildPedestal(model, pos)
	local m = Kit.model(model, "Pedestal")
	local root = Kit.cylinder(m, { name = "Plinth", height = 1.6, diameter = 6.4, cf = CFrame.new(pos + Vector3.new(0, 0.8, 0)), color = { 230, 232, 238 }, material = Enum.Material.Marble })
	local ring = Kit.cylinder(m, { name = "RarityRing", height = 0.25, diameter = 6.7, cf = CFrame.new(pos + Vector3.new(0, 1.5, 0)), color = { 90, 90, 100 }, material = Enum.Material.SmoothPlastic, collide = false })
	Kit.cylinder(m, { name = "Top", height = 0.2, diameter = 5.6, cf = CFrame.new(pos + Vector3.new(0, 1.7, 0)), color = { 60, 64, 78 }, material = Enum.Material.SmoothPlastic, collide = false })
	m.PrimaryPart = root
	return { model = m, root = root, ring = ring, top = CFrame.new(pos + Vector3.new(0, 1.8, 0)), basePos = pos }
end

local function buildTreadmill(model, slotIndex, cf)
	local m = Kit.model(model, "Treadmill")
	local center = worldPos(WorldLayout.treadmillPosition(slotIndex), BaseBuilder.FLOOR_TOP)
	local rot = cf.Rotation
	local frame = CFrame.new(center) * rot
	Kit.part(m, { name = "Deck", size = Vector3.new(18, 0.8, 8), cf = frame * CFrame.new(0, 0.4, 0), color = DARK, material = Enum.Material.Metal })
	local belt = Kit.part(m, { name = "Belt", size = Vector3.new(16, 0.3, 6), cf = frame * CFrame.new(0, 0.95, 0), color = { 30, 30, 34 }, material = Enum.Material.Rubber })
	for _, z in ipairs({ -3.4, 3.4 }) do
		Kit.part(m, { name = "Led", size = Vector3.new(16, 0.2, 0.3), cf = frame * CFrame.new(0, 1, z), color = TRIM, material = Enum.Material.Neon, collide = false })
		Kit.part(m, { name = "Rail", size = Vector3.new(6, 0.35, 0.35), cf = frame * CFrame.new(5.5, 4, z), color = METAL, material = Enum.Material.Metal })
		Kit.part(m, { name = "RailPost", size = Vector3.new(0.35, 3.4, 0.35), cf = frame * CFrame.new(8.2, 2.5, z), color = METAL, material = Enum.Material.Metal })
	end
	-- console at the front end, with a screen the server writes speed info to
	local console = Kit.part(m, { name = "Console", size = Vector3.new(1, 5, 7), cf = frame * CFrame.new(9, 2.5, 0), color = DARK, material = Enum.Material.Metal })
	local screen = Kit.part(m, { name = "Screen", size = Vector3.new(0.2, 2.6, 6), cf = frame * CFrame.new(8.45, 4, 0), color = { 15, 20, 30 }, material = Enum.Material.SmoothPlastic, collide = false })
	local sg = Instance.new("SurfaceGui")
	sg.Name = "TreadGui"
	sg.Face = Enum.NormalId.Left
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Brightness = 2
	sg.Parent = screen
	Kit.text(sg, { name = "Title", text = "TREADMILL", size = UDim2.new(1, 0, 0.35, 0), color = TRIM, font = Enum.Font.LuckiestGuy })
	Kit.text(sg, { name = "Gain", text = "+5 SPEED / STEP", size = UDim2.new(1, 0, 0.6, 0), position = UDim2.new(0, 0, 0.38, 0), color = { 255, 255, 255 } })
	-- the screen faces the runner, so a floating label makes the treadmill easy to spot from the base entrance
	local tag = Kit.billboard(console, { name = "TreadmillLabel", size = UDim2.new(12, 0, 3, 0), offset = Vector3.new(0, 4.5, 0), maxDistance = 90 })
	Kit.text(tag, { name = "Text", text = "🏃 TREADMILL", color = TRIM, font = Enum.Font.LuckiestGuy })
	-- conveyor: the belt pushes toward local -X; running toward the console keeps you in place
	belt.AssemblyLinearVelocity = rot:VectorToWorldSpace(Vector3.new(-Config.Speed.BeltSpeed, 0, 0))
	return { model = m, belt = belt, frame = frame, console = console, gainLabel = sg:FindFirstChild("Gain") }
end

local function buildTerminal(model, pos, rot, title, color, icon)
	local m = Kit.model(model, title .. "Terminal")
	local cf = CFrame.new(pos) * rot
	local pad = Kit.part(m, { name = "Pad", size = Vector3.new(6, 0.4, 6), cf = cf * CFrame.new(0, 0.2, 0), color = color, material = Enum.Material.Neon, transparency = 0.3 })
	Kit.part(m, { name = "Stand", size = Vector3.new(1.6, 4.2, 2.6), cf = cf * CFrame.new(-1.8, 2.3, 0), color = DARK, material = Enum.Material.Metal })
	local screen = Kit.part(m, { name = "Screen", size = Vector3.new(0.3, 2.2, 3.4), cf = cf * CFrame.new(-1.0, 4.4, 0) * CFrame.Angles(0, 0, -0.3), color = color, material = Enum.Material.Neon })
	-- sized in studs (not pixels) so the two terminal labels, 14 studs apart, never overlap at a distance
	local bb = Kit.billboard(screen, { name = "Label", size = UDim2.new(10, 0, 3, 0), offset = Vector3.new(0, 2.8, 0), maxDistance = 70 })
	Kit.text(bb, { name = "Text", text = icon .. " " .. title, color = { 255, 255, 255 }, font = Enum.Font.LuckiestGuy })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = title
	prompt.ActionText = "Use"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	return { model = m, pad = pad, prompt = prompt, label = bb }
end

function BaseBuilder.build(parent, slotIndex)
	local cf = baseCF(slotIndex)
	local rot = cf.Rotation
	local size = Config.Bases.Size
	local half = size / 2
	local slotColor = SLOT_COLORS[(slotIndex - 1) % #SLOT_COLORS + 1]
	local model = Kit.model(parent, "Base" .. slotIndex)
	model:SetAttribute("Slot", slotIndex)
	local function at(lx, ly, lz)
		return cf * CFrame.new(lx, ly, lz)
	end

	-- pad, floor zones and trim
	Kit.part(model, { name = "Pad", size = Vector3.new(size, BaseBuilder.FLOOR_TOP, size), cf = at(0, BaseBuilder.FLOOR_TOP / 2, 0), color = CONCRETE, material = Enum.Material.Concrete })
	Kit.part(model, { name = "PodDeck", size = Vector3.new(24, 0.1, size - 6), cf = at(-21, BaseBuilder.FLOOR_TOP + 0.05, 0), color = PLATE, material = Enum.Material.DiamondPlate })
	Kit.part(model, { name = "DisplayDeck", size = Vector3.new(30, 0.1, size - 10), cf = at(10, BaseBuilder.FLOOR_TOP + 0.05, 0), color = { 210, 212, 220 }, material = Enum.Material.Marble })
	-- front hazard edge
	for i = 1, 12 do
		local seg = size / 12
		Kit.part(model, { name = "Hazard", size = Vector3.new(2, 0.14, seg), cf = at(half - 1, BaseBuilder.FLOOR_TOP + 0.07, -half + seg * (i - 0.5)), color = (i % 2 == 0) and DARK or TRIM, material = Enum.Material.SmoothPlastic })
	end
	-- ramp/step down to the avenue
	Kit.part(model, { name = "Step", shape = "Wedge", size = Vector3.new(size, BaseBuilder.FLOOR_TOP, 3), cf = at(half + 1.5, BaseBuilder.FLOOR_TOP / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), color = CONCRETE, material = Enum.Material.Concrete })

	-- walls: back (tall) + sides
	local wallH = 7
	Kit.part(model, { name = "BackWall", size = Vector3.new(2, 14, size), cf = at(-half + 1, BaseBuilder.FLOOR_TOP + 7, 0), color = { 160, 164, 176 }, material = Enum.Material.Concrete })
	Kit.part(model, { name = "BackTrim", size = Vector3.new(2.2, 1, size), cf = at(-half + 1, BaseBuilder.FLOOR_TOP + 14.2, 0), color = slotColor, material = Enum.Material.SmoothPlastic })
	for _, side in ipairs({ -1, 1 }) do
		Kit.part(model, { name = "SideWall", size = Vector3.new(size - 14, wallH, 2), cf = at(-7, BaseBuilder.FLOOR_TOP + wallH / 2, side * (half - 1)), color = { 170, 174, 186 }, material = Enum.Material.Concrete })
		Kit.part(model, { name = "SideTrim", size = Vector3.new(size - 14, 0.8, 2.2), cf = at(-7, BaseBuilder.FLOOR_TOP + wallH + 0.4, side * (half - 1)), color = TRIM, material = Enum.Material.SmoothPlastic })
		-- shield pylons at the front corners
		local pylon = Kit.part(model, { name = "Pylon", size = Vector3.new(3, 12, 3), cf = at(half - 2, BaseBuilder.FLOOR_TOP + 6, side * (half - 2)), color = DARK, material = Enum.Material.Metal })
		local emitter = Kit.part(model, { name = "PylonEmitter", size = Vector3.new(3.2, 1.2, 3.2), cf = at(half - 2, BaseBuilder.FLOOR_TOP + 11, side * (half - 2)), color = slotColor, material = Enum.Material.Neon })
		Kit.light(emitter, slotColor, 18, 1)
	end
	-- bunker door on the back wall
	Kit.part(model, { name = "BunkerDoor", size = Vector3.new(0.6, 8, 10), cf = at(-half + 2.2, BaseBuilder.FLOOR_TOP + 4, 0), color = { 90, 96, 110 }, material = Enum.Material.DiamondPlate })
	Kit.part(model, { name = "DoorStripe", size = Vector3.new(0.7, 1, 10), cf = at(-half + 2.25, BaseBuilder.FLOOR_TOP + 7.2, 0), color = TRIM, material = Enum.Material.SmoothPlastic })

	-- owner sign above the back wall (readable from the avenue)
	local signPart = Kit.part(model, { name = "OwnerSign", size = Vector3.new(1, 7, 34), cf = at(-half + 1, BaseBuilder.FLOOR_TOP + 19, 0), color = DARK, material = Enum.Material.Metal })
	Kit.part(model, { name = "SignFrame", size = Vector3.new(1.2, 7.6, 34.6), cf = at(-half + 0.9, BaseBuilder.FLOOR_TOP + 19, 0), color = slotColor, material = Enum.Material.SmoothPlastic })
	local sg = Instance.new("SurfaceGui")
	sg.Name = "OwnerGui"
	sg.Face = Enum.NormalId.Right -- local +X: faces the avenue
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 25
	sg.LightInfluence = 0
	sg.Brightness = 1.4
	sg.Parent = signPart
	local ownerText = Kit.text(sg, { name = "Owner", text = "EMPTY BASE", size = UDim2.new(1, -20, 0.62, 0), position = UDim2.new(0, 10, 0.04, 0), color = { 255, 255, 255 }, font = Enum.Font.LuckiestGuy })
	local infoText = Kit.text(sg, { name = "Info", text = "Waiting for a storm chaser...", size = UDim2.new(1, -20, 0.3, 0), position = UDim2.new(0, 10, 0.66, 0), color = TRIM })
	for _, side in ipairs({ -1, 1 }) do
		Kit.part(model, { name = "SignPost", size = Vector3.new(1, 6, 1), cf = at(-half + 1, BaseBuilder.FLOOR_TOP + 14, side * 14), color = DARK, material = Enum.Material.Metal })
	end

	-- shield wall (visual only; the server enforces it)
	local shield = Kit.part(model, { name = "ShieldWall", size = Vector3.new(0.6, 14, size - 4), cf = at(half - 2, BaseBuilder.FLOOR_TOP + 7, 0), color = slotColor, material = Enum.Material.ForceField, transparency = 1, collide = false, castShadow = false, query = false })

	-- pods & pedestals
	local pods = {}
	for i = 1, Config.Bases.MaxPods do
		local p = buildPod(model, worldPos(WorldLayout.podPosition(slotIndex, i), BaseBuilder.FLOOR_TOP), slotColor)
		p.lock = lockLabel(p.root, "🔒")
		pods[i] = p
	end
	local pedestals = {}
	for i = 1, Config.Bases.MaxPedestals do
		local p = buildPedestal(model, worldPos(WorldLayout.pedestalPosition(slotIndex, i), BaseBuilder.FLOOR_TOP))
		p.lock = lockLabel(p.root, "🔒")
		pedestals[i] = p
	end

	local treadmill = buildTreadmill(model, slotIndex, cf)
	local upgradeTerm = buildTerminal(model, cf * Vector3.new(31, BaseBuilder.FLOOR_TOP, -14), rot, "UPGRADES", { 60, 200, 90 }, "⬆")
	upgradeTerm.prompt.ActionText = "Open Shop"
	local shieldPos = WorldLayout.shieldButtonPosition(slotIndex)
	local shieldTerm = buildTerminal(model, worldPos(shieldPos, BaseBuilder.FLOOR_TOP), rot, "LOCK BASE", { 70, 170, 255 }, "🛡")
	shieldTerm.prompt.ActionText = "Lock"
	shieldTerm.prompt.HoldDuration = 0.4

	-- tier decor (revealed as the base improves)
	local tiers = {}
	local function decor(tier, part)
		tiers[tier] = tiers[tier] or {}
		table.insert(tiers[tier], { part = part, transparency = part.Transparency })
		part.Transparency = 1
		part.CanCollide = false
	end
	for _, side in ipairs({ -1, 1 }) do
		decor(2, Kit.part(model, { name = "RodTower", size = Vector3.new(1.4, 22, 1.4), cf = at(-half + 3, BaseBuilder.FLOOR_TOP + 11, side * (half - 3)), color = METAL, material = Enum.Material.Metal }))
		decor(2, Kit.ball(model, { name = "RodTip", diameter = 2.2, cf = at(-half + 3, BaseBuilder.FLOOR_TOP + 22.5, side * (half - 3)), color = slotColor, material = Enum.Material.Neon }))
	end
	decor(3, Kit.cylinder(model, { name = "DishStand", height = 6, diameter = 1.4, cf = at(-half + 6, BaseBuilder.FLOOR_TOP + 17, -12), color = METAL, material = Enum.Material.Metal }))
	decor(3, Kit.cylinder(model, { name = "Dish", height = 0.6, diameter = 8, cf = at(-half + 6, BaseBuilder.FLOOR_TOP + 20.5, -12) * CFrame.Angles(0, 0, 0.6), color = { 235, 235, 240 }, material = Enum.Material.SmoothPlastic }))
	for _, side in ipairs({ -1, 1 }) do
		decor(4, Kit.part(model, { name = "NeonTrim", size = Vector3.new(size - 14, 0.4, 2.3), cf = at(-7, BaseBuilder.FLOOR_TOP + wallH + 1, side * (half - 1)), color = slotColor, material = Enum.Material.Neon }))
	end
	decor(4, Kit.part(model, { name = "BackNeon", size = Vector3.new(2.4, 0.5, size), cf = at(-half + 1, BaseBuilder.FLOOR_TOP + 14.9, 0), color = slotColor, material = Enum.Material.Neon }))

	-- floating owner billboard over the entrance (visible from far)
	local bbAnchor = Kit.part(model, { name = "OwnerAnchor", size = Vector3.new(1, 1, 1), cf = at(half - 2, BaseBuilder.FLOOR_TOP + 16, 0), transparency = 1, collide = false, query = false })
	local bb = Kit.billboard(bbAnchor, { name = "OwnerBillboard", size = UDim2.new(0, 260, 0, 70), offset = Vector3.new(0, 0, 0), maxDistance = 400 })
	local bbName = Kit.text(bb, { name = "Name", text = "", size = UDim2.new(1, 0, 0.6, 0), color = slotColor, font = Enum.Font.LuckiestGuy })
	local bbInfo = Kit.text(bb, { name = "Info", text = "", size = UDim2.new(1, 0, 0.4, 0), position = UDim2.new(0, 0, 0.6, 0), color = { 255, 255, 255 } })

	return {
		slot = slotIndex,
		model = model,
		cf = cf,
		color = slotColor,
		pods = pods,
		pedestals = pedestals,
		treadmill = treadmill,
		upgradeTerminal = upgradeTerm,
		shieldTerminal = shieldTerm,
		shieldWall = shield,
		ownerText = ownerText,
		infoText = infoText,
		billboardName = bbName,
		billboardInfo = bbInfo,
		tiers = tiers,
	}
end

return BaseBuilder
