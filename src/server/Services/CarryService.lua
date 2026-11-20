--[[
	CarryService — everything about cores in transit.

	An item is either
	  { kind = "world",  entity = <CoreSpawnService entity>, coreId, mutation, zoneIndex }
	  { kind = "player", victim = Player, podSlot = n, coreId, mutation, zoneIndex, progress }
	Ownership only transfers on delivery (carrier inside their own base).
	Any interruption returns every item to its source:
	  death, character removal, leaving, falling, guardian tag, owner tag,
	  and suspected teleport (movement faster than physically possible).
	If a robbery victim leaves, their in-transit items are cancelled first so
	nothing can be duplicated.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local CarryLogic = require(Shared.Logic.CarryLogic)
local Kit = require(Shared.Models.Kit)
local CoreModels = require(Shared.Models.CoreModels)
local Remotes = require(Shared.Remotes)

local CarryService = { Name = "CarryService" }

local S
local carriers = {} -- [player] = { items = {}, lastPos = Vector3?, visuals = {} }

local DROP_TEXT = {
	died = "You were knocked out — the core returned home.",
	guardian = "The guardian got you! The core went back to its nest.",
	caught = "Caught by the owner! The core went back.",
	teleport = "Movement rejected — the core went back.",
	fell = "You fell — the core returned.",
	left = "",
	lost = "You lost the core.",
	victimLeft = "The owner left — that core vanished.",
}

function CarryService:Init(registry)
	S = registry
end

local function state(player)
	local st = carriers[player]
	if not st then
		st = { items = {}, lastPos = nil, visuals = {} }
		carriers[player] = st
	end
	return st
end

function CarryService:getItems(player)
	local st = carriers[player]
	return st and st.items or {}
end

function CarryService:count(player)
	local st = carriers[player]
	return st and #st.items or 0
end

function CarryService:isCarrying(player)
	return self:count(player) > 0
end

function CarryService:walkMultiplier(player)
	local st = carriers[player]
	if not st or #st.items == 0 then
		return 1
	end
	local ids = {}
	for _, it in ipairs(st.items) do
		table.insert(ids, it.coreId)
	end
	return CarryLogic.walkMultiplier(CarryLogic.totalWeight(ids))
end

function CarryService:resetTracking(player)
	local st = carriers[player]
	if st then
		st.lastPos = nil
		st.budget = nil
	end
end

function CarryService:_rebuildVisuals(player)
	local st = state(player)
	for _, v in ipairs(st.visuals) do
		v:Destroy()
	end
	st.visuals = {}
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	for i, it in ipairs(st.items) do
		local m = CoreModels.build(it.coreId, it.mutation, 0.9)
		m.Name = "CarriedCore"
		m:PivotTo(hrp.CFrame * CFrame.new(0, 4.4 + (i - 1) * 2.8, 0))
		Kit.setCollide(m, false)
		Kit.setMassless(m)
		Kit.setAnchored(m, false)
		local w = Instance.new("WeldConstraint")
		w.Part0 = hrp
		w.Part1 = m.PrimaryPart
		w.Parent = m.PrimaryPart
		Kit.weldAll(m, m.PrimaryPart)
		m.Parent = char
		table.insert(st.visuals, m)
	end
	player:SetAttribute("Carrying", #st.items)
end

function CarryService:_changed(player)
	self:_rebuildVisuals(player)
	S.SpeedService:refreshWalkSpeed(player)
	S.PlayerDataService:markDirty(player)
end

function CarryService:add(player, item)
	local st = state(player)
	if #st.items == 0 then
		-- a fresh carry starts with a full movement budget; a budget drained by an
		-- earlier teleport rejection must not drop this one on its first step
		st.budget = nil
	end
	table.insert(st.items, item)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	st.lastPos = hrp and hrp.Position or nil
	self:_changed(player)
	Remotes.get("Announce"):FireClient(player, {
		kind = "carry",
		title = "RUN HOME!",
		subtitle = "Get " .. Config.Cores[item.coreId].name .. " back to your base",
		color = Config.Rarities[Config.Cores[item.coreId].rarity].color,
	})
end

local function returnItem(item)
	if item.kind == "world" then
		S.CoreSpawnService:returnToNest(item.entity)
	elseif item.kind == "player" then
		S.IncubatorService:cancelTransit(item.victim, item.podSlot)
	end
end

function CarryService:dropAll(player, reason)
	local st = carriers[player]
	if not st or #st.items == 0 then
		return 0
	end
	local n = #st.items
	for _, it in ipairs(st.items) do
		returnItem(it)
	end
	st.items = {}
	st.lastPos = nil
	if player.Parent == Players then
		self:_changed(player)
		local text = DROP_TEXT[reason or "lost"]
		if text and text ~= "" then
			S.PlayerDataService:notify(player, text, "error")
		end
	else
		for _, v in ipairs(st.visuals) do
			v:Destroy()
		end
		st.visuals = {}
	end
	return n
end

-- Remove items stolen from `victim` (victim is leaving). Thief loses them.
function CarryService:cancelFromVictim(victim)
	for thief, st in pairs(carriers) do
		local kept = {}
		local removed = 0
		for _, it in ipairs(st.items) do
			if it.kind == "player" and it.victim == victim then
				removed = removed + 1
				S.IncubatorService:cancelTransit(victim, it.podSlot)
			else
				table.insert(kept, it)
			end
		end
		if removed > 0 then
			st.items = kept
			if thief.Parent == Players then
				self:_changed(thief)
				S.PlayerDataService:notify(thief, DROP_TEXT.victimLeft, "error")
			end
		end
	end
end

function CarryService:deliver(player)
	local st = carriers[player]
	if not st or #st.items == 0 then
		return 0
	end
	local data = S.PlayerDataService:get(player)
	if not data then
		return 0
	end
	local delivered = {}
	for _, it in ipairs(st.items) do
		local entry
		if it.kind == "world" then
			if S.CoreSpawnService:consume(it.entity) then
				entry = { c = it.coreId, m = it.mutation, z = it.zoneIndex, p = 0 }
				data.stats.stolen = data.stats.stolen + 1
			end
		elseif it.kind == "player" then
			entry = S.IncubatorService:completeTransit(it.victim, it.podSlot)
			if entry then
				data.stats.stolen = data.stats.stolen + 1
				data.stats.robbed = data.stats.robbed + 1
				S.PlayerDataService:notify(it.victim, player.DisplayName .. " stole your " .. Config.Cores[entry.c].name .. "!", "error")
			end
		end
		if entry then
			S.IncubatorService:receive(player, entry)
			table.insert(delivered, entry)
		end
	end
	st.items = {}
	st.lastPos = nil
	self:_changed(player)
	if #delivered > 0 then
		local first = Config.Cores[delivered[1].c]
		Remotes.get("Announce"):FireClient(player, {
			kind = "delivered",
			title = "DELIVERED!",
			subtitle = (#delivered > 1) and (#delivered .. " cores secured") or (first.name .. " secured — incubating!"),
			color = { 120, 255, 140 },
		})
	end
	return #delivered
end

function CarryService:_tick(dt)
	for player, st in pairs(carriers) do
		if #st.items > 0 then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if player.Parent ~= Players then
				self:dropAll(player, "left")
			elseif not hrp or not hum then
				self:dropAll(player, "lost")
			elseif hum.Health <= 0 then
				self:dropAll(player, "died")
			else
				local pos = hrp.Position
				local maxWalk = S.SpeedService:maxWalkFor(player)
				local teleported = false
				if st.lastPos then
					local dx, dz = pos.X - st.lastPos.X, pos.Z - st.lastPos.Z
					st.budget, teleported = CarryLogic.spendBudget(st.budget or CarryLogic.newBudget(maxWalk), math.sqrt(dx * dx + dz * dz), dt, maxWalk)
				else
					st.budget = CarryLogic.newBudget(maxWalk)
				end
				if teleported then
					warn("[Carry] teleport suspected for " .. player.Name)
					self:dropAll(player, "teleport")
				else
					st.lastPos = pos
					if S.BaseService:inOwnBase(player, pos) then
						self:deliver(player)
					else
						-- owners can tag thieves carrying their cores
						for _, it in ipairs(st.items) do
							if it.kind == "player" and it.victim.Parent == Players then
								local vhrp = it.victim.Character and it.victim.Character:FindFirstChild("HumanoidRootPart")
								if vhrp and (vhrp.Position - pos).Magnitude <= Config.Carry.TagRange then
									self:dropAll(player, "caught")
									S.PlayerDataService:notify(it.victim, "You caught the thief! Core recovered.", "success")
									break
								end
							end
						end
					end
				end
			end
		end
	end
end

function CarryService:Start()
	RunService.Heartbeat:Connect(function(dt)
		self:_tick(dt)
	end)
	S.PlayerDataService.Releasing:Connect(function(player)
		self:cancelFromVictim(player)
		self:dropAll(player, "left")
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:dropAll(player, "left")
		carriers[player] = nil
	end)
	local function hookCharacter(player, char)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then
			hum.Died:Connect(function()
				self:dropAll(player, "died")
			end)
		end
	end
	local function hookPlayer(player)
		player.CharacterRemoving:Connect(function()
			self:dropAll(player, "died")
		end)
		player.CharacterAdded:Connect(function(char)
			hookCharacter(player, char)
		end)
		if player.Character then
			task.spawn(hookCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hookPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		hookPlayer(p)
	end
end

return CarryService
