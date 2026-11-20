--[[
	EconomyService — passive income and all money mutations.

	Income is paid once per second from the disasters on display. All money
	changes go through addMoney/trySpend so they are validated in one place.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyLogic = require(Shared.Logic.EconomyLogic)
local MonetizationLogic = require(Shared.Logic.MonetizationLogic)
local Util = require(Shared.Util)

local EconomyService = { Name = "EconomyService" }

local S
local incomeCache = {}

function EconomyService:Init(registry)
	S = registry
end

function EconomyService:incomeOf(player)
	return incomeCache[player] or 0
end

function EconomyService:recompute(player)
	local data = S.PlayerDataService:get(player)
	if not data then
		incomeCache[player] = 0
		return 0
	end
	local inc = EconomyLogic.totalIncome(data.disasters) * MonetizationLogic.incomeMultiplier(data)
	incomeCache[player] = inc
	player:SetAttribute("Income", inc)
	return inc
end

function EconomyService:addMoney(player, amount, reason)
	local data = S.PlayerDataService:get(player)
	if not data or not Util.isFiniteNumber(amount) or amount < 0 then
		return false
	end
	data.money = data.money + amount
	S.PlayerDataService:markDirty(player)
	self:_updateStats(player, data)
	return true
end

function EconomyService:trySpend(player, amount)
	local data = S.PlayerDataService:get(player)
	if not data or not Util.isFiniteNumber(amount) or amount < 0 then
		return false
	end
	if data.money < amount then
		return false
	end
	data.money = data.money - amount
	S.PlayerDataService:markDirty(player)
	self:_updateStats(player, data)
	return true
end

function EconomyService:_ensureStats(player)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local money = Instance.new("StringValue")
		money.Name = "Cash"
		money.Parent = ls
		local speed = Instance.new("StringValue")
		speed.Name = "Speed"
		speed.Parent = ls
		ls.Parent = player
	end
	return ls
end

function EconomyService:_updateStats(player, data)
	local ls = self:_ensureStats(player)
	ls.Cash.Value = Util.formatMoney(data.money)
	ls.Speed.Value = Util.formatNumber(data.speed)
end

function EconomyService:Start()
	S.PlayerDataService.Loaded:Connect(function(player, data)
		self:recompute(player)
		self:_updateStats(player, data)
	end)
	Players.PlayerRemoving:Connect(function(p)
		incomeCache[p] = nil
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 1 then
			return
		end
		local elapsed = math.min(acc, 5)
		acc = 0
		for _, player in ipairs(S.PlayerDataService:loadedPlayers()) do
			local inc = incomeCache[player] or self:recompute(player)
			if inc > 0 then
				self:addMoney(player, inc * elapsed, "income")
			end
		end
	end)
end

return EconomyService
