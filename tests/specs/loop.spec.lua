-- Integration tests: run the real server (Main.server.lua + all services) inside
-- the mock DataModel and play through the core loop and its edge cases.

local function boot(opts)
	local env = Env.new({ mode = "server", verbose = VERBOSE })
	env.runScript("ServerScriptService.Server.Main")
	env.advance(0.5)
	local S = env.G.StealADisaster
	assert(S, "server did not finish booting: " .. table.concat(env.errors, "\n"))
	return env, S
end

local function V(x, y, z)
	return Vector3 and Vector3.new(x, y, z)
end

local function noErrors(env)
	if #env.errors > 0 then
		error("runtime errors:\n" .. table.concat(env.errors, "\n----\n"), 2)
	end
end

local function hrpOf(p)
	return p.Character:FindFirstChild("HumanoidRootPart")
end

-- put the guardian of zone i to sleep for a long time (deterministic tests)
local function sleepGuardian(S, i)
	S.GuardianService:setEnabled(i, false)
end

local function remoteCalls(env, name, target)
	local out = {}
	for _, r in ipairs(env.M.remoteLog) do
		if r.remote == name and (target == nil or r.target == target) then
			table.insert(out, r)
		end
	end
	return out
end

local function trainOnTreadmill(env, S, player, seconds)
	local D = env.D
	local base = S.BaseService:baseOf(player)
	local belt = base.treadmill.belt
	local hrp = hrpOf(player)
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	hrp.CFrame = D.CFrame.new(belt.Position + D.Vector3.new(0, 3, 0))
	env.M.state[hum].props.MoveDirection = D.Vector3.new(1, 0, 0)
	env.advance(seconds, 1 / 30)
	env.M.state[hum].props.MoveDirection = D.Vector3.zero
end

local function firstNestEntity(S, zoneIndex)
	for _, p in ipairs(S.CoreSpawnService:points(zoneIndex)) do
		if p.entity and p.entity.state == "Nest" then
			return p.entity
		end
	end
end

local function walkHome(env, S, player)
	local slot = S.BaseService:slotOf(player)
	local D = env.D
	local cfg = env.require("ReplicatedStorage.Shared.Config.GameConfig")
	local s = cfg.Bases.Slots[slot]
	-- out of the zone along the route, then to the base front, then inside
	local hrp = hrpOf(player)
	env.walkTo(player, D.Vector3.new(0, 3, hrp.Position.Z))
	env.walkTo(player, D.Vector3.new(0, 3, s.z))
	env.walkTo(player, D.Vector3.new(s.x, 3, s.z))
end

