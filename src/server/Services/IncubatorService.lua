--[[
	IncubatorService — pods at each base turn cores into disasters.

	* receive(player, entry) puts a delivered core into the first free pod, or
	  into storage (shown on the base sign) when all pods are busy.
	* Pods advance every tick at EventService:incubationRate() (x4 in Frenzy),
	  and offline time (capped) is applied on join.
	* When a pod finishes, DisasterCollectionService places the disaster on a
	  free pedestal. If none is free the pod waits in a "READY" state.
	* Visible in the world: the core floats inside the glass capsule, a neon
	  fill rises with progress, and a billboard shows name, rarity and time left.
	* Theft: beginTransit / cancelTransit / completeTransit. A pod in transit is
	  frozen and shows "STOLEN!"; ownership moves only on completeTransit.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local IncubatorLogic = require(Shared.Logic.IncubatorLogic)
local DataSchema = require(Shared.Logic.DataSchema)
local Util = require(Shared.Util)
local Kit = require(Shared.Models.Kit)
local CoreModels = require(Shared.Models.CoreModels)

local IncubatorService = { Name = "IncubatorService" }

local S
local transit = {} -- [victim] = { [podSlot] = thief }
local visuals = {} -- [player] = { [podSlot] = { model, label, ... } }
local promptsWired = false

local TICK = 0.25
local FILL_MAX = 6.6

function IncubatorService:Init(registry)
	S = registry
end

local function podsOf(player)
	local data = S.PlayerDataService:get(player)
	return data and data.pods or nil, data
end

function IncubatorService:isInTransit(player, slot)
	return transit[player] ~= nil and transit[player][slot] ~= nil
end

function IncubatorService:freePods(player)
	local data = S.PlayerDataService:get(player)
	if not data then
		return 0
	end
	return data.upgrades.Pods - #data.pods
end

function IncubatorService:hasRoom(player, incoming)
	local data = S.PlayerDataService:get(player)
	if not data then
		return false
	end
	local room = (data.upgrades.Pods - #data.pods) + (Config.Data.MaxStoredCores - #data.storage)
	return room >= (incoming or 1)
end

-- Visuals ---------------------------------------------------------------------
local function unitFor(player, slot)
	local base = S.BaseService:baseOf(player)
	return base and base.pods[slot] or nil
end

function IncubatorService:_clearVisual(player, slot)
	local v = visuals[player] and visuals[player][slot]
	if v then
		if v.model then
			v.model:Destroy()
		end
		if v.label then
			v.label:Destroy()
		end
		visuals[player][slot] = nil
	end
	local unit = unitFor(player, slot)
	if unit then
		unit.fill.Size = Vector3.new(0.05, unit.fill.Size.Y, unit.fill.Size.Z)
		unit.fill.CFrame = CFrame.new(unit.basePos + Vector3.new(0, 1.45, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		local prompt = unit.root:FindFirstChild("PodStealPrompt")
		if prompt then
			prompt.Enabled = false
		end
	end
end

function IncubatorService:_buildVisual(player, pod)
	self:_clearVisual(player, pod.s)
	local unit = unitFor(player, pod.s)
	if not unit then
		return
	end
	visuals[player] = visuals[player] or {}
	local m = CoreModels.build(pod.c, pod.m)
	m:ScaleTo(0.85)
	m:PivotTo(unit.anchor)
	m:AddTag("Animated")
	m.Parent = unit.model
	local def = Config.Cores[pod.c]
	local rarity = Config.Rarities[def.rarity]
	local bb = Kit.billboard(unit.root, { name = "PodLabel", size = UDim2.new(0, 170, 0, 74), offset = Vector3.new(0, 10.5, 0), maxDistance = 80 })
	local name = Kit.text(bb, { name = "Name", text = def.name, size = UDim2.new(1, 0, 0.34, 0), color = rarity.color, font = Enum.Font.LuckiestGuy })
	local timer = Kit.text(bb, { name = "Timer", text = "", size = UDim2.new(1, 0, 0.3, 0), position = UDim2.new(0, 0, 0.34, 0), color = { 255, 255, 255 } })
	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Size = UDim2.new(0.8, 0, 0.18, 0)
	barBg.Position = UDim2.new(0.1, 0, 0.74, 0)
	barBg.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	barBg.BorderSizePixel = 0
	barBg.Parent = bb
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(10, 10, 15)
	stroke.Parent = barBg
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.new(0, 0, 1, 0)
	bar.BackgroundColor3 = Kit.rgb(rarity.color)
	bar.BorderSizePixel = 0
	bar.Parent = barBg
	unit.fill.Color = Kit.rgb(def.colors[3])
	visuals[player][pod.s] = { model = m, label = bb, timer = timer, bar = bar, name = name }
	local prompt = unit.root:FindFirstChild("PodStealPrompt")
	if prompt then
		prompt.Enabled = true
		prompt.ObjectText = def.name
	end
	self:_updateVisual(player, pod)
end

function IncubatorService:_updateVisual(player, pod)
	local v = visuals[player] and visuals[player][pod.s]
	local unit = unitFor(player, pod.s)
	if not v or not unit then
		return
	end
	local frac = IncubatorLogic.fraction(pod)
	local h = math.max(0.05, FILL_MAX * frac)
	unit.fill.Size = Vector3.new(h, unit.fill.Size.Y, unit.fill.Size.Z)
	unit.fill.CFrame = CFrame.new(unit.basePos + Vector3.new(0, 1.45 + h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	v.bar.Size = UDim2.new(frac, 0, 1, 0)
	if self:isInTransit(player, pod.s) then
		v.timer.Text = "STOLEN! CHASE THEM!"
		v.timer.TextColor3 = Color3.fromRGB(255, 80, 80)
		v.model.Parent = nil
	else
		if v.model.Parent == nil then
			v.model.Parent = unit.model
		end
		v.timer.TextColor3 = Color3.fromRGB(255, 255, 255)
		if frac >= 1 then
			v.timer.Text = "READY • need a free pedestal"
		else
			local rate = S.EventService:incubationRate()
			local t = Util.formatTime(IncubatorLogic.remaining(pod) / rate)
			v.timer.Text = (rate > 1) and ("⚡ " .. t .. " (x" .. rate .. ")") or t
		end
	end
end

function IncubatorService:rebuildAll(player)
	local pods = podsOf(player)
	if not pods then
		return
	end
	for _, pod in ipairs(pods) do
		self:_buildVisual(player, pod)
	end
end

function IncubatorService:clearAll(player)
	if visuals[player] then
		for slot in pairs(visuals[player]) do
			self:_clearVisual(player, slot)
		end
	end
	visuals[player] = nil
end

-- Pod data --------------------------------------------------------------------
function IncubatorService:receive(player, entry)
	local data = S.PlayerDataService:get(player)
	if not data then
		return nil
	end
	local slot = DataSchema.freeSlot(data.pods, data.upgrades.Pods)
	if slot then
		local pod = { s = slot, c = entry.c, m = entry.m, z = entry.z or 1, p = entry.p or 0 }
		table.insert(data.pods, pod)
		self:_buildVisual(player, pod)
		S.PlayerDataService:markDirty(player)
		self:_tryHatch(player, pod)
		return "pod"
	end
	if #data.storage < Config.Data.MaxStoredCores then
		table.insert(data.storage, { c = entry.c, m = entry.m, z = entry.z or 1 })
		S.PlayerDataService:markDirty(player)
		S.PlayerDataService:notify(player, "All pods busy — core stored (" .. #data.storage .. " waiting).", "info")
		return "storage"
	end
	return nil
end

-- Move stored cores into free pods.
function IncubatorService:fillFromStorage(player)
	local data = S.PlayerDataService:get(player)
	if not data then
		return
	end
	while #data.storage > 0 do
		local slot = DataSchema.freeSlot(data.pods, data.upgrades.Pods)
		if not slot then
			break
		end
		local entry = table.remove(data.storage, 1)
		local pod = { s = slot, c = entry.c, m = entry.m, z = entry.z, p = 0 }
		table.insert(data.pods, pod)
		self:_buildVisual(player, pod)
	end
	S.PlayerDataService:markDirty(player)
end

function IncubatorService:_removePod(player, slot)
	local data = S.PlayerDataService:get(player)
	if not data then
		return nil
	end
	local pod, idx = DataSchema.findBySlot(data.pods, slot)
	if not pod then
		return nil
	end
	table.remove(data.pods, idx)
	self:_clearVisual(player, slot)
	S.PlayerDataService:markDirty(player)
	return pod
end

function IncubatorService:_tryHatch(player, pod)
	if self:isInTransit(player, pod.s) then
		return false
	end
	if IncubatorLogic.fraction(pod) < 1 then
		return false
	end
	local ok = S.DisasterCollectionService:place(player, pod)
	if ok then
		self:_removePod(player, pod.s)
		self:fillFromStorage(player)
	end
	return ok
end

function IncubatorService:tryHatchAll(player)
	local pods = podsOf(player)
	if not pods then
		return
	end
	local list = {}
	for _, p in ipairs(pods) do
		table.insert(list, p)
	end
	for _, p in ipairs(list) do
		self:_tryHatch(player, p)
	end
end

function IncubatorService:onCapacityChanged(player)
	self:fillFromStorage(player)
	self:tryHatchAll(player)
end

-- Theft -------------------------------------------------------------------------
function IncubatorService:beginTransit(victim, slot, thief)
	local data = S.PlayerDataService:get(victim)
	if not data then
		return nil
	end
	local pod = DataSchema.findBySlot(data.pods, slot)
	if not pod or self:isInTransit(victim, slot) then
		return nil
	end
	transit[victim] = transit[victim] or {}
	transit[victim][slot] = thief
	self:_updateVisual(victim, pod)
	local unit = unitFor(victim, slot)
	local prompt = unit and unit.root:FindFirstChild("PodStealPrompt")
	if prompt then
		prompt.Enabled = false
	end
	return { c = pod.c, m = pod.m, z = pod.z, p = pod.p }
end

function IncubatorService:cancelTransit(victim, slot)
	if not transit[victim] or not transit[victim][slot] then
		return
	end
	transit[victim][slot] = nil
	local data = S.PlayerDataService:get(victim)
	local pod = data and DataSchema.findBySlot(data.pods, slot)
	if pod then
		self:_updateVisual(victim, pod)
		local unit = unitFor(victim, slot)
		local prompt = unit and unit.root:FindFirstChild("PodStealPrompt")
		if prompt then
			prompt.Enabled = true
		end
		self:_tryHatch(victim, pod)
	end
end

function IncubatorService:completeTransit(victim, slot)
	if not transit[victim] or not transit[victim][slot] then
		return nil
	end
	transit[victim][slot] = nil
	local pod = self:_removePod(victim, slot)
	if pod then
		self:fillFromStorage(victim)
		return { c = pod.c, m = pod.m, z = pod.z, p = pod.p }
	end
	return nil
end

-- Steal prompts on every pod of every base (owner check happens in StealService;
-- the client hides prompts on its own base).
function IncubatorService:_wirePrompts()
	if promptsWired then
		return
	end
	promptsWired = true
	for slot = 1, #Config.Bases.Slots do
		local base = S.BaseService:base(slot)
		for i, unit in ipairs(base.pods) do
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "PodStealPrompt"
			prompt.ActionText = "Steal"
			prompt.ObjectText = "Core"
			prompt.HoldDuration = Config.Bases.StealHoldTime
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.Enabled = false
			prompt:SetAttribute("BaseSlot", slot)
			prompt.Parent = unit.root
			prompt.Triggered:Connect(function(thief)
				S.StealService:tryStealFromBase(thief, slot, i)
			end)
		end
	end
end

function IncubatorService:Start()
	self:_wirePrompts()
	S.PlayerDataService.Loaded:Connect(function(player, data, offline)
		if offline and offline > 0 then
			for _, pod in ipairs(data.pods) do
				IncubatorLogic.advance(pod, offline, 1)
			end
		end
		self:fillFromStorage(player)
		self:rebuildAll(player)
		self:tryHatchAll(player)
	end)
	S.PlayerDataService.Releasing:Connect(function(player)
		-- any thief carrying this player's core loses it (CarryService handles the
		-- thief side); clear runtime-only state
		transit[player] = nil
		self:clearAll(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		transit[player] = nil
		self:clearAll(player)
		-- thieves who were robbing others keep nothing in transit tables here
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < TICK then
			return
		end
		local step = acc
		acc = 0
		local rate = S.EventService:incubationRate()
		for _, player in ipairs(S.PlayerDataService:loadedPlayers()) do
			local pods = podsOf(player)
			local list = {}
			for _, p in ipairs(pods) do
				table.insert(list, p)
			end
			for _, pod in ipairs(list) do
				if not self:isInTransit(player, pod.s) then
					local wasDone = IncubatorLogic.fraction(pod) >= 1
					local done = IncubatorLogic.advance(pod, step, rate)
					if done then
						self:_tryHatch(player, pod)
					end
					if not wasDone then
						self:_updateVisual(player, pod)
					end
				end
			end
		end
	end)
end

-- test hooks
function IncubatorService:_transit()
	return transit
end

return IncubatorService
