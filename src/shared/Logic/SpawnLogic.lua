--[[
	SpawnLogic — weighted core selection and mutation rolls.
	`rng` is a function returning a float in [0, 1).
]]

local Config = require(script.Parent.Parent.Config.GameConfig)

local SpawnLogic = {}

-- Returns a rarity -> weight table, boosted during Chaos Frenzy.
function SpawnLogic.effectiveWeights(zone, frenzy)
	local out = {}
	for rarity, w in pairs(zone.rarityWeights) do
		local rank = Config.Rarities[rarity].rank
		if frenzy then
			out[rarity] = w * Config.Events.FrenzyRareBoostPerRank ^ (rank - 1)
		else
			out[rarity] = w
		end
	end
	return out
end

function SpawnLogic.rollRarity(weights, rng)
	local total = 0
	-- iterate in a deterministic order so seeded tests are stable
	for _, rarity in ipairs(Config.RarityOrder) do
		total = total + (weights[rarity] or 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = rng() * total
	local last = nil
	for _, rarity in ipairs(Config.RarityOrder) do
		local w = weights[rarity] or 0
		if w > 0 then
			last = rarity
			if roll < w then
				return rarity
			end
			roll = roll - w
		end
	end
	return last
end

-- Picks a core id for a zone. Zones list one core per rarity.
function SpawnLogic.pickCore(zone, rng, frenzy)
	local rarity = SpawnLogic.rollRarity(SpawnLogic.effectiveWeights(zone, frenzy), rng)
	local candidates = {}
	for _, coreId in ipairs(zone.cores) do
		if Config.Cores[coreId].rarity == rarity then
			table.insert(candidates, coreId)
		end
	end
	if #candidates == 0 then
		return zone.cores[1]
	end
	return candidates[math.floor(rng() * #candidates) + 1] or candidates[1]
end

function SpawnLogic.rollMutation(rng, mult)
	mult = mult or 1
	local roll = rng()
	local acc = 0
	-- rarest first so the rarest mutations aren't shadowed when mult is large
	for i = #Config.MutationOrder, 1, -1 do
		local id = Config.MutationOrder[i]
		acc = acc + Config.Mutations[id].chance * mult
		if roll < acc then
			return id
		end
	end
	return nil
end

return SpawnLogic
