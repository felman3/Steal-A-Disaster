--[[
	DisasterCollectionService — hatched disasters on display pedestals.

	place(player, pod) turns a finished pod into a disaster on the first free
	pedestal (mutation rolled now if the core had none; Frenzy boosts it),
	records it in the Index, and refreshes income. Owners can sell a disaster
	with a hold-prompt on its pedestal to free the slot.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local EconomyLogic = require(Shared.Logic.EconomyLogic)
local MonetizationLogic = require(Shared.Logic.MonetizationLogic)
local IncubatorLogic = require(Shared.Logic.IncubatorLogic)
local DataSchema = require(Shared.Logic.DataSchema)
local RateLimiter = require(Shared.Logic.RateLimiter)
local Util = require(Shared.Util)
local Kit = require(Shared.Models.Kit)
local CoreModels = require(Shared.Models.CoreModels)
local Remotes = require(Shared.Remotes)

local okModels, DisasterModels = pcall(function()
	return require(Shared.Models.DisasterModels)
end)
if not okModels then
	DisasterModels = nil
end

local DisasterCollectionService = { Name = "DisasterCollectionService" }

local S
local visuals = {} -- [player] = { [slot] = { model, label } }
local sellLimiter
local random = Random.new()

function DisasterCollectionService:Init(registry)
	S = registry
	local rl = Config.RateLimits.Sell
	sellLimiter = RateLimiter.new(rl[1], rl[2])
end

local function buildModel(entry)
	if DisasterModels then
		local ok, m = pcall(DisasterModels.build, entry.d, entry.m)
		if ok and m then
			return m
		end
		warn("[Disasters] model build failed for " .. tostring(entry.d) .. ": " .. tostring(m))
	end
	-- fallback: an oversized core so the slot is never empty
	local coreId = Config.CoreByDisaster[entry.d]
	local m = CoreModels.build(coreId, entry.m)
	m:ScaleTo(1.4)
	return m
end

function DisasterCollectionService:_clearVisual(player, slot)
	local v = visuals[player] and visuals[player][slot]
	if v then
		v.model:Destroy()
		v.label:Destroy()
		if v.prompt then
			v.prompt:Destroy()
		end
		visuals[player][slot] = nil
	end
	local base = S.BaseService:baseOf(player)
	local ped = base and base.pedestals[slot]
	if ped then
		ped.ring.Color = Color3.fromRGB(90, 90, 100)
		ped.ring.Material = Enum.Material.SmoothPlastic
	end
end

function DisasterCollectionService:_buildVisual(player, entry)
	self:_clearVisual(player, entry.s)
	local base = S.BaseService:baseOf(player)
	local ped = base and base.pedestals[entry.s]
	if not ped then
		return
	end
	visuals[player] = visuals[player] or {}
	local def = Config.Disasters[entry.d]
	local rarity = Config.Rarities[def.rarity]
	local m = buildModel(entry)
	-- stand the model on the pedestal top, facing the avenue
	local _, size = m:GetBoundingBox()
	m:PivotTo(ped.top * base.cf.Rotation * CFrame.Angles(0, math.pi / 2, 0))
	m:AddTag("Animated")
	m.Parent = ped.model
	ped.ring.Color = Kit.rgb(rarity.color)
	ped.ring.Material = Enum.Material.Neon

	local height = math.max(4, size.Y)
	local bb = Kit.billboard(ped.root, { name = "DisasterLabel", size = UDim2.new(0, 180, 0, 70), offset = Vector3.new(0, height + 3, 0), maxDistance = 90 })
	local mut = entry.m and Config.Mutations[entry.m]
	if mut then
		Kit.text(bb, { name = "Mutation", text = string.upper(entry.m), size = UDim2.new(1, 0, 0.26, 0), color = mut.color })
	end
	Kit.text(bb, { name = "Name", text = def.name, size = UDim2.new(1, 0, 0.36, 0), position = UDim2.new(0, 0, 0.24, 0), color = rarity.color, font = Enum.Font.LuckiestGuy })
	Kit.text(bb, { name = "Income", text = self:_incomeText(player, entry), size = UDim2.new(1, 0, 0.32, 0), position = UDim2.new(0, 0, 0.62, 0), color = { 120, 255, 120 } })

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SellPrompt"
	prompt.ActionText = "Sell " .. Util.formatMoney(EconomyLogic.valueFor(entry))
	prompt.ObjectText = def.name
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt:SetAttribute("OwnerOnly", player.UserId)
	prompt.Parent = ped.root
	local slot = entry.s
	prompt.Triggered:Connect(function(who)
		if who == player then
			self:sell(player, slot)
		end
	end)
	visuals[player][entry.s] = { model = m, label = bb, prompt = prompt, entry = entry }
end

-- what this disaster actually earns for its owner (Double Cash included)
function DisasterCollectionService:_incomeText(player, entry)
	local mult = MonetizationLogic.incomeMultiplier(S.PlayerDataService:get(player))
	return Util.formatMoney(EconomyLogic.incomeFor(entry) * mult) .. "/s"
end

-- re-label every pedestal (after a pass changes the income multiplier)
function DisasterCollectionService:refreshIncomeLabels(player)
	for _, v in pairs(visuals[player] or {}) do
		local t = v.label and v.label:FindFirstChild("Income")
		if t and v.entry then
			t.Text = self:_incomeText(player, v.entry)
		end
	end
end

function DisasterCollectionService:rebuildAll(player)
	local data = S.PlayerDataService:get(player)
	if not data then
		return
	end
	for _, d in ipairs(data.disasters) do
		self:_buildVisual(player, d)
	end
end

function DisasterCollectionService:clearAll(player)
	if visuals[player] then
		for slot in pairs(visuals[player]) do
			self:_clearVisual(player, slot)
		end
	end
	visuals[player] = nil
end

function DisasterCollectionService:freeSlot(player)
	local data = S.PlayerDataService:get(player)
	if not data then
		return nil
	end
	return DataSchema.freeSlot(data.disasters, data.upgrades.Pedestals)
end

-- Place a finished pod. Returns true on success.
function DisasterCollectionService:place(player, pod)
	local data = S.PlayerDataService:get(player)
	if not data then
		return false
	end
	local slot = DataSchema.freeSlot(data.disasters, data.upgrades.Pedestals)
	if not slot then
		return false
	end
	local core = Config.Cores[pod.c]
	local mutation = IncubatorLogic.hatchMutation(pod.m, function()
		return random:NextNumber()
	end, S.EventService:mutationMult())
	local entry = { s = slot, d = core.disaster, m = mutation, z = pod.z }
	table.insert(data.disasters, entry)
	local isNew = not data.index[entry.d]
	data.index[entry.d] = true
	data.stats.hatched = data.stats.hatched + 1
	self:_buildVisual(player, entry)
	S.EconomyService:recompute(player)
	S.BaseService:refresh(player)
	S.PlayerDataService:markDirty(player)
	local def = Config.Disasters[entry.d]
	local title = isNew and "NEW DISASTER!" or "HATCHED!"
	local sub = def.name .. (mutation and (" • " .. mutation) or "") .. " • " .. Util.formatMoney(EconomyLogic.incomeFor(entry)) .. "/s"
	Remotes.get("Announce"):FireClient(player, { kind = "hatch", title = title, subtitle = sub, color = Config.Rarities[def.rarity].color, disaster = entry.d, mutation = mutation })
	return true, entry
end

function DisasterCollectionService:sell(player, slot)
	if not sellLimiter:allow(player) then
		return false
	end
	local data = S.PlayerDataService:get(player)
	if not data then
		return false
	end
	local entry, idx = DataSchema.findBySlot(data.disasters, slot)
	if not entry then
		return false
	end
	local value = EconomyLogic.valueFor(entry)
	table.remove(data.disasters, idx)
	self:_clearVisual(player, slot)
	S.EconomyService:addMoney(player, value, "sell")
	S.EconomyService:recompute(player)
	S.BaseService:refresh(player)
	S.IncubatorService:tryHatchAll(player)
	S.PlayerDataService:notify(player, "Sold " .. Config.Disasters[entry.d].name .. " for " .. Util.formatMoney(value), "success")
	return true, value
end

function DisasterCollectionService:Start()
	S.PlayerDataService.Loaded:Connect(function(player)
		self:rebuildAll(player)
		S.EconomyService:recompute(player)
		S.BaseService:refresh(player)
	end)
	S.PlayerDataService.Releasing:Connect(function(player)
		self:clearAll(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:clearAll(player)
	end)
end

return DisasterCollectionService
