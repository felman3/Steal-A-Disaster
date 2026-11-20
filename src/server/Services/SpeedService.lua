--[[
	SpeedService — treadmill training and WalkSpeed.

	Steps are counted on the server only: a player earns steps while their root
	part is over THEIR OWN treadmill belt and their Humanoid is moving
	(MoveDirection), at the capped rate from SpeedLogic. No remote is involved,
	so steps can't be spoofed.

	WalkSpeed = walkSpeedFor(Speed) * carry multiplier, recomputed whenever
	speed or carried weight changes, and re-asserted periodically.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpeedLogic = require(Shared.Logic.SpeedLogic)
local Util = require(Shared.Util)

local SpeedService = { Name = "SpeedService" }

local S
local stepStates = {}
local lastSync = {}

function SpeedService:Init(registry)
	S = registry
end

function SpeedService:maxWalkFor(player)
	local data = S.PlayerDataService:get(player)
	return SpeedLogic.walkSpeedFor(data and data.speed or 0)
end

function SpeedService:refreshWalkSpeed(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local mult = 1
	if S.CarryService then
		mult = S.CarryService:walkMultiplier(player)
	end
	local target = self:maxWalkFor(player) * mult
	if math.abs(hum.WalkSpeed - target) > 0.01 then
		hum.WalkSpeed = target
	end
	player:SetAttribute("WalkSpeed", target)
end

-- Is the player's root over their own treadmill belt?
function SpeedService:onTreadmill(player)
	local base = S.BaseService:baseOf(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not base or not hrp then
		return false
	end
	local belt = base.treadmill.belt
	local rel = belt.CFrame:PointToObjectSpace(hrp.Position)
	local size = belt.Size
	return math.abs(rel.X) <= size.X / 2 + 0.5 and math.abs(rel.Z) <= size.Z / 2 + 0.5 and rel.Y > -1 and rel.Y < 7
end

function SpeedService:addSteps(player, steps)
	local data = S.PlayerDataService:get(player)
	if not data or steps <= 0 then
		return 0
	end
	local gain = SpeedLogic.gainPerStep(data.upgrades.Treadmill) * steps
	data.speed = data.speed + gain
	data.steps = data.steps + steps
	return gain
end

function SpeedService:Start()
	Players.PlayerRemoving:Connect(function(p)
		stepStates[p] = nil
		lastSync[p] = nil
	end)
	S.PlayerDataService.Loaded:Connect(function(player)
		self:refreshWalkSpeed(player)
	end)
	local function hookPlayer(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				self:refreshWalkSpeed(player)
			end)
		end)
	end
	Players.PlayerAdded:Connect(hookPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		hookPlayer(p)
	end

	local reassert = 0
	RunService.Heartbeat:Connect(function(dt)
		reassert = reassert + dt
		local doReassert = reassert >= 1
		if doReassert then
			reassert = 0
		end
		for _, player in ipairs(S.PlayerDataService:loadedPlayers()) do
			local st = stepStates[player]
			if not st then
				st = SpeedLogic.newStepState()
				stepStates[player] = st
			end
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local running = hum ~= nil and hum.Health > 0 and hum.MoveDirection.Magnitude > 0.1 and self:onTreadmill(player)
			local steps = SpeedLogic.tickSteps(st, dt, running)
			if steps > 0 then
				local before = SpeedLogic.highestUnlockedZone(S.PlayerDataService:get(player).speed)
				self:addSteps(player, steps)
				local data = S.PlayerDataService:get(player)
				local after = SpeedLogic.highestUnlockedZone(data.speed)
				self:refreshWalkSpeed(player)
				player:SetAttribute("Speed", data.speed)
				-- sync at most ~4x/s while training
				local now = os.clock()
				if not lastSync[player] or now - lastSync[player] > 0.25 then
					lastSync[player] = now
					S.PlayerDataService:markDirty(player)
					if S.EconomyService then
						S.EconomyService:_updateStats(player, data)
					end
				end
				if after > before then
					local Config = require(Shared.Config.GameConfig)
					local zone = Config.Zones[after]
					local Remotes = require(Shared.Remotes)
					Remotes.get("Announce"):FireClient(player, {
						kind = "unlock",
						title = "ZONE UNLOCKED!",
						subtitle = "You can now steal in " .. zone.name,
						color = { 255, 230, 90 },
					})
				end
			elseif doReassert then
				self:refreshWalkSpeed(player)
			end
		end
	end)
end

return SpeedService
