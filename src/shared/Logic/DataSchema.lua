--[[
	DataSchema — default player data and a strict sanitizer.

	Everything loaded from the DataStore goes through sanitize(), which drops
	unknown ids, clamps numbers, removes duplicate slots and enforces upgrade
	limits. That way corrupted, legacy or tampered data can never put the
	server in an invalid state.

	Shape (v1):
	{
		v = 1,
		money = number, speed = number, steps = number,
		upgrades = { Treadmill = n, Carry = n, Pods = n, Pedestals = n, Shield = n },
		pods = { { s = slot, c = coreId, m = mutation?, z = zoneIndex, p = progress } },
		storage = { { c = coreId, m = mutation?, z = zoneIndex } },
		disasters = { { s = slot, d = disasterId, m = mutation?, z = zoneIndex } },
		index = { [disasterId] = true },
		stats = { stolen = n, hatched = n, robbed = n },
		lastSeen = unixTime,
		passes = { [passKey] = true },   -- Game Pass entitlements (re-verified on join)
		boostSpeed = seconds,             -- Speed Boost play-time left
		hatchCredits = n,                 -- paid Instant Hatches waiting to be used
		receipts = { purchaseId, ... },   -- processed Developer Product receipts
	}
]]

local Config = require(script.Parent.Parent.Config.GameConfig)
local Util = require(script.Parent.Parent.Util)
local MConfig = require(script.Parent.Parent.Config.MonetizationConfig)

local DataSchema = {}

function DataSchema.default()
	local upgrades = {}
	for id, def in pairs(Config.Upgrades) do
		upgrades[id] = def.startLevel
	end
	return {
		v = Config.Data.SchemaVersion,
		money = Config.Economy.StartMoney,
		speed = 0,
		steps = 0,
		upgrades = upgrades,
		pods = {},
		storage = {},
		disasters = {},
		index = {},
		stats = { stolen = 0, hatched = 0, robbed = 0 },
		lastSeen = 0,
		passes = {},
		boostSpeed = 0,
		hatchCredits = 0,
		receipts = {},
	}
end

local function num(x, default, lo, hi)
	if not Util.isFiniteNumber(x) then
		return default
	end
	if lo and x < lo then
		x = lo
	end
	if hi and x > hi then
		x = hi
	end
	return x
end

local function validMutation(m)
	if m ~= nil and Config.Mutations[m] then
		return m
	end
	return nil
end

local function validZone(z)
	z = tonumber(z)
	if z and Config.Zones[math.floor(z)] then
		return math.floor(z)
	end
	return 1
end

function DataSchema.sanitize(raw)
	local data = DataSchema.default()
	if type(raw) ~= "table" then
		return data
	end

	data.money = num(raw.money, 0, 0, 1e18)
	data.speed = num(raw.speed, 0, 0, 1e15)
	data.steps = math.floor(num(raw.steps, 0, 0, 1e15))
	data.lastSeen = math.floor(num(raw.lastSeen, 0, 0, 1e11))

	if type(raw.upgrades) == "table" then
		for id, def in pairs(Config.Upgrades) do
			local lvl = math.floor(num(raw.upgrades[id], def.startLevel, def.startLevel, def.maxLevel))
			data.upgrades[id] = lvl
		end
	end

	-- pods: valid core, unique slot within unlocked pod count
	local podCount = data.upgrades.Pods
	local usedPods = {}
	if type(raw.pods) == "table" then
		for _, p in ipairs(raw.pods) do
			if type(p) == "table" and Config.Cores[p.c] then
				local s = math.floor(num(p.s, 0))
				if s >= 1 and s <= podCount and not usedPods[s] then
					usedPods[s] = true
					table.insert(data.pods, {
						s = s,
						c = p.c,
						m = validMutation(p.m),
						z = validZone(p.z),
						p = num(p.p, 0, 0, 1e7),
					})
				end
			end
		end
	end

	if type(raw.storage) == "table" then
		for _, c in ipairs(raw.storage) do
			if #data.storage >= Config.Data.MaxStoredCores then
				break
			end
			if type(c) == "table" and Config.Cores[c.c] then
				table.insert(data.storage, { c = c.c, m = validMutation(c.m), z = validZone(c.z) })
			end
		end
	end

	local pedCount = data.upgrades.Pedestals
	local usedPeds = {}
	if type(raw.disasters) == "table" then
		for _, d in ipairs(raw.disasters) do
			if type(d) == "table" and Config.Disasters[d.d] then
				local s = math.floor(num(d.s, 0))
				if s >= 1 and s <= pedCount and not usedPeds[s] then
					usedPeds[s] = true
					table.insert(data.disasters, { s = s, d = d.d, m = validMutation(d.m), z = validZone(d.z) })
				end
			end
		end
	end

	if type(raw.index) == "table" then
		for id, v in pairs(raw.index) do
			if v and Config.Disasters[id] then
				data.index[id] = true
			end
		end
	end
	for _, d in ipairs(data.disasters) do
		data.index[d.d] = true
	end

	if type(raw.stats) == "table" then
		data.stats.stolen = math.floor(num(raw.stats.stolen, 0, 0))
		data.stats.hatched = math.floor(num(raw.stats.hatched, 0, 0))
		data.stats.robbed = math.floor(num(raw.stats.robbed, 0, 0))
	end

	-- monetization: only known passes, bounded numbers, string receipt ids
	if type(raw.passes) == "table" then
		for key, item in pairs(MConfig.Items) do
			if item.type == "GamePass" and raw.passes[key] == true then
				data.passes[key] = true
			end
		end
	end
	data.boostSpeed = num(raw.boostSpeed, 0, 0, 1e7)
	data.hatchCredits = math.floor(num(raw.hatchCredits, 0, 0, 1000))
	if type(raw.receipts) == "table" then
		for _, id in ipairs(raw.receipts) do
			if type(id) == "string" and #id > 0 and #id <= 100 then
				table.insert(data.receipts, id)
			end
		end
		while #data.receipts > MConfig.ReceiptHistorySize do
			table.remove(data.receipts, 1)
		end
	end

	return data
end

-- helpers used by services ---------------------------------------------------

function DataSchema.freeSlot(list, maxSlots)
	local used = {}
	for _, e in ipairs(list) do
		used[e.s] = true
	end
	for s = 1, maxSlots do
		if not used[s] then
			return s
		end
	end
	return nil
end

function DataSchema.findBySlot(list, slot)
	for i, e in ipairs(list) do
		if e.s == slot then
			return e, i
		end
	end
	return nil, nil
end

return DataSchema
