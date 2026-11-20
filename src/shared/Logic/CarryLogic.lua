--[[
	CarryLogic — weight, slowdown, capacity, teleport heuristics.
]]

local Config = require(script.Parent.Parent.Config.GameConfig)

local C = Config.Carry
local CarryLogic = {}

function CarryLogic.coreWeight(coreId)
	local core = Config.Cores[coreId]
	if not core then
		return 1
	end
	return Config.Rarities[core.rarity].weight
end

function CarryLogic.totalWeight(coreIds)
	local w = 0
	for _, id in ipairs(coreIds) do
		w = w + CarryLogic.coreWeight(id)
	end
	return w
end

function CarryLogic.walkMultiplier(totalWeight)
	if totalWeight <= 0 then
		return 1
	end
	return math.max(C.MinWalkMult, 1 - C.PenaltyPerWeight * totalWeight)
end

function CarryLogic.capacityForLevel(level)
	return math.max(1, math.min(level or 1, Config.Upgrades.Carry.maxLevel))
end

function CarryLogic.canCarryMore(currentCount, carryLevel)
	return currentCount < CarryLogic.capacityForLevel(carryLevel)
end

-- Max plausible distance moved in `dt` seconds at walk speed `maxWalk`.
function CarryLogic.maxTravel(dt, maxWalk)
	return maxWalk * dt * C.TeleportFactor + C.TeleportSlack
end

-- Horizontal distance only: falling/jumping is not a teleport.
function CarryLogic.isTeleport(dx, dz, dt, maxWalk)
	local dist = math.sqrt(dx * dx + dz * dz)
	return dist > CarryLogic.maxTravel(dt, maxWalk)
end

--[[
	Movement budget for carriers. Character positions replicate in bursts, so a
	per-frame distance check would flag laggy players. Instead every frame adds
	allowance (maxWalk * dt * factor) up to a cap and every frame's movement
	spends it. A real teleport overdraws the budget; lag bursts don't.
]]
function CarryLogic.newBudget(maxWalk)
	return CarryLogic.budgetCap(maxWalk)
end

function CarryLogic.budgetCap(maxWalk)
	return maxWalk * 2.5 + 15
end

-- returns newBudget, isTeleport
function CarryLogic.spendBudget(budget, dist, dt, maxWalk)
	local cap = CarryLogic.budgetCap(maxWalk)
	budget = math.min(cap, budget + maxWalk * math.min(dt, 1) * C.TeleportFactor) - dist
	return budget, budget < -C.TeleportSlack
end

return CarryLogic
