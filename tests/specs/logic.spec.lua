-- Unit tests for the pure shared logic modules.
local env = Env.new({ mode = "server" })
local Config = env.require("ReplicatedStorage.Shared.Config.GameConfig")
local Util = env.require("ReplicatedStorage.Shared.Util")
local SpeedLogic = env.require("ReplicatedStorage.Shared.Logic.SpeedLogic")
local CarryLogic = env.require("ReplicatedStorage.Shared.Logic.CarryLogic")
local EconomyLogic = env.require("ReplicatedStorage.Shared.Logic.EconomyLogic")
local IncubatorLogic = env.require("ReplicatedStorage.Shared.Logic.IncubatorLogic")
local SpawnLogic = env.require("ReplicatedStorage.Shared.Logic.SpawnLogic")
local UpgradeLogic = env.require("ReplicatedStorage.Shared.Logic.UpgradeLogic")
local EventLogic = env.require("ReplicatedStorage.Shared.Logic.EventLogic")
local RateLimiter = env.require("ReplicatedStorage.Shared.Logic.RateLimiter")
local DataSchema = env.require("ReplicatedStorage.Shared.Logic.DataSchema")
local WorldLayout = env.require("ReplicatedStorage.Shared.Logic.WorldLayout")

local function seeded(seed)
	local r = env.G.Random.new(seed)
	return function()
		return r:NextNumber()
	end
end

