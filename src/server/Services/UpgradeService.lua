--[[
	UpgradeService — the only way to spend money on progression.

	Client sends RequestUpgrade(upgradeId). The server rate-limits, validates the
	id and price via UpgradeLogic, applies the effect and refreshes the base so
	the change is visible in the world (new pods/pedestals unlock, decor tiers).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local UpgradeLogic = require(Shared.Logic.UpgradeLogic)
local RateLimiter = require(Shared.Logic.RateLimiter)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local UpgradeService = { Name = "UpgradeService" }

local S
local limiter

function UpgradeService:Init(registry)
	S = registry
	local rl = Config.RateLimits.Upgrade
	limiter = RateLimiter.new(rl[1], rl[2])
end

function UpgradeService:buy(player, upgradeId)
	if type(upgradeId) ~= "string" or not Config.Upgrades[upgradeId] then
		return false, "Unknown upgrade"
	end
	if not limiter:allow(player) then
		return false, "Slow down"
	end
	local data = S.PlayerDataService:get(player)
	if not data then
		return false, "Not loaded"
	end
	local ok, res = UpgradeLogic.buy(data, upgradeId)
	if not ok then
		return false, res
	end
	-- side effects
	if upgradeId == "Pods" then
		S.IncubatorService:onCapacityChanged(player)
	elseif upgradeId == "Pedestals" then
		S.IncubatorService:tryHatchAll(player)
	elseif upgradeId == "Treadmill" or upgradeId == "Carry" then
		S.SpeedService:refreshWalkSpeed(player)
	end
	S.BaseService:refresh(player)
	S.EconomyService:_updateStats(player, data)
	S.PlayerDataService:markDirty(player)
	return true, res
end

function UpgradeService:Start()
	Remotes.get("RequestUpgrade").OnServerEvent:Connect(function(player, upgradeId)
		local ok, res = self:buy(player, upgradeId)
		if ok then
			local def = Config.Upgrades[upgradeId]
			local data = S.PlayerDataService:get(player)
			S.PlayerDataService:notify(player, def.name .. " upgraded to Lv " .. data.upgrades[upgradeId] .. "!", "success")
		elseif res == "Not enough money" then
			local data = S.PlayerDataService:get(player)
			local cost = data and UpgradeLogic.nextCost(data, upgradeId)
			local short = cost and (cost - data.money) or 0
			S.PlayerDataService:notify(player, "Not enough money — you need " .. Util.formatMoney(math.max(0, short)) .. " more.", "error")
		elseif res ~= "Slow down" then
			S.PlayerDataService:notify(player, tostring(res), "error")
		end
	end)
end

return UpgradeService
