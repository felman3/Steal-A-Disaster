--[[
	TravelService — server-validated Quick Travel.

	Destinations: Home (own base spawn), Train (behind own treadmill), Steal
	(entrance of the highest zone the player can steal in), Zone n (any zone
	the player has unlocked). Every request is checked here: data loaded,
	alive, not carrying (no skipping the run home), cooldown, and progression.
	The landing spot is a fixed safe point (open corridor / base floor), shifted
	sideways to avoid other players. The carry anti-teleport tracker is reset.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local TravelLogic = require(Shared.Logic.TravelLogic)
local RateLimiter = require(Shared.Logic.RateLimiter)
local Remotes = require(Shared.Remotes)

local TravelService = { Name = "TravelService" }

local S
local limiter
local readyAt = {} -- [player] = os.clock() when the next trip is allowed

function TravelService:Init(registry)
	S = registry
	limiter = RateLimiter.new(2, 4)
end

local function otherRoots(player)
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			table.insert(out, { hrp.Position.X, hrp.Position.Z })
		end
	end
	return out
end

-- Shift `cf` sideways (its RightVector) to the first spot clear of other players.
local function clearSpot(player, cf)
	local p = cf.Position
	local r = cf.RightVector
	local off = TravelLogic.clearOffset({ p.X, p.Y, p.Z }, { r.X, r.Z }, otherRoots(player))
	return cf + r * off
end

function TravelService:destination(player, dest, arg)
	local data = S.PlayerDataService:get(player)
	local slot = S.BaseService:slotOf(player)
	if dest == "Home" then
		if not slot then
			return nil
		end
		return S.BaseService:spawnCFrame(slot) + Vector3.new(0, 1, 0), "your base"
	elseif dest == "Train" then
		local base = slot and S.BaseService:base(slot)
		if not base then
			return nil
		end
		-- just off the back end of the belt, facing the console: walk forward to train
		local frame = base.treadmill.frame
		local pos = (frame * CFrame.new(-11.5, 3.5, 0)).Position
		return CFrame.lookAt(pos, pos + frame.RightVector), "your treadmill"
	end
	local index = (dest == "Steal") and TravelLogic.stealZone(data.speed) or tonumber(arg)
	local p = TravelLogic.zoneEntrance(index)
	local pos = Vector3.new(p[1], p[2], p[3])
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)), Config.Zones[index].name
end

-- Returns ok, message.
function TravelService:request(player, dest, arg)
	if not limiter:allow(player) then
		return false, nil
	end
	local data = S.PlayerDataService:get(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not data or not hrp or not hum or hum.Health <= 0 then
		return false, nil
	end
	local ok, reason = TravelLogic.check(dest, arg, data.speed, S.CarryService:count(player), os.clock(), readyAt[player])
	if not ok then
		return false, reason
	end
	local cf, label = self:destination(player, dest, arg)
	if not cf then
		return false, "You don't have a base yet."
	end
	cf = clearSpot(player, cf)
	S.CarryService:resetTracking(player)
	char:PivotTo(cf)
	hrp.AssemblyLinearVelocity = Vector3.zero
	readyAt[player] = os.clock() + TravelLogic.COOLDOWN
	player:SetAttribute("TravelReadyAt", workspace:GetServerTimeNow() + TravelLogic.COOLDOWN)
	return true, label
end

function TravelService:Start()
	Remotes.get("RequestTravel").OnServerEvent:Connect(function(player, dest, arg)
		local ok, msg = self:request(player, dest, arg)
		if not ok and msg then
			S.PlayerDataService:notify(player, msg, "error")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return TravelService