describe("GameConfig", function()
	it("has 9 zones with strictly increasing speed requirements", function()
		expect(#Config.Zones).toBe(9)
		for i = 2, #Config.Zones do
			expect(Config.Zones[i].speedReq).toBeGreaterThan(Config.Zones[i - 1].speedReq)
			expect(Config.Zones[i].baseIncome).toBeGreaterThan(Config.Zones[i - 1].baseIncome)
		end
	end)
	it("every zone core exists, belongs to that zone and maps to a disaster", function()
		for _, zone in ipairs(Config.Zones) do
			expect(#zone.cores).toBe(4)
			for _, coreId in ipairs(zone.cores) do
				local c = Config.Cores[coreId]
				expect(c ~= nil).toBe(true)
				expect(c.zone).toBe(zone.id)
				expect(Config.Disasters[c.disaster] ~= nil).toBe(true)
				expect(zone.rarityWeights[c.rarity] ~= nil).toBe(true)
			end
		end
	end)
	it("every disaster has exactly one source core and a known archetype", function()
		local archetypes = {
			Vortex = true, Cloud = true, StormCloud = true, Golem = true, Serpent = true, Beast = true,
			Wisp = true, Maw = true, Volcano = true, Meteor = true, Wave = true, Bird = true,
			Entity = true, BlackHole = true,
		}
		for id, d in pairs(Config.Disasters) do
			expect(Config.CoreByDisaster[id] ~= nil).toBe(true)
			expect(archetypes[d.archetype]).toBe(true)
		end
	end)
	it("every rarity weight table references real rarities", function()
		for _, zone in ipairs(Config.Zones) do
			for r in pairs(zone.rarityWeights) do
				expect(Config.Rarities[r] ~= nil).toBe(true)
			end
		end
	end)
end)

describe("Util", function()
	it("formats numbers compactly", function()
		expect(Util.formatNumber(15)).toBe("15")
		expect(Util.formatNumber(1234)).toBe("1.23K")
		expect(Util.formatNumber(2500000)).toBe("2.5M")
		expect(Util.formatNumber(3000)).toBe("3K")
		expect(Util.formatNumber(999)).toBe("999")
		expect(Util.formatNumber(123456)).toBe("123K")
		expect(Util.formatNumber(0 / 0)).toBe("0")
	end)
	it("formats time", function()
		expect(Util.formatTime(75)).toBe("1:15")
		expect(Util.formatTime(3725)).toBe("1:02:05")
		expect(Util.formatTime(-3)).toBe("0:00")
	end)
end)

describe("SpeedLogic", function()
	it("maps speed to walk speed monotonically with a cap", function()
		expect(SpeedLogic.walkSpeedFor(0)).toBe(16)
		local prev = 0
		for _, s in ipairs({ 0, 100, 600, 3000, 12000, 1e5, 1e6, 1e8 }) do
			local w = SpeedLogic.walkSpeedFor(s)
			expect(w).toBeAtLeast(prev)
			prev = w
		end
		expect(SpeedLogic.walkSpeedFor(1e30)).toBe(Config.Speed.MaxWalkSpeed)
	end)
	it("gates zones by speed requirement", function()
		expect(SpeedLogic.canStealInZone(0, 1)).toBe(true)
		expect(SpeedLogic.canStealInZone(599, 2)).toBe(false)
		expect(SpeedLogic.canStealInZone(600, 2)).toBe(true)
		expect(SpeedLogic.canStealInZone(1e12, 99)).toBe(false)
		expect(SpeedLogic.highestUnlockedZone(3000)).toBe(3)
		expect(SpeedLogic.nextZone(3000).id).toBe("Frostfall")
		expect(SpeedLogic.nextZone(1e12)).toBeNil()
	end)
	it("counts treadmill steps at a capped rate regardless of frame rate", function()
		local st = SpeedLogic.newStepState()
		local total = 0
		for _ = 1, 600 do -- 10 s at 60 fps
			total = total + SpeedLogic.tickSteps(st, 1 / 60, true)
		end
		expect(total).toBe(40)
		st = SpeedLogic.newStepState()
		total = 0
		for _ = 1, 10 do -- 10 s at 1 fps
			total = total + SpeedLogic.tickSteps(st, 1, true)
		end
		-- hitch clamp: a 1 s frame only counts 0.5 s
		expect(total).toBe(20)
		expect(SpeedLogic.tickSteps(st, 1, false)).toBe(0)
	end)
	it("treadmill gain grows with level", function()
		expect(SpeedLogic.gainPerStep(1)).toBe(5)
		expect(SpeedLogic.gainPerStep(2)).toBeGreaterThan(5)
		expect(SpeedLogic.gainPerStep(10)).toBeGreaterThan(SpeedLogic.gainPerStep(9))
	end)
end)

describe("CarryLogic", function()
	it("slows by weight down to a floor", function()
		expect(CarryLogic.walkMultiplier(0)).toBe(1)
		expect(CarryLogic.walkMultiplier(1)).toBeNear(0.88)
		expect(CarryLogic.walkMultiplier(100)).toBe(Config.Carry.MinWalkMult)
		expect(CarryLogic.totalWeight({ "GustCore", "TornadoCore" })).toBeNear(2.5)
	end)
	it("enforces capacity", function()
		expect(CarryLogic.canCarryMore(0, 1)).toBe(true)
		expect(CarryLogic.canCarryMore(1, 1)).toBe(false)
		expect(CarryLogic.canCarryMore(3, 4)).toBe(true)
		expect(CarryLogic.capacityForLevel(99)).toBe(4)
	end)
	it("flags teleports but not normal movement", function()
		expect(CarryLogic.isTeleport(1, 1, 1 / 30, 30)).toBe(false)
		expect(CarryLogic.isTeleport(200, 0, 1 / 30, 30)).toBe(true)
		expect(CarryLogic.isTeleport(0, 9, 1 / 30, 90)).toBe(false)
	end)
end)

describe("EconomyLogic", function()
	it("income scales with zone, rarity and mutation", function()
		local base = EconomyLogic.incomeFor({ d = "DustDevil" })
		expect(base).toBe(2)
		expect(EconomyLogic.incomeFor({ d = "DustDevil", m = "Golden" })).toBe(6)
		expect(EconomyLogic.incomeFor({ d = "MiniTornado" })).toBeNear(5.2)
		expect(EconomyLogic.incomeFor({ d = "Nope" })).toBe(0)
		expect(EconomyLogic.incomeFor({ d = "BlackHole" })).toBeGreaterThan(EconomyLogic.incomeFor({ d = "VoidEntity" }))
	end)
	it("chaos storm income follows its origin zone", function()
		local z1 = EconomyLogic.incomeFor({ d = "ChaosStorm", z = 1 })
		local z9 = EconomyLogic.incomeFor({ d = "ChaosStorm", z = 9 })
		expect(z1).toBe(60)
		expect(z9).toBeGreaterThan(z1)
		expect(EconomyLogic.incomeFor({ d = "ChaosStorm", z = 999 })).toBe(60)
	end)
	it("value is income * 60", function()
		expect(EconomyLogic.valueFor({ d = "DustDevil" })).toBe(120)
		expect(EconomyLogic.coreValue("GustCore")).toBe(120)
	end)
end)

describe("IncubatorLogic", function()
	it("incubation time depends on rarity and zone", function()
		expect(IncubatorLogic.incubationTime("GustCore")).toBe(15)
		expect(IncubatorLogic.incubationTime("TornadoCore")).toBe(60)
		expect(IncubatorLogic.incubationTime("SingularityCore")).toBeGreaterThan(IncubatorLogic.incubationTime("SupervolcanoCore") - 1)
	end)
	it("advances with rate and completes", function()
		local pod = { s = 1, c = "GustCore", z = 1, p = 0 }
		expect(IncubatorLogic.advance(pod, 10, 1)).toBe(false)
		expect(IncubatorLogic.fraction(pod)).toBeNear(10 / 15)
		expect(IncubatorLogic.advance(pod, 2, 4)).toBe(true)
		expect(pod.p).toBe(15)
		expect(IncubatorLogic.remaining(pod)).toBe(0)
	end)
end)

describe("SpawnLogic", function()
	it("rarity distribution matches weights", function()
		local rng = seeded(42)
		local zone = Config.Zones[1]
		local counts = {}
		local N = 20000
		for _ = 1, N do
			local r = SpawnLogic.rollRarity(zone.rarityWeights, rng)
			counts[r] = (counts[r] or 0) + 1
		end
		expect(counts.Common / N).toBeNear(0.62, 0.02)
		expect(counts.Epic / N).toBeNear(0.02, 0.006)
		expect(counts.Legendary).toBeNil()
	end)
	it("frenzy shifts odds toward rarer cores", function()
		local zone = Config.Zones[1]
		local normal = SpawnLogic.effectiveWeights(zone, false)
		local frenzy = SpawnLogic.effectiveWeights(zone, true)
		expect(frenzy.Epic / frenzy.Common).toBeGreaterThan(normal.Epic / normal.Common * 4)
	end)
	it("pickCore returns a zone core", function()
		local rng = seeded(7)
		for _, zone in ipairs(Config.Zones) do
			for _ = 1, 50 do
				local id = SpawnLogic.pickCore(zone, rng, false)
				expect(Config.Cores[id].zone).toBe(zone.id)
			end
		end
	end)
	it("mutation rates are roughly configured", function()
		local rng = seeded(3)
		local n, N = 0, 20000
		for _ = 1, N do
			if SpawnLogic.rollMutation(rng, 1) then
				n = n + 1
			end
		end
		expect(n / N).toBeNear(0.1285, 0.012)
	end)
end)

describe("UpgradeLogic", function()
	it("buys when affordable and deducts money", function()
		local data = DataSchema.default()
		data.money = 1000
		local ok, cost = UpgradeLogic.buy(data, "Treadmill")
		expect(ok).toBe(true)
		expect(cost).toBe(40)
		expect(data.money).toBe(960)
		expect(data.upgrades.Treadmill).toBe(2)
		expect(UpgradeLogic.nextCost(data, "Treadmill")).toBe(86)
	end)
	it("refuses when broke, maxed or unknown", function()
		local data = DataSchema.default()
		local ok, reason = UpgradeLogic.buy(data, "Treadmill")
		expect(ok).toBe(false)
		expect(reason).toBe("Not enough money")
		data.money = 1e30
		data.upgrades.Carry = 4
		ok, reason = UpgradeLogic.buy(data, "Carry")
		expect(reason).toBe("Maxed")
		ok, reason = UpgradeLogic.buy(data, "Hax")
		expect(ok).toBe(false)
	end)
	it("fixed cost tables are used for Carry", function()
		local data = DataSchema.default()
		expect(UpgradeLogic.nextCost(data, "Carry")).toBe(400)
		data.upgrades.Carry = 3
		expect(UpgradeLogic.nextCost(data, "Carry")).toBe(250000)
	end)
	it("pods/pedestals start at configured counts", function()
		local data = DataSchema.default()
		expect(UpgradeLogic.level(data, "Pods")).toBe(2)
		expect(UpgradeLogic.level(data, "Pedestals")).toBe(4)
		expect(UpgradeLogic.nextCost(data, "Pods")).toBe(150)
		expect(UpgradeLogic.shieldDuration(1)).toBe(30)
		expect(UpgradeLogic.shieldDuration(99)).toBe(90)
	end)
end)

describe("EventLogic", function()
	it("follows the warning -> frenzy -> normal cycle", function()
		expect(EventLogic.phaseAt(0).phase).toBe("Normal")
		expect(EventLogic.phaseAt(5).phase).toBe("Normal") -- no frenzy at boot
		expect(EventLogic.phaseAt(269).phase).toBe("Normal")
		expect(EventLogic.phaseAt(271).phase).toBe("Warning")
		expect(EventLogic.phaseAt(300).phase).toBe("Frenzy")
		expect(EventLogic.phaseAt(309.5).phase).toBe("Frenzy")
		expect(EventLogic.phaseAt(310).phase).toBe("Normal")
		expect(EventLogic.phaseAt(305).frenzyLeft).toBeNear(5)
		expect(EventLogic.phaseAt(290).toRefresh).toBeNear(10)
	end)
	it("counts refreshes", function()
		expect(EventLogic.refreshesBetween(0, 299)).toBe(0)
		expect(EventLogic.refreshesBetween(299, 301)).toBe(1)
		expect(EventLogic.refreshesBetween(0, 900)).toBe(3)
	end)
end)

describe("RateLimiter", function()
	it("allows burst then throttles then refills", function()
		local t = 0
		local rl = RateLimiter.new(2, 3, function()
			return t
		end)
		expect(rl:allow("a")).toBe(true)
		expect(rl:allow("a")).toBe(true)
		expect(rl:allow("a")).toBe(true)
		expect(rl:allow("a")).toBe(false)
		expect(rl:allow("b")).toBe(true)
		t = 0.5
		expect(rl:allow("a")).toBe(true)
		expect(rl:allow("a")).toBe(false)
	end)
end)

describe("DataSchema", function()
	it("sanitizes garbage into defaults", function()
		local d = DataSchema.sanitize("lol")
		expect(d.money).toBe(0)
		d = DataSchema.sanitize({ money = 0 / 0, speed = -5, upgrades = { Treadmill = 9999, Carry = "x" } })
		expect(d.money).toBe(0)
		expect(d.speed).toBe(0)
		expect(d.upgrades.Treadmill).toBe(Config.Upgrades.Treadmill.maxLevel)
		expect(d.upgrades.Carry).toBe(1)
	end)
	it("drops unknown ids, duplicate and out-of-range slots", function()
		local d = DataSchema.sanitize({
			pods = {
				{ s = 1, c = "GustCore", p = 3 },
				{ s = 1, c = "HailCore" }, -- duplicate slot
				{ s = 3, c = "GustCore" }, -- beyond 2 pods
				{ s = 2, c = "FakeCore" },
			},
			disasters = {
				{ s = 1, d = "DustDevil", m = "Golden" },
				{ s = 2, d = "MiniTornado", m = "SuperHax" },
				{ s = 9, d = "DustDevil" },
			},
			storage = { { c = "GustCore" }, { c = "Bad" } },
			index = { DustDevil = true, Nope = true },
		})
		expect(#d.pods).toBe(1)
		expect(d.pods[1].p).toBe(3)
		expect(#d.disasters).toBe(2)
		expect(d.disasters[2].m).toBeNil()
		expect(#d.storage).toBe(1)
		expect(d.index.DustDevil).toBe(true)
		expect(d.index.Nope).toBeNil()
		expect(d.index.MiniTornado).toBe(true)
	end)
	it("finds free slots", function()
		expect(DataSchema.freeSlot({ { s = 1 }, { s = 3 } }, 4)).toBe(2)
		expect(DataSchema.freeSlot({ { s = 1 }, { s = 2 } }, 2)).toBeNil()
	end)
end)

describe("WorldLayout", function()
	it("maps z to zones", function()
		expect(WorldLayout.zoneAt(0, 0)).toBe(0)
		expect(WorldLayout.zoneAt(0, 201)).toBe(1)
		expect(WorldLayout.zoneAt(0, 200 + 260 * 8 + 1)).toBe(9)
		expect(WorldLayout.zoneAt(0, 200 + 260 * 9 + 1)).toBe(-1)
		expect(WorldLayout.zoneAt(500, 300)).toBe(-1)
	end)
	it("nests sit inside their zone", function()
		for i = 1, #Config.Zones do
			for _, p in ipairs(WorldLayout.nestPoints(i)) do
				expect(WorldLayout.zoneAt(p[1], p[3])).toBe(i)
			end
		end
	end)
	it("base slots don't overlap and all base furniture is inside the base", function()
		local n = #Config.Bases.Slots
		for i = 1, n do
			for j = i + 1, n do
				local a, b = Config.Bases.Slots[i], Config.Bases.Slots[j]
				local apart = math.abs(a.x - b.x) >= Config.Bases.Size or math.abs(a.z - b.z) >= Config.Bases.Size
				expect(apart).toBe(true)
			end
			for k = 1, Config.Bases.MaxPods do
				local p = WorldLayout.podPosition(i, k)
				expect(WorldLayout.inBase(i, p[1], p[3])).toBe(true)
			end
			for k = 1, Config.Bases.MaxPedestals do
				local p = WorldLayout.pedestalPosition(i, k)
				expect(WorldLayout.inBase(i, p[1], p[3])).toBe(true)
			end
			local t = WorldLayout.treadmillPosition(i)
			expect(WorldLayout.inBase(i, t[1], t[3])).toBe(true)
			local s = WorldLayout.spawnPosition(i)
			expect(WorldLayout.baseAt(s[1], s[3])).toBe(i)
		end
	end)
	it("pods and pedestals never share a spot", function()
		for k = 1, Config.Bases.MaxPods do
			local p = WorldLayout.podPosition(1, k)
			for j = 1, Config.Bases.MaxPedestals do
				local q = WorldLayout.pedestalPosition(1, j)
				local d = math.sqrt((p[1] - q[1]) ^ 2 + (p[3] - q[3]) ^ 2)
				expect(d).toBeAtLeast(6)
			end
		end
	end)
end)
