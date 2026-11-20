--[[
	StealService — validates every steal attempt on the server.

	tryStealWorld(player, entity)       from a zone nest (ProximityPrompt)
	tryStealFromBase(thief, slot, pod)  an incubating core from another base

	Checks: data loaded, alive, in range (server-measured), zone Speed gate,
	carry capacity, room at home, base shield, not already in transit, rate limit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local SpeedLogic = require(Shared.Logic.SpeedLogic)
local CarryLogic = require(Shared.Logic.CarryLogic)
local WorldLayout = require(Shared.Logic.WorldLayout)
local RateLimiter = require(Shared.Logic.RateLimiter)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local StealService = { Name = "StealService" }

local S
local limiter

function StealService:Init(registry)
	S = registry
	local rl = Config.RateLimits.Generic
	limiter = RateLimiter.new(rl[1], rl[2])
end

local function aliveRoot(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then
		return nil
	end
	return hrp
end

local function deny(player, text)
	S.PlayerDataService:notify(player, text, "error")
	return false, text
end

local function commonChecks(player, data, extraIncoming)
	if not CarryLogic.canCarryMore(S.CarryService:count(player), data.upgrades.Carry) then
		return "Your hands are full! Upgrade your Backpack to carry more."
	end
	if not S.IncubatorService:hasRoom(player, S.CarryService:count(player) + (extraIncoming or 1)) then
		return "Your base is full! Free a pod or pedestal first."
	end
	return nil
end

function StealService:tryStealWorld(player, entity)
	if not limiter:allow(player) then
		return false, "rate"
	end
	local data = S.PlayerDataService:get(player)
	if not data then
		return false, "not loaded"
	end
	if not entity or entity.state ~= "Nest" or S.CoreSpawnService:get(entity.uid) ~= entity then
		return false, "gone"
	end
	local hrp = aliveRoot(player)
	if not hrp then
		return false, "dead"
	end
	if (hrp.Position - entity.position).Magnitude > Config.Carry.PickupRange then
		return false, "range"
	end
	if not SpeedLogic.canStealInZone(data.speed, entity.zoneIndex) then
		local req = Config.Zones[entity.zoneIndex].speedReq
		return deny(player, "You need ⚡" .. Util.formatNumber(req) .. " Speed to steal here. Train on your treadmill!")
	end
	local err = commonChecks(player, data)
	if err then
		return deny(player, err)
	end
	if not S.CoreSpawnService:take(entity, player) then
		return false, "race"
	end
	S.CarryService:add(player, {
		kind = "world",
		entity = entity,
		coreId = entity.coreId,
		mutation = entity.mutation,
		zoneIndex = entity.zoneIndex,
	})
	if S.GuardianService then
		S.GuardianService:alert(entity.zoneIndex, player)
	end
	return true
end

function StealService:tryStealFromBase(thief, slot, podSlot)
	if not limiter:allow(thief) then
		return false, "rate"
	end
	local victim = S.BaseService:ownerOf(slot)
	if not victim or victim == thief then
		return false, "owner"
	end
	local data = S.PlayerDataService:get(thief)
	local vdata = S.PlayerDataService:get(victim)
	if not data or not vdata then
		return false, "not loaded"
	end
	if S.BaseService:isShielded(slot) then
		return deny(thief, "That base is locked!")
	end
	local hrp = aliveRoot(thief)
	if not hrp then
		return false, "dead"
	end
	local p = WorldLayout.podPosition(slot, podSlot)
	local podPos = Vector3.new(p[1], hrp.Position.Y, p[3])
	if (hrp.Position - podPos).Magnitude > Config.Carry.PickupRange then
		return false, "range"
	end
	local err = commonChecks(thief, data)
	if err then
		return deny(thief, err)
	end
	local pod = S.IncubatorService:beginTransit(victim, podSlot, thief)
	if not pod then
		return false, "empty"
	end
	S.CarryService:add(thief, {
		kind = "player",
		victim = victim,
		podSlot = podSlot,
		coreId = pod.c,
		mutation = pod.m,
		zoneIndex = pod.z,
		progress = pod.p,
	})
	Remotes.get("Announce"):FireClient(victim, {
		kind = "alarm",
		title = "BASE BREACH!",
		subtitle = thief.DisplayName .. " is stealing your " .. Config.Cores[pod.c].name .. " — tag them!",
		color = { 255, 70, 70 },
	})
	return true
end

return StealService
