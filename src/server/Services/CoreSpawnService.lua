--[[
	CoreSpawnService — the world's temporary Disaster Core opportunities.

	Each zone has a nest with N spawn points. A point holds at most one core
	entity. Entities are owned by the world until delivered:
	  state "Nest"    → visible on its plinth with a Steal prompt
	  state "Carried" → model removed; a carrier holds a reference
	Delivery consumes the entity and schedules a respawn. A drop (death,
	guardian, teleport, disconnect) returns it to its exact point.

	Every refresh (EventService) rerolls all uncarried cores with Frenzy odds
	and spawns Chaos Cores that vanish when the frenzy ends unless grabbed.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local SpawnLogic = require(Shared.Logic.SpawnLogic)
local EconomyLogic = require(Shared.Logic.EconomyLogic)
local Util = require(Shared.Util)
local Kit = require(Shared.Models.Kit)
local CoreModels = require(Shared.Models.CoreModels)

local CoreSpawnService = { Name = "CoreSpawnService" }

local S
local folder
local points = {} -- [zoneIndex] = { { pos, entity, respawnAt } }
local entities = {} -- [uid] = entity
local nextUid = 0
local random = Random.new()
local WORLD_CORE_SCALE = 1.6

local function rng()
	return random:NextNumber()
end

function CoreSpawnService:Init(registry)
	S = registry
	folder = Instance.new("Folder")
	folder.Name = "Cores"
	folder.Parent = workspace:WaitForChild("World")
	for i = 1, #Config.Zones do
		local refs = S.ZoneService:zoneRefs(i)
		points[i] = {}
		for j, pos in ipairs(refs.nestPoints) do
			points[i][j] = { pos = pos, entity = nil, respawnAt = 0 }
		end
	end
end

local function coreLabel(entity)
	local def = Config.Cores[entity.coreId]
	local rarity = Config.Rarities[def.rarity]
	local zone = Config.Zones[entity.zoneIndex]
	local root = entity.model.PrimaryPart
	local bb = Kit.billboard(root, { name = "CoreLabel", size = UDim2.new(0, 200, 0, 78), offset = Vector3.new(0, 4.8, 0), maxDistance = 90 })
	bb:SetAttribute("ReqSpeed", zone.speedReq)
	local mutText = ""
	if entity.mutation then
		mutText = string.upper(entity.mutation) .. " "
	end
	local m = entity.mutation and Config.Mutations[entity.mutation]
	if m then
		Kit.text(bb, { name = "Mutation", text = mutText, size = UDim2.new(1, 0, 0.24, 0), color = m.color })
	end
	Kit.text(bb, { name = "Name", text = def.name, size = UDim2.new(1, 0, 0.32, 0), position = UDim2.new(0, 0, 0.22, 0), color = { 255, 255, 255 }, font = Enum.Font.LuckiestGuy })
	Kit.text(bb, { name = "Rarity", text = string.upper(def.rarity) .. "  •  " .. Util.formatMoney(EconomyLogic.coreValue(entity.coreId, entity.mutation, entity.zoneIndex)), size = UDim2.new(1, 0, 0.22, 0), position = UDim2.new(0, 0, 0.53, 0), color = rarity.color })
	local req = zone.speedReq > 0 and ("⚡ " .. Util.formatNumber(zone.speedReq) .. " to steal") or ""
	Kit.text(bb, { name = "Requirement", text = req, size = UDim2.new(1, 0, 0.2, 0), position = UDim2.new(0, 0, 0.77, 0), color = { 255, 230, 90 } })
end

local function spawnModel(entity)
	local m = CoreModels.build(entity.coreId, entity.mutation, WORLD_CORE_SCALE)
	m:PivotTo(CFrame.new(entity.position))
	m:SetAttribute("Uid", entity.uid)
	m:SetAttribute("Zone", entity.zoneIndex)
	m.Parent = folder
	m:AddTag("Animated")
	entity.model = m
	coreLabel(entity)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal"
	prompt.ObjectText = Config.Cores[entity.coreId].name
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = m.PrimaryPart
	prompt:SetAttribute("ReqSpeed", Config.Zones[entity.zoneIndex].speedReq)
	prompt.Triggered:Connect(function(player)
		if S.StealService then
			S.StealService:tryStealWorld(player, entity)
		end
	end)
	entity.prompt = prompt
end

function CoreSpawnService:_create(zoneIndex, pointIndex, position, opts)
	opts = opts or {}
	local zone = Config.Zones[zoneIndex]
	local frenzy = opts.frenzy == true
	local coreId = opts.coreId or SpawnLogic.pickCore(zone, rng, frenzy)
	local mutMult = frenzy and Config.Events.FrenzyMutationMult or 1
	local mutation = opts.mutation
	if mutation == nil and not opts.noMutation then
		mutation = SpawnLogic.rollMutation(rng, mutMult)
	end
	nextUid = nextUid + 1
	local entity = {
		uid = nextUid,
		coreId = coreId,
		mutation = mutation,
		zoneIndex = zoneIndex,
		pointIndex = pointIndex,
		position = position,
		state = "Nest",
		carrier = nil,
		chaos = opts.chaos == true,
	}
	entities[entity.uid] = entity
	spawnModel(entity)
	if pointIndex then
		points[zoneIndex][pointIndex].entity = entity
	end
	return entity
end

function CoreSpawnService:_destroyModel(entity)
	if entity.model then
		entity.model:Destroy()
		entity.model = nil
		entity.prompt = nil
	end
end

function CoreSpawnService:_remove(entity)
	self:_destroyModel(entity)
	entities[entity.uid] = nil
	if entity.pointIndex then
		local p = points[entity.zoneIndex][entity.pointIndex]
		if p.entity == entity then
			p.entity = nil
			p.respawnAt = os.clock() + Config.Spawning.RespawnDelay
		end
	end
end

function CoreSpawnService:get(uid)
	return entities[uid]
end

function CoreSpawnService:points(zoneIndex)
	return points[zoneIndex]
end

function CoreSpawnService:entitiesInZone(zoneIndex)
	local out = {}
	for _, e in pairs(entities) do
		if e.zoneIndex == zoneIndex then
			table.insert(out, e)
		end
	end
	return out
end

-- Called by StealService after validation.
function CoreSpawnService:take(entity, player)
	if entity.state ~= "Nest" or entities[entity.uid] ~= entity then
		return false
	end
	entity.state = "Carried"
	entity.carrier = player
	self:_destroyModel(entity)
	return true
end

-- Carrier lost the core: put it back where it came from.
function CoreSpawnService:returnToNest(entity)
	if entities[entity.uid] ~= entity or entity.state ~= "Carried" then
		return
	end
	entity.state = "Nest"
	entity.carrier = nil
	if entity.expired then
		-- chaos core whose frenzy already ended: it fizzles out
		self:_remove(entity)
		return
	end
	spawnModel(entity)
end

-- Delivered: the world entity is gone; schedule a respawn on its point.
function CoreSpawnService:consume(entity)
	if entities[entity.uid] ~= entity then
		return false
	end
	self:_remove(entity)
	return true
end

function CoreSpawnService:refreshAll(frenzy)
	local created = {}
	for zi, list in ipairs(points) do
		for pi, p in ipairs(list) do
			local e = p.entity
			if e and e.state == "Nest" then
				self:_remove(e)
				p.entity = nil
			end
			if not p.entity then
				table.insert(created, self:_create(zi, pi, p.pos, { frenzy = frenzy }))
			end
		end
	end
	return created
end

-- Tell everyone about the rarest fresh cores (Legendary+), at most two per refresh,
-- so there is a reason to travel and race for them.
CoreSpawnService.ALERT_MIN_RANK = 5
function CoreSpawnService:_alertRare(entities)
	local rare = {}
	for _, e in ipairs(entities or {}) do
		local core = Config.Cores[e.coreId]
		local rank = core and Config.Rarities[core.rarity].rank or 0
		if rank >= self.ALERT_MIN_RANK then
			table.insert(rare, { e = e, rank = rank })
		end
	end
	table.sort(rare, function(a, b)
		return a.rank > b.rank
	end)
	for i = 1, math.min(2, #rare) do
		local e = rare[i].e
		local core = Config.Cores[e.coreId]
		local text = "🌟 A " .. string.upper(core.rarity) .. " " .. core.name .. " appeared in " .. Config.Zones[e.zoneIndex].name .. "!"
		for _, pl in ipairs(Players:GetPlayers()) do
			S.PlayerDataService:notify(pl, text, "info")
		end
	end
	return math.min(2, #rare)
end

function CoreSpawnService:spawnChaosCores(count)
	-- prefer zones where players currently are, so the race is real
	local zonesWithPlayers = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local z = S.ZoneService:zoneOf(pl)
		if z and z >= 1 then
			table.insert(zonesWithPlayers, z)
		end
	end
	local spawned = {}
	for i = 1, count do
		local zi
		if #zonesWithPlayers > 0 then
			zi = zonesWithPlayers[(i - 1) % #zonesWithPlayers + 1]
		else
			zi = math.random(1, math.min(3, #Config.Zones))
		end
		local center = S.ZoneService:zoneRefs(zi).nestCenter
		local a = rng() * math.pi * 2
		local r = 6 + rng() * 10
		local pos = center + Vector3.new(math.cos(a) * r, 4.6, math.sin(a) * r)
		local e = self:_create(zi, nil, pos, { coreId = "ChaosCore", chaos = true, frenzy = true })
		table.insert(spawned, e)
	end
	return spawned
end

function CoreSpawnService:expireChaos()
	for _, e in pairs(entities) do
		if e.chaos then
			if e.state == "Nest" then
				self:_remove(e)
			else
				e.expired = true -- if dropped later it fizzles instead of returning
			end
		end
	end
end

function CoreSpawnService:Start()
	self:refreshAll(false)
	S.EventService.Refreshed:Connect(function()
		local fresh = self:refreshAll(true)
		self:spawnChaosCores(Config.Events.ChaosCoresPerFrenzy)
		self:_alertRare(fresh)
	end)
	S.EventService.PhaseChanged:Connect(function(new, old)
		if old == "Frenzy" then
			self:expireChaos()
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local now = os.clock()
		for zi, list in ipairs(points) do
			for pi, p in ipairs(list) do
				if not p.entity and now >= p.respawnAt then
					self:_create(zi, pi, p.pos, { frenzy = S.EventService:isFrenzy() })
				end
			end
		end
	end)
end

return CoreSpawnService