describe("server boot", function()
	it("boots all services and builds the world without errors", function()
		local env, S = boot()
		noErrors(env)
		local world = env.G.workspace:FindFirstChild("World")
		expect(world ~= nil).toBe(true)
		expect(world:FindFirstChild("Zones") ~= nil).toBe(true)
		expect(#world.Zones:GetChildren()).toBe(9)
		expect(#world.Bases:GetChildren()).toBe(8)
		expect(#world.Guardians:GetChildren()).toBe(9)
		-- every nest point has a core
		for zi = 1, 9 do
			for _, p in ipairs(S.CoreSpawnService:points(zi)) do
				expect(p.entity ~= nil).toBe(true)
			end
		end
	end)
end)

describe("vertical slice loop", function()
	it("train -> steal -> carry -> deliver -> incubate -> hatch -> income -> upgrade", function()
		local env, S = boot()
		local D = env.D
		local player = env.addPlayer("Alice")
		env.advance(1)
		noErrors(env)
		local data = S.PlayerDataService:get(player)
		expect(data ~= nil).toBe(true)
		local slot = S.BaseService:slotOf(player)
		expect(slot).toBe(1)
		-- spawned on own base
		expect(S.BaseService:inOwnBase(player, hrpOf(player).Position)).toBe(true)

		-- 1) TRAIN
		trainOnTreadmill(env, S, player, 10)
		expect(data.speed).toBeNear(200, 5) -- 4 steps/s * 10 s * 5 per step
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		expect(hum.WalkSpeed).toBeGreaterThan(16)

		-- 2) STEAL from Suburb nest
		sleepGuardian(S, 1)
		local entity = firstNestEntity(S, 1)
		env.walkTo(player, D.Vector3.new(entity.position.X, 3, entity.position.Z - 6))
		noErrors(env)
		entity.prompt.Triggered:Fire(player)
		env.advance(0.1)
		expect(S.CarryService:count(player)).toBe(1)
		expect(entity.state).toBe("Carried")
		-- 3) CARRY slows you down
		local walkCarrying = hum.WalkSpeed
		expect(walkCarrying).toBeLessThan(S.SpeedService:maxWalkFor(player))
		expect(player:GetAttribute("Carrying")).toBe(1)

		-- 4) RETURN HOME & DELIVER
		walkHome(env, S, player)
		env.advance(0.2)
		noErrors(env)
		expect(S.CarryService:count(player)).toBe(0)
		expect(#data.pods).toBe(1)
		expect(data.stats.stolen).toBe(1)
		expect(hum.WalkSpeed).toBeNear(S.SpeedService:maxWalkFor(player), 0.01)

		-- 5) INCUBATE (visible fill rises)
		local pod = data.pods[1]
		local base = S.BaseService:baseOf(player)
		local fill = base.pods[1].fill
		env.advance(5)
		expect(fill.Size.X).toBeGreaterThan(0.1)

		-- 6) HATCH
		local IncubatorLogic = env.require("ReplicatedStorage.Shared.Logic.IncubatorLogic")
		env.advance(IncubatorLogic.incubationTime(pod.c) + 1, 0.25)
		noErrors(env)
		expect(#data.pods).toBe(0)
		expect(#data.disasters).toBe(1)
		expect(data.index[data.disasters[1].d]).toBe(true)
		local pedModel = base.pedestals[1].model
		local hasDisaster = false
		for _, c in ipairs(pedModel:GetChildren()) do
			if c:IsA("Model") then
				hasDisaster = true
			end
		end
		expect(hasDisaster).toBe(true)

		-- 7) PASSIVE INCOME
		local income = S.EconomyService:incomeOf(player)
		expect(income).toBeGreaterThan(0)
		local before = data.money
		env.advance(10, 0.25)
		expect(data.money - before).toBeNear(income * 10, income * 1.5)

		-- 8) UPGRADE via remote (server-validated)
		data.money = data.money + 1000
		local remote = env.G.game:GetService("ReplicatedStorage").Remotes.RequestUpgrade
		remote.OnServerEvent:Fire(player, "Treadmill")
		env.advance(0.1)
		expect(data.upgrades.Treadmill).toBe(2)
		noErrors(env)
	end)
end)

