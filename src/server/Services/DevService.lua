--[[
	DevService — Studio-only test commands (disabled in live servers).

	Type in chat while play-testing in Studio:
	  /money <n>        set money
	  /speed <n>        set Speed
	  /core <CoreId>    put a core into your incubator (e.g. /core BlackHoleCore)
	  /hatch            finish all your pods now
	  /frenzy           jump to 2 s before the next refresh + Chaos Frenzy
	  /guardians off|on toggle all guardians
	  /reset            wipe your data back to defaults (this session)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local DataSchema = require(Shared.Logic.DataSchema)
local IncubatorLogic = require(Shared.Logic.IncubatorLogic)

local DevService = { Name = "DevService" }

local S

function DevService:Init(registry)
	S = registry
end

function DevService:enabled()
	return RunService:IsStudio()
end

function DevService:run(player, msg)
	if not self:enabled() or type(msg) ~= "string" then
		return false
	end
	local args = string.split(msg, " ")
	local cmd = string.lower(args[1] or "")
	local data = S.PlayerDataService:get(player)
	if not data then
		return false
	end
	local n = tonumber(args[2] or "")
	if cmd == "/money" and n then
		data.money = math.max(0, n)
	elseif cmd == "/speed" and n then
		data.speed = math.max(0, n)
		S.SpeedService:refreshWalkSpeed(player)
	elseif cmd == "/core" and args[2] and Config.Cores[args[2]] then
		S.IncubatorService:receive(player, { c = args[2], z = 1 })
	elseif cmd == "/hatch" then
		for _, pod in ipairs(data.pods) do
			pod.p = IncubatorLogic.incubationTime(pod.c, pod.z)
		end
		S.IncubatorService:tryHatchAll(player)
	elseif cmd == "/frenzy" then
		local info = S.EventService:elapsed() % Config.Events.Interval
		S.EventService:skip(Config.Events.Interval - info - 2)
	elseif cmd == "/guardians" then
		for i = 1, #Config.Zones do
			S.GuardianService:setEnabled(i, args[2] ~= "off")
		end
	elseif cmd == "/reset" then
		local fresh = DataSchema.default()
		for k, v in pairs(fresh) do
			data[k] = v
		end
		S.IncubatorService:clearAll(player)
		S.DisasterCollectionService:clearAll(player)
		S.EconomyService:recompute(player)
		S.SpeedService:refreshWalkSpeed(player)
	else
		return false
	end
	S.BaseService:refresh(player)
	S.EconomyService:_updateStats(player, data)
	S.PlayerDataService:markDirty(player)
	S.PlayerDataService:notify(player, "[dev] " .. msg, "info")
	return true
end

function DevService:Start()
	if not self:enabled() then
		return
	end
	local function hook(player)
		player.Chatted:Connect(function(msg)
			self:run(player, msg)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	print("[DevService] Studio commands enabled: /money /speed /core /hatch /frenzy /guardians /reset")
end

return DevService
