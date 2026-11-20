--[[
	ZoneService — builds the world and tracks which zone each player is in.

	Player attribute "Zone": 0 = hub/bases, 1..9 = route zone, -1 = out of bounds.
	Players who fall out of the world are returned to their base.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local WorldLayout = require(Shared.Logic.WorldLayout)
local Signal = require(Shared.Signal)

local MapBuilder = require(ServerScriptService.Server.World.MapBuilder)

local ZoneService = { Name = "ZoneService" }
ZoneService.ZoneChanged = Signal.new() -- (player, newZone, oldZone)

local S
local current = {}
local KILL_Y = -40

function ZoneService:Init(registry)
	S = registry
	self.world = MapBuilder.build()
end

function ZoneService:zoneOf(player)
	return current[player] or 0
end

function ZoneService:zoneRefs(index)
	return self.world.zones[index]
end

function ZoneService:hubRefs()
	return self.world.hub
end

local function rootOf(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end
ZoneService.rootOf = function(_, player)
	return rootOf(player)
end

function ZoneService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 0.2 then
			return
		end
		acc = 0
		for _, player in ipairs(Players:GetPlayers()) do
			local hrp = rootOf(player)
			if hrp then
				local pos = hrp.Position
				if pos.Y < KILL_Y then
					if S.CarryService then
						S.CarryService:dropAll(player, "fell")
					end
					if S.BaseService then
						S.BaseService:sendHome(player)
					end
				end
				local z = WorldLayout.zoneAt(pos.X, pos.Z)
				local old = current[player]
				if z ~= old then
					current[player] = z
					player:SetAttribute("Zone", z)
					self.ZoneChanged:Fire(player, z, old or 0)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		current[p] = nil
	end)
end

return ZoneService
