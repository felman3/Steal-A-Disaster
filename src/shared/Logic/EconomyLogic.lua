--[[
	EconomyLogic — income and value of disaster collectibles.

	A disaster entry is { d = disasterId, m = mutationId|nil, z = originZoneIndex|nil }.
	`z` matters for the zone-agnostic Chaos Storm (its income scales with the zone it
	was stolen from); for other disasters the configured zone is used.
]]

local Config = require(script.Parent.Parent.Config.GameConfig)

local EconomyLogic = {}

function EconomyLogic.zoneIndexFor(entry)
	local d = Config.Disasters[entry.d]
	if not d then
		return 1
	end
	local idx = Config.ZoneIndex[d.zone]
	if idx then
		return idx
	end
	local z = tonumber(entry.z)
	if z and Config.Zones[z] then
		return z
	end
	return 1
end

function EconomyLogic.mutationMult(mutationId)
	local m = mutationId and Config.Mutations[mutationId]
	return m and m.mult or 1
end

function EconomyLogic.incomeFor(entry)
	local d = Config.Disasters[entry.d]
	if not d then
		return 0
	end
	local zone = Config.Zones[EconomyLogic.zoneIndexFor(entry)]
	local rarity = Config.Rarities[d.rarity]
	local income = zone.baseIncome * rarity.incomeMult * d.incomeFactor * EconomyLogic.mutationMult(entry.m)
	return math.floor(income * 10 + 0.5) / 10
end

function EconomyLogic.totalIncome(entries)
	local total = 0
	for _, e in ipairs(entries) do
		total = total + EconomyLogic.incomeFor(e)
	end
	return total
end

function EconomyLogic.valueFor(entry)
	return math.floor(EconomyLogic.incomeFor(entry) * Config.Economy.ValueSeconds)
end

-- Value of a core (shown in world): the value of the disaster it would become.
function EconomyLogic.coreValue(coreId, mutationId, zoneIndex)
	local c = Config.Cores[coreId]
	if not c then
		return 0
	end
	return EconomyLogic.valueFor({ d = c.disaster, m = mutationId, z = zoneIndex })
end

return EconomyLogic
