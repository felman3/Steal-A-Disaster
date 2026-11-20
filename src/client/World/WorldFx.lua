--[[
	WorldFx — client-only world presentation:
	  * Animator: bob/spin/orbit for models tagged "Animated" (cores, disasters,
	    the storm tower anemometer). Only animates what's near the camera.
	  * Atmosphere: per-zone lighting mood + Chaos Frenzy tint.
	  * Prompt filter: hide Steal prompts on your own base and Sell prompts on
	    other players' bases; mark cores you can't steal yet.
	  * Waypoint: a beam and a HOME marker pointing to your base while carrying.
	  * Event screens: countdown text on the storm tower.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local Util = require(Shared.Util)
local Kit = require(Shared.Models.Kit)

local State = require(script.Parent.Parent.State)

local WorldFx = {}

local ANIM_RANGE = 170

---------------------------------------------------------------------------
-- Animator
---------------------------------------------------------------------------
local animated = {} -- [model] = rec

local function register(model)
	if animated[model] or not model:IsA("Model") then
		return
	end
	local root = model.PrimaryPart
	local pivot = model:GetPivot()
	local rec = {
		model = model,
		pivot = pivot,
		bob = model:GetAttribute("AnimBob") or 0,
		spin = model:GetAttribute("AnimSpin") or 0,
		phase = (pivot.Position.X * 0.37 + pivot.Position.Z * 0.11) % 6.28,
		parts = {},
		cframes = {},
	}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(rec.parts, {
				part = d,
				offset = pivot:ToObjectSpace(d.CFrame),
				orbit = d:GetAttribute("Orbit") or 0,
				selfSpin = d:GetAttribute("SelfSpin") or 0,
			})
		end
	end
	if rec.bob == 0 and rec.spin == 0 then
		local any = false
		for _, p in ipairs(rec.parts) do
			if p.orbit ~= 0 or p.selfSpin ~= 0 then
				any = true
			end
		end
		if not any then
			return
		end
	end
	animated[model] = rec
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			animated[model] = nil
		end
	end)
	if root == nil then
		return
	end
end

local function animate(t, camPos)
	local parts, cframes = {}, {}
	for model, rec in pairs(animated) do
		if (rec.pivot.Position - camPos).Magnitude < ANIM_RANGE then
			local base = rec.pivot * CFrame.new(0, math.sin(t * 2 + rec.phase) * rec.bob, 0) * CFrame.Angles(0, t * rec.spin, 0)
			for _, p in ipairs(rec.parts) do
				local cf = base
				if p.orbit ~= 0 then
					cf = cf * CFrame.Angles(0, t * p.orbit, 0)
				end
				cf = cf * p.offset
				if p.selfSpin ~= 0 then
					cf = cf * CFrame.Angles(0, t * p.selfSpin, 0)
				end
				table.insert(parts, p.part)
				table.insert(cframes, cf)
			end
		end
	end
	if #parts > 0 then
		local ok = pcall(function()
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end)
		if not ok then
			for i, part in ipairs(parts) do
				part.CFrame = cframes[i]
			end
		end
	end
end

---------------------------------------------------------------------------
-- Atmosphere
---------------------------------------------------------------------------
local HUB_SKY = { ambient = { 120, 120, 135 }, fog = { 190, 215, 255 }, fogEnd = 1200, tint = { 255, 255, 255 }, clock = 14.2 }

local function applySky(sky, frenzy)
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(Lighting, info, {
		Ambient = Util.rgb(sky.ambient),
		OutdoorAmbient = Util.rgb(sky.ambient):Lerp(Color3.new(1, 1, 1), 0.25),
		FogColor = Util.rgb(sky.fog),
		FogEnd = sky.fogEnd,
		ClockTime = sky.clock,
	}):Play()
	local grade = Lighting:FindFirstChild("ZoneGrade")
	if grade then
		local tint = Util.rgb(sky.tint)
		if frenzy then
			tint = tint:Lerp(Color3.fromRGB(255, 120, 240), 0.45)
		end
		TweenService:Create(grade, info, { TintColor = tint, Saturation = frenzy and 0.45 or 0.18 }):Play()
	end
	local atm = Lighting:FindFirstChild("Atmosphere")
	if atm then
		TweenService:Create(atm, info, { Color = Util.rgb(sky.fog), Density = math.clamp(260 / sky.fogEnd, 0.2, 0.6) }):Play()
	end
end

---------------------------------------------------------------------------
-- Prompt filter
---------------------------------------------------------------------------
local function filterPrompt(prompt, player)
	local function apply()
		local mySlot = player:GetAttribute("BaseSlot")
		if prompt.Name == "PodStealPrompt" then
			if prompt:GetAttribute("BaseSlot") == mySlot and prompt.Enabled then
				prompt.Enabled = false
			end
		elseif prompt:GetAttribute("OwnerOnly") == true then
			-- purchase prompts (Speed Boost, Instant Hatch) appear only on your own base;
			-- range (not Enabled, which the server drives) hides them elsewhere
			local mine = mySlot ~= nil and prompt:GetAttribute("BaseSlot") == mySlot
			prompt.MaxActivationDistance = mine and (prompt:GetAttribute("Range") or 8) or 0
		elseif prompt.Name == "SellPrompt" then
			if prompt:GetAttribute("OwnerOnly") ~= player.UserId and prompt.Enabled then
				prompt.Enabled = false
			end
		elseif prompt.Name == "StealPrompt" then
			local req = prompt:GetAttribute("ReqSpeed") or 0
			local snap = State.get()
			local speed = snap and snap.speed or 0
			if speed < req then
				prompt.ActionText = "🔒 Need ⚡" .. Util.formatNumber(req)
			else
				prompt.ActionText = "Steal"
			end
		end
	end
	apply()
	prompt:GetPropertyChangedSignal("Enabled"):Connect(apply)
	return apply
end

local function colorCoreLabel(bb)
	local req = bb:GetAttribute("ReqSpeed")
	local label = bb:FindFirstChild("Requirement")
	if not req or not label then
		return
	end
	local snap = State.get()
	local speed = snap and snap.speed or 0
	if req <= 0 then
		label.Text = ""
	elseif speed >= req then
		label.Text = "✅ You can steal this"
		label.TextColor3 = Color3.fromRGB(120, 255, 120)
	else
		label.Text = "🔒 Need ⚡" .. Util.formatNumber(req)
		label.TextColor3 = Color3.fromRGB(255, 110, 110)
	end
end

---------------------------------------------------------------------------
function WorldFx.mount()
	local player = Players.LocalPlayer

	-- animator
	for _, m in ipairs(CollectionService:GetTagged("Animated")) do
		register(m)
	end
	CollectionService:GetInstanceAddedSignal("Animated"):Connect(function(m)
		task.defer(register, m)
	end)

	-- prompts and labels
	local filters = {}
	local function onDescendant(d)
		if d:IsA("ProximityPrompt") then
			filters[d] = filterPrompt(d, player)
		elseif d:IsA("BillboardGui") and d.Name == "CoreLabel" then
			task.defer(colorCoreLabel, d)
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		onDescendant(d)
	end
	workspace.DescendantAdded:Connect(onDescendant)
	workspace.DescendantRemoving:Connect(function(d)
		filters[d] = nil
	end)
	local lastSpeed = -1
	State.Changed:Connect(function(snap)
		if snap.speed ~= lastSpeed then
			lastSpeed = snap.speed
			for prompt, apply in pairs(filters) do
				if prompt.Name == "StealPrompt" then
					apply()
				end
			end
			local cores = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Cores")
			if cores then
				for _, d in ipairs(cores:GetDescendants()) do
					if d:IsA("BillboardGui") and d.Name == "CoreLabel" then
						colorCoreLabel(d)
					end
				end
			end
		end
	end)
	player:GetAttributeChangedSignal("BaseSlot"):Connect(function()
		for prompt, apply in pairs(filters) do
			apply()
		end
	end)

	-- atmosphere
	local currentZone = 0
	local frenzy = false
	local function refreshSky()
		local sky = HUB_SKY
		if currentZone >= 1 and Config.Zones[currentZone] then
			sky = Config.Zones[currentZone].sky
		end
		applySky(sky, frenzy)
	end
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		currentZone = player:GetAttribute("Zone") or 0
		refreshSky()
	end)
	ReplicatedStorage:GetAttributeChangedSignal("EventPhase"):Connect(function()
		local f = ReplicatedStorage:GetAttribute("EventPhase") == "Frenzy"
		if f ~= frenzy then
			frenzy = f
			refreshSky()
		end
	end)

	-- waypoint home
	local beam, homeMarker, a0, a1, anchorPart
	local function clearWaypoint()
		if beam then
			beam:Destroy()
			beam = nil
		end
		if a0 then
			a0:Destroy()
			a0 = nil
		end
		if anchorPart then
			anchorPart:Destroy()
			anchorPart = nil
		end
	end
	local function setWaypoint(snap)
		local carrying = #snap.carried > 0
		if not carrying or snap.baseSlot <= 0 then
			clearWaypoint()
			return
		end
		if beam then
			return
		end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		local s = Config.Bases.Slots[snap.baseSlot]
		anchorPart = Kit.part(workspace, { name = "HomeWaypoint", size = Vector3.new(1, 1, 1), cf = CFrame.new(s.x, 6, s.z), transparency = 1, collide = false, query = false })
		a1 = Instance.new("Attachment")
		a1.Parent = anchorPart
		a0 = Instance.new("Attachment")
		a0.Name = "WaypointAttachment"
		a0.Parent = hrp
		beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(Color3.fromRGB(120, 255, 140))
		beam.Transparency = NumberSequence.new(0.35)
		beam.Width0 = 0.8
		beam.Width1 = 0.8
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Segments = 1
		beam.Parent = anchorPart
		homeMarker = Kit.billboard(anchorPart, { name = "HomeMarker", size = UDim2.new(0, 120, 0, 50), offset = Vector3.new(0, 8, 0), alwaysOnTop = true, maxDistance = 5000 })
		Kit.text(homeMarker, { name = "Text", text = "🏠 HOME", color = { 120, 255, 140 }, font = Enum.Font.LuckiestGuy })
	end
	State.Changed:Connect(setWaypoint)

	-- frame loop
	local t = 0
	local screenAcc = 0
	RunService.RenderStepped:Connect(function(dt)
		t = t + dt
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		animate(t, camPos)
		screenAcc = screenAcc + dt
		if screenAcc >= 0.25 then
			screenAcc = 0
			local now = workspace:GetServerTimeNow()
			local phase = ReplicatedStorage:GetAttribute("EventPhase") or "Normal"
			local text
			if phase == "Frenzy" then
				text = "NOW! " .. Util.formatTime(math.max(0, (ReplicatedStorage:GetAttribute("FrenzyEndsAt") or now) - now))
			else
				text = Util.formatTime(math.max(0, (ReplicatedStorage:GetAttribute("NextRefreshAt") or now) - now))
			end
			for _, screen in ipairs(CollectionService:GetTagged("EventScreen")) do
				for _, gui in ipairs(screen:GetChildren()) do
					if gui:IsA("SurfaceGui") then
						local timer = gui:FindFirstChild("Timer")
						if timer then
							timer.Text = text
						end
					end
				end
			end
		end
	end)
	return { animated = animated }
end

-- test hook
function WorldFx._animated()
	return animated
end

return WorldFx