describe("stealing rules & exploits", function()
	it("enforces the zone speed gate", function()
		local env, S = boot()
		local D = env.D
		local player = env.addPlayer("Bob")
		env.advance(1)
		sleepGuardian(S, 2)
		local entity = firstNestEntity(S, 2)
		env.moveTo(player, D.Vector3.new(entity.position.X, 3, entity.position.Z - 5))
		env.advance(0.1)
		S.CarryService:resetTracking(player)
		entity.prompt.Triggered:Fire(player)
		env.advance(0.1)
		expect(S.CarryService:count(player)).toBe(0)
		expect(entity.state).toBe("Nest")
		local notes = remoteCalls(env, "Notify", player)
		expect(#notes).toBeGreaterThan(0)
		noErrors(env)
	end)

	it("rejects pickups from too far away", function()
		local env, S = boot()
		local player = env.addPlayer("Far")
		env.advance(1)
		local entity = firstNestEntity(S, 1)
		entity.prompt.Triggered:Fire(player) -- player is at base, hundreds of studs away
		env.advance(0.1)
		expect(S.CarryService:count(player)).toBe(0)
	end)

	it("drops cores back to the nest on teleport", function()
		local env, S = boot()
		local D = env.D
		local player = env.addPlayer("Tele")
		env.advance(1)
		sleepGuardian(S, 1)
		local entity = firstNestEntity(S, 1)
		env.walkTo(player, D.Vector3.new(entity.position.X, 3, entity.position.Z - 6))
		entity.prompt.Triggered:Fire(player)
		env.advance(0.1)
		expect(S.CarryService:count(player)).toBe(1)
		-- exploit: teleport straight into the base
		local slot = S.BaseService:slotOf(player)
		local cf = S.BaseService:spawnCFrame(slot)
		hrpOf(player).CFrame = cf
		env.advance(0.1)
		local data = S.PlayerDataService:get(player)
		expect(S.CarryService:count(player)).toBe(0)
		expect(#data.pods).toBe(0)
		expect(entity.state).toBe("Nest")
		expect(entity.model ~= nil).toBe(true)
	end)

	it("spawns every base's players facing the central avenue", function()
		local env, S = boot()
		for slot = 1, 8 do
			local cf = S.BaseService:spawnCFrame(slot)
			local look = cf.LookVector
			-- bases sit on both sides of x = 0; facing the avenue means looking back toward x = 0
			expect(math.abs(look.X) > 0.9).toBe(true)
			expect(look.X * cf.Position.X < 0).toBe(true)
		end
	end)

	it("returns the core when the carrier dies or leaves", function()
		local env, S = boot()
		local D = env.D
		local player = env.addPlayer("Dies")
		env.advance(1)
		sleepGuardian(S, 1)
		local entity = firstNestEntity(S, 1)
		env.walkTo(player, D.Vector3.new(entity.position.X, 3, entity.position.Z - 6))
		entity.prompt.Triggered:Fire(player)
		env.advance(0.1)
		player.Character:FindFirstChildOfClass("Humanoid").Health = 0
		env.advance(0.1)
		expect(S.CarryService:count(player)).toBe(0)
		expect(entity.state).toBe("Nest")

		-- pick up again and disconnect
		env.loadCharacter(player)
		env.advance(0.2)
		env.walkTo(player, D.Vector3.new(entity.position.X, 3, entity.position.Z - 6))
		entity.prompt.Triggered:Fire(player)
		env.advance(0.1)
		expect(entity.state).toBe("Carried")
		env.removePlayer(player)
		env.advance(0.5)
		expect(entity.state).toBe("Nest")
		noErrors(env)
	end)

	it("guardian chases and tags a carrier, returning the core", function()
		local env, S = boot()
		local D = env.D
		local player = env.addPlayer("Slow")
		env.advance(1)
		local entity = firstNestEntity(S, 1)
		env.walkTo(player, D.Vector3.new(entity.position.X, 3, entity.position.Z - 6))
		entity.prompt.Triggered:Fire(player)
		env.advance(0.1)
		expect(S.CarryService:count(player)).toBe(1)
		local g = S.GuardianService:get(1)
		S.GuardianService:setEnabled(1, true)
		S.GuardianService:_setState(g, "Patrol")
		-- carrier stands still next to the nest; guardian must reach and tag
		local tagged = false
		for _ = 1, 400 do
			env.step(1 / 30)
			if S.CarryService:count(player) == 0 then
				tagged = true
				break
			end
		end
		expect(tagged).toBe(true)
		expect(entity.state).toBe("Nest")
		noErrors(env)
	end)

	it("can't carry more than capacity", function()
		local env, S = boot()
		local D = env.D
		local player = env.addPlayer("Greedy")
		env.advance(1)
		sleepGuardian(S, 1)
		local pts = S.CoreSpawnService:points(1)
		local e1, e2 = pts[1].entity, pts[2].entity
		env.walkTo(player, D.Vector3.new(e1.position.X, 3, e1.position.Z))
		e1.prompt.Triggered:Fire(player)
		env.walkTo(player, D.Vector3.new(e2.position.X, 3, e2.position.Z))
		e2.prompt.Triggered:Fire(player)
		env.advance(0.1)
		expect(S.CarryService:count(player)).toBe(1)
		expect(e2.state).toBe("Nest")
	end)
end)

describe("player vs player stealing", function()
	local function setupVictim(env, S, D)
		local victim = env.addPlayer("Victim")
		local thief = env.addPlayer("Thief")
		env.advance(1)
		local vdata = S.PlayerDataService:get(victim)
		S.IncubatorService:receive(victim, { c = "TornadoCore", z = 1, p = 10 })
		env.advance(0.1)
		expect(#vdata.pods).toBe(1)
		return victim, thief, vdata
	end

	it("thief steals an incubating core and delivers it", function()
		local env, S = boot()
		local D = env.D
		local victim, thief, vdata = setupVictim(env, S, D)
		local tdata = S.PlayerDataService:get(thief)
		local vslot = S.BaseService:slotOf(victim)
		local WL = env.require("ReplicatedStorage.Shared.Logic.WorldLayout")
		local p = WL.podPosition(vslot, 1)
		-- victim walks away from their base
		env.moveTo(victim, D.Vector3.new(0, 3, 150))
		env.advance(0.1)
		env.walkTo(thief, D.Vector3.new(p[1] + 4, 3, p[3]))
		local prompt = S.BaseService:base(vslot).pods[1].root:FindFirstChild("PodStealPrompt")
		expect(prompt.Enabled).toBe(true)
		prompt.Triggered:Fire(thief)
		env.advance(0.1)
		expect(S.CarryService:count(thief)).toBe(1)
		expect(#vdata.pods).toBe(1) -- still owned by victim while in transit
		-- the pod is frozen while stolen
		local progress = vdata.pods[1].p
		env.advance(2)
		expect(vdata.pods[1].p).toBe(progress)
		walkHome(env, S, thief)
		env.advance(0.2)
		expect(#vdata.pods).toBe(0)
		expect(#tdata.pods).toBe(1)
		expect(tdata.pods[1].c).toBe("TornadoCore")
		-- incubation progress is kept (and continues once it's in the thief's pod)
		expect(tdata.pods[1].p).toBeAtLeast(progress)
		expect(tdata.pods[1].p).toBeLessThan(progress + 8)
		expect(tdata.stats.robbed).toBe(1)
		noErrors(env)
	end)

	it("owner tagging the thief returns the core", function()
		local env, S = boot()
		local D = env.D
		local victim, thief, vdata = setupVictim(env, S, D)
		local vslot = S.BaseService:slotOf(victim)
		local WL = env.require("ReplicatedStorage.Shared.Logic.WorldLayout")
		local p = WL.podPosition(vslot, 1)
		env.moveTo(victim, D.Vector3.new(0, 3, 150))
		env.walkTo(thief, D.Vector3.new(p[1] + 4, 3, p[3]))
		S.BaseService:base(vslot).pods[1].root.PodStealPrompt.Triggered:Fire(thief)
		env.advance(0.1)
		expect(S.CarryService:count(thief)).toBe(1)
		-- owner runs into the thief
		env.moveTo(victim, hrpOf(thief).Position + D.Vector3.new(2, 0, 0))
		S.CarryService:resetTracking(victim)
		env.advance(0.1)
		expect(S.CarryService:count(thief)).toBe(0)
		expect(#vdata.pods).toBe(1)
		expect(S.IncubatorService:isInTransit(victim, 1)).toBe(false)
		noErrors(env)
	end)

	it("victim leaving mid-steal cancels the theft (no duplication)", function()
		local env, S = boot()
		local D = env.D
		local victim, thief, vdata = setupVictim(env, S, D)
		local vslot = S.BaseService:slotOf(victim)
		local WL = env.require("ReplicatedStorage.Shared.Logic.WorldLayout")
		local p = WL.podPosition(vslot, 1)
		env.moveTo(victim, D.Vector3.new(0, 3, 150))
		env.walkTo(thief, D.Vector3.new(p[1] + 4, 3, p[3]))
		S.BaseService:base(vslot).pods[1].root.PodStealPrompt.Triggered:Fire(thief)
		env.advance(0.1)
		local victimId = victim.UserId
		env.removePlayer(victim)
		env.advance(1)
		expect(S.CarryService:count(thief)).toBe(0)
		walkHome(env, S, thief)
		env.advance(0.2)
		local tdata = S.PlayerDataService:get(thief)
		expect(#tdata.pods).toBe(0)
		-- victim's saved data still has the pod
		local store = env.datastore.stores["StealADisaster_PlayerData_v1/global"]
		local saved = store._data["u_" .. victimId]
		expect(saved ~= nil).toBe(true)
		expect(#saved.pods).toBe(1)
		noErrors(env)
	end)

	it("locked bases can't be robbed", function()
		local env, S = boot()
		local D = env.D
		local victim, thief, vdata = setupVictim(env, S, D)
		local vslot = S.BaseService:slotOf(victim)
		local ok = S.BaseService:activateShield(victim)
		expect(ok).toBe(true)
		local WL = env.require("ReplicatedStorage.Shared.Logic.WorldLayout")
		local p = WL.podPosition(vslot, 1)
		local okSteal = S.StealService:tryStealFromBase(thief, vslot, 1)
		expect(okSteal).toBe(false)
		-- intruders get pushed out of a locked base
		env.moveTo(thief, D.Vector3.new(p[1] + 4, 3, p[3]))
		env.advance(0.5)
		expect(WL.inBase(vslot, hrpOf(thief).Position.X, hrpOf(thief).Position.Z)).toBe(false)
		-- shield expires and recharges
		env.advance(31, 0.25)
		expect(S.BaseService:isShielded(vslot)).toBe(false)
		local again, why = S.BaseService:activateShield(victim)
		expect(again).toBe(false)
		noErrors(env)
	end)
end)

describe("persistence", function()
	it("saves on leave and restores on rejoin", function()
		local env, S = boot()
		local p = env.addPlayer("Saver", 4242)
		env.advance(1)
		local data = S.PlayerDataService:get(p)
		data.money = 12345
		data.speed = 777
		S.IncubatorService:receive(p, { c = "HailCore", z = 1 })
		env.removePlayer(p)
		env.advance(1)
		local p2 = env.addPlayer("Saver", 4242)
		env.advance(1)
		local d2 = S.PlayerDataService:get(p2)
		expect(d2.money).toBeAtLeast(12345)
		expect(d2.speed).toBe(777)
		expect(#d2.pods).toBe(1)
		noErrors(env)
	end)

	it("survives DataStore failures with retries", function()
		local env, S = boot()
		env.datastore.failNext = 2
		local p = env.addPlayer("Flaky", 5151)
		env.advance(10, 0.25)
		expect(S.PlayerDataService:isLoaded(p)).toBe(true)
		noErrors(env)
	end)

	it("sanitizes tampered saved data", function()
		local env, S = boot()
		local store = env.G.game:GetService("DataStoreService"):GetDataStore("StealADisaster_PlayerData_v1")
		store:SetAsync("u_6161", { money = -50, speed = "lots", upgrades = { Pods = 999 }, disasters = { { s = 1, d = "Hax" } } })
		local p = env.addPlayer("Hacker", 6161)
		env.advance(1)
		local d = S.PlayerDataService:get(p)
		expect(d.money).toBe(0)
		expect(d.speed).toBe(0)
		expect(d.upgrades.Pods).toBe(8)
		expect(#d.disasters).toBe(0)
		noErrors(env)
	end)
end)

describe("events", function()
	it("refresh + Chaos Frenzy rerolls world cores but never touches owned data", function()
		local env, S = boot()
		local player = env.addPlayer("Eve")
		env.advance(1)
		local data = S.PlayerDataService:get(player)
		S.IncubatorService:receive(player, { c = "GlacierCore", z = 4 })
		data.money = 500
		local before = {}
		for zi = 1, 9 do
			for pi, pt in ipairs(S.CoreSpawnService:points(zi)) do
				before[zi * 100 + pi] = pt.entity.uid
			end
		end
		-- jump to just before the refresh
		S.EventService:skip(299 - S.EventService:elapsed())
		env.advance(0.3)
		expect(S.EventService:phase()).toBe("Warning")
		env.advance(1.2)
		expect(S.EventService:phase()).toBe("Frenzy")
		expect(S.EventService:incubationRate()).toBe(4)
		local changed = 0
		for zi = 1, 9 do
			for pi, pt in ipairs(S.CoreSpawnService:points(zi)) do
				if pt.entity.uid ~= before[zi * 100 + pi] then
					changed = changed + 1
				end
			end
		end
		expect(changed).toBe(54)
		local chaos = 0
		for zi = 1, 9 do
			for _, e in ipairs(S.CoreSpawnService:entitiesInZone(zi)) do
				if e.chaos then
					chaos = chaos + 1
				end
			end
		end
		expect(chaos).toBe(3)
		expect(#data.pods).toBe(1)
		expect(data.money).toBeAtLeast(500)
		env.advance(10.5, 0.25)
		expect(S.EventService:phase()).toBe("Normal")
		chaos = 0
		for zi = 1, 9 do
			for _, e in ipairs(S.CoreSpawnService:entitiesInZone(zi)) do
				if e.chaos then
					chaos = chaos + 1
				end
			end
		end
		expect(chaos).toBe(0)
		noErrors(env)
	end)
end)

describe("remote validation", function()
	it("ignores malformed and spammed upgrade requests", function()
		local env, S = boot()
		local p = env.addPlayer("Spammer")
		env.advance(1)
		local data = S.PlayerDataService:get(p)
		local remote = env.G.game:GetService("ReplicatedStorage").Remotes.RequestUpgrade
		remote.OnServerEvent:Fire(p, nil)
		remote.OnServerEvent:Fire(p, 42)
		remote.OnServerEvent:Fire(p, { "Treadmill" })
		remote.OnServerEvent:Fire(p, "Treadmill") -- no money
		env.advance(0.1)
		expect(data.upgrades.Treadmill).toBe(1)
		data.money = 1e12
		for _ = 1, 50 do
			remote.OnServerEvent:Fire(p, "Treadmill")
		end
		env.advance(0.1)
		-- burst of 6 allowed, rest rate-limited
		expect(data.upgrades.Treadmill).toBeAtMost(8)
		noErrors(env)
	end)
end)

describe("studio dev commands", function()
	it("chat commands work in Studio", function()
		local env, S = boot()
		local p = env.addPlayer("Dev")
		env.advance(1)
		local data = S.PlayerDataService:get(p)
		p.Chatted:Fire("/money 5000")
		p.Chatted:Fire("/speed 13000")
		p.Chatted:Fire("/core GlacierCore")
		env.advance(0.1)
		expect(data.money).toBeAtLeast(5000)
		expect(data.speed).toBe(13000)
		expect(#data.pods).toBe(1)
		p.Chatted:Fire("/hatch")
		env.advance(0.1)
		expect(#data.disasters).toBe(1)
		p.Chatted:Fire("/frenzy")
		env.advance(2.5)
		expect(S.EventService:phase()).toBe("Frenzy")
		p.Chatted:Fire("/reset")
		env.advance(0.1)
		expect(#data.disasters).toBe(0)
		expect(data.speed).toBe(0)
		noErrors(env)
	end)
end)
