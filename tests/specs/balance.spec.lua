-- Progression balance: simulate a reasonable player (greedy upgrades, trains
-- when pods are busy, runs to the furthest unlocked zone otherwise) and check
-- that every zone unlocks at a reachable pace.

local env = Env.new({ mode = "server" })
local Config = env.require("ReplicatedStorage.Shared.Config.GameConfig")
local SpeedLogic = env.require("ReplicatedStorage.Shared.Logic.SpeedLogic")
local CarryLogic = env.require("ReplicatedStorage.Shared.Logic.CarryLogic")
local EconomyLogic = env.require("ReplicatedStorage.Shared.Logic.EconomyLogic")
local IncubatorLogic = env.require("ReplicatedStorage.Shared.Logic.IncubatorLogic")
local SpawnLogic = env.require("ReplicatedStorage.Shared.Logic.SpawnLogic")
local UpgradeLogic = env.require("ReplicatedStorage.Shared.Logic.UpgradeLogic")
local DataSchema = env.require("ReplicatedStorage.Shared.Logic.DataSchema")
local WorldLayout = env.require("ReplicatedStorage.Shared.Logic.WorldLayout")

local function simulate(seed, maxMinutes)
	local r = env.G.Random.new(seed)
	local rng = function()
		return r:NextNumber()
	end
	local data = DataSchema.default()
	local t = 0
	local unlockedAt = { [1] = 0 }
	local run = nil
	local pods = {}
	local trained = 999
	while t < maxMinutes * 60 do
		t = t + 1
		-- income
		data.money = data.money + EconomyLogic.totalIncome(data.disasters)
		-- greedy upgrades: cheapest affordable, but keep pods/pedestals sensible
		local bought = true
		while bought do
			bought = false
			local best, bestCost
			for _, id in ipairs(Config.UpgradeOrder) do
				local cost = UpgradeLogic.nextCost(data, id)
				if cost and cost <= data.money and (not bestCost or cost < bestCost) then
					if id ~= "Shield" then
						best, bestCost = id, cost
					end
				end
			end
			if best then
				UpgradeLogic.buy(data, best)
				bought = true
			end
		end
		-- incubation
		local keep = {}
		for _, pod in ipairs(pods) do
			if IncubatorLogic.advance(pod, 1, 1) then
				local slot = DataSchema.freeSlot(data.disasters, data.upgrades.Pedestals)
				local entry = { d = Config.Cores[pod.c].disaster, m = pod.m, z = pod.z }
				if slot then
					entry.s = slot
					table.insert(data.disasters, entry)
				else
					-- replace the weakest if the new one is better
					local worst, wi
					for i, d in ipairs(data.disasters) do
						if not worst or EconomyLogic.incomeFor(d) < EconomyLogic.incomeFor(worst) then
							worst, wi = d, i
						end
					end
					if worst and EconomyLogic.incomeFor(entry) > EconomyLogic.incomeFor(worst) then
						data.money = data.money + EconomyLogic.valueFor(worst)
						entry.s = worst.s
						data.disasters[wi] = entry
					else
						data.money = data.money + EconomyLogic.valueFor(entry)
					end
				end
			else
				table.insert(keep, pod)
			end
		end
		pods = keep
		-- activity
		if run then
			run.left = run.left - 1
			if run.left <= 0 then
				for _, c in ipairs(run.cores) do
					table.insert(pods, { c = c.c, m = c.m, z = c.z, p = 0 })
				end
				run = nil
			end
		elseif #pods < data.upgrades.Pods and trained >= 30 then
			trained = 0
			local zi = SpeedLogic.highestUnlockedZone(data.speed)
			local zone = Config.Zones[zi]
			local cap = math.min(CarryLogic.capacityForLevel(data.upgrades.Carry), data.upgrades.Pods - #pods)
			local cores = {}
			local ids = {}
			for _ = 1, cap do
				local c = SpawnLogic.pickCore(zone, rng, false)
				table.insert(cores, { c = c, m = SpawnLogic.rollMutation(rng, 1), z = zi })
				table.insert(ids, c)
			end
			local walk = SpeedLogic.walkSpeedFor(data.speed)
			local nest = WorldLayout.nestCenter(zi)
			local dist = nest[3] + 140 -- from a base to the nest
			local mult = CarryLogic.walkMultiplier(CarryLogic.totalWeight(ids))
			-- out, grab (with a little dodging), back slowed; 25% failed attempts add a retry
			local duration = dist / walk + 6 + dist / (walk * mult)
			run = { left = math.ceil(duration * 1.25), cores = cores }
		else
			trained = trained + 1
			data.speed = data.speed + SpeedLogic.gainPerStep(data.upgrades.Treadmill) * Config.Speed.StepsPerSecond
		end
		local zi = SpeedLogic.highestUnlockedZone(data.speed)
		if not unlockedAt[zi] then
			for k = 1, zi do
				unlockedAt[k] = unlockedAt[k] or t
			end
		end
		if zi == #Config.Zones then
			break
		end
	end
	return unlockedAt, t, data
end

describe("progression balance", function()
	it("every zone unlocks at a reachable pace (simulated player)", function()
		local results = {}
		for seed = 1, 5 do
			local unlockedAt, total = simulate(seed * 101, 240)
			table.insert(results, unlockedAt)
		end
		local lines = {}
		for i, zone in ipairs(Config.Zones) do
			local sum, n, worstGap = 0, 0, 0
			for _, u in ipairs(results) do
				if u[i] then
					sum = sum + u[i]
					n = n + 1
					if i > 1 and u[i - 1] then
						worstGap = math.max(worstGap, u[i] - u[i - 1])
					end
				end
			end
			local avg = n > 0 and sum / n or -1
			table.insert(lines, string.format("%-13s req %-9s avg unlock %6.1f min  (worst gap %4.1f min, %d/5 runs)", zone.name, tostring(zone.speedReq), avg / 60, worstGap / 60, n))
			lines[#lines + 1] = nil
			results.checks = results.checks or {}
			table.insert(results.checks, { n = n, gap = worstGap, i = i })
		end
		print("\n      " .. table.concat(lines, "\n      "))
		for _, c in ipairs(results.checks) do
			expect(c.n).toBe(5)
			if c.i > 1 then
				expect(c.gap).toBeAtMost(20 * 60)
				expect(c.gap).toBeAtLeast(1 * 60)
			end
		end
		local finalAvg = 0
		for _, u in ipairs(results) do
			finalAvg = finalAvg + u[#Config.Zones] / #results
		end
		expect(finalAvg).toBeAtMost(110 * 60)
		expect(finalAvg).toBeAtLeast(35 * 60)
	end)
end)
