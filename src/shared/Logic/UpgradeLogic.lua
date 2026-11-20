--[[
	UpgradeLogic — costs and application of base upgrades (pure, data-only).
]]

local Config = require(script.Parent.Parent.Config.GameConfig)

local UpgradeLogic = {}

function UpgradeLogic.level(data, upgradeId)
	local def = Config.Upgrades[upgradeId]
	if not def then
		return 0
	end
	return (data.upgrades and data.upgrades[upgradeId]) or def.startLevel
end

-- Cost to go from `level` to `level + 1`; nil when maxed or unknown.
function UpgradeLogic.costFor(upgradeId, level)
	local def = Config.Upgrades[upgradeId]
	if not def or level >= def.maxLevel then
		return nil
	end
	if def.costs then
		return def.costs[level - def.startLevel + 1]
	end
	local steps = level - def.startLevel
	return math.floor(def.baseCost * def.growth ^ steps + 0.5)
end

function UpgradeLogic.nextCost(data, upgradeId)
	return UpgradeLogic.costFor(upgradeId, UpgradeLogic.level(data, upgradeId))
end

-- Returns ok, reasonOrCost
function UpgradeLogic.canBuy(data, upgradeId)
	if not Config.Upgrades[upgradeId] then
		return false, "Unknown upgrade"
	end
	local cost = UpgradeLogic.nextCost(data, upgradeId)
	if not cost then
		return false, "Maxed"
	end
	if (data.money or 0) < cost then
		return false, "Not enough money"
	end
	return true, cost
end

-- Mutates data. Returns ok, reasonOrCost
function UpgradeLogic.buy(data, upgradeId)
	local ok, res = UpgradeLogic.canBuy(data, upgradeId)
	if not ok then
		return false, res
	end
	data.money = data.money - res
	data.upgrades[upgradeId] = UpgradeLogic.level(data, upgradeId) + 1
	return true, res
end

function UpgradeLogic.shieldDuration(level)
	local d = Config.Upgrades.Shield.durations
	return d[math.max(1, math.min(#d, level or 1))]
end

return UpgradeLogic
