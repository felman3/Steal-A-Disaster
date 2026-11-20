-- Quick Travel: pure rules, the server service, and the client buttons/panel.

local function boot(mode)
	local env = Env.new({ mode = mode or "server", verbose = VERBOSE })
	env.runScript("ServerScriptService.Server.Main")
	env.advance(0.5)
	local S = env.G.StealADisaster
	assert(S, "server did not boot: " .. table.concat(env.errors, "\n"))
	return env, S
end

local function noErrors(env)
	if #env.errors > 0 then
		error("runtime errors:\n" .. table.concat(env.errors, "\n----\n"), 2)
	end
	for _, w in ipairs(env.warnings) do
		if string.find(w, "[Main]", 1, true) then
			error("service failed to start: " .. w, 2)
		end
	end
end

local function pos(player)
	return player.Character.HumanoidRootPart.Position
end

local function travel(env, player, dest, arg)
	env.G.game:GetService("ReplicatedStorage").Remotes.RequestTravel.OnServerEvent:Fire(player, dest, arg)
	env.advance(0.1)
end

describe("TravelLogic", function()
	local env = Env.new({ mode = "server" })
	local T = env.require("ReplicatedStorage.Shared.Logic.TravelLogic")

	it("only unlocked zones are valid", function()
		expect(T.zoneUnlocked(0, 1)).toBe(true)
		expect(T.zoneUnlocked(0, 2)).toBe(false)
		expect(T.zoneUnlocked(600, 2)).toBe(true)
		expect(T.zoneUnlocked(1e12, 10)).toBe(false)
		expect(T.zoneUnlocked(1e12, 1.5)).toBe(false)
		expect(T.zoneUnlocked(1e12, "x")).toBe(false)
		expect(T.stealZone(0)).toBe(1)
		expect(T.stealZone(3000)).toBe(3)
	end)

	it("check rejects carrying, cooldown, bad destinations and locked zones", function()
		expect(T.check("Home", nil, 0, 0, 10, nil)).toBe(true)
		expect(T.check("Home", nil, 0, 1, 10, nil)).toBe(false)
		expect(T.check("Home", nil, 0, 0, 10, 12)).toBe(false)
		expect(T.check("Moon", nil, 0, 0, 10, nil)).toBe(false)
		expect(T.check(nil, nil, 0, 0, 10, nil)).toBe(false)
		local ok, why = T.check("Zone", 2, 0, 0, 10, nil)
		expect(ok).toBe(false)
		expect(why).toContain("600")
		expect(T.check("Zone", 2, 600, 0, 10, nil)).toBe(true)
	end)

	it("clearOffset steps aside from other players", function()
		expect(T.clearOffset({ 0, 4, 100 }, { 1, 0 }, {})).toBe(0)
		expect(T.clearOffset({ 0, 4, 100 }, { 1, 0 }, { { 0, 100 } })).toBe(5)
		expect(T.clearOffset({ 0, 4, 100 }, { 1, 0 }, { { 0, 100 }, { 5, 100 } })).toBe(-5)
	end)
end)

describe("TravelService", function()
	it("HOME, TRAIN and STEAL land at the right places", function()
		local env, S = boot()
		local p = env.addPlayer("Walker")
		env.advance(1)
		local slot = S.BaseService:slotOf(p)
		env.moveTo(p, env.D.Vector3.new(0, 4, 400))
		travel(env, p, "Home")
		local home = S.BaseService:spawnCFrame(slot).Position
		expect((pos(p) - home).Magnitude < 3).toBe(true)
		env.advance(4.1)
		travel(env, p, "Train")
		local belt = S.BaseService:base(slot).treadmill.belt.Position
		local d = pos(p) - belt
		expect(math.abs(d.X) + math.abs(d.Z) < 14).toBe(true)
		env.advance(4.1)
		travel(env, p, "Steal") -- 0 Speed -> Suburb entrance
		expect(math.abs(pos(p).X) <= 13).toBe(true)
		expect(pos(p).Z).toBe(214)
		S.PlayerDataService:get(p).speed = 3000
		env.advance(4.1)
		travel(env, p, "Steal") -- Droughtlands (zone 3)
		expect(pos(p).Z).toBe(200 + 2 * 260 + 14)
		noErrors(env)
	end)

	it("locked zones are refused and the player does not move", function()
		local env, S = boot()
		local p = env.addPlayer("Eager")
		env.advance(1)
		env.moveTo(p, env.D.Vector3.new(0, 4, 300))
		local before = pos(p)
		travel(env, p, "Zone", 5)
		expect((pos(p) - before).Magnitude < 0.01).toBe(true)
		travel(env, p, "Zone", 99)
		travel(env, p, "Zone", "1; drop")
		expect((pos(p) - before).Magnitude < 0.01).toBe(true)
		S.PlayerDataService:get(p).speed = 40000
		env.advance(1)
		travel(env, p, "Zone", 5)
		expect(pos(p).Z).toBe(200 + 4 * 260 + 14)
		noErrors(env)
	end)

	it("no travel while carrying a core (cannot skip the run home)", function()
		local env, S = boot()
		local p = env.addPlayer("Thief")
		env.advance(1)
		S.GuardianService:setEnabled(1, false)
		local entity
		for _, pt in ipairs(S.CoreSpawnService:points(1)) do
			if pt.entity and pt.entity.state == "Nest" then
				entity = pt.entity
				break
			end
		end
		env.walkTo(p, env.D.Vector3.new(entity.position.X, 3, entity.position.Z - 6))
		entity.prompt.Triggered:Fire(p)
		env.advance(0.1)
		expect(S.CarryService:count(p)).toBe(1)
		local before = pos(p)
		travel(env, p, "Home")
		expect((pos(p) - before).Magnitude < 1).toBe(true)
		expect(S.CarryService:count(p)).toBe(1)
		noErrors(env)
	end)

	it("cooldown is enforced on the server", function()
		local env, S = boot()
		local p = env.addPlayer("Spammy")
		env.advance(1)
		env.moveTo(p, env.D.Vector3.new(0, 4, 300))
		travel(env, p, "Steal")
		expect(pos(p).Z).toBe(214)
		env.moveTo(p, env.D.Vector3.new(0, 4, 300))
		travel(env, p, "Steal")
		expect(pos(p).Z).toBe(300) -- refused: cooldown
		env.advance(4.1)
		travel(env, p, "Steal")
		expect(pos(p).Z).toBe(214)
		noErrors(env)
	end)

	it("lands beside, not inside, another player", function()
		local env, S = boot()
		local a = env.addPlayer("A")
		local b = env.addPlayer("B")
		env.advance(1)
		env.moveTo(a, env.D.Vector3.new(0, 4, 214))
		travel(env, b, "Steal")
		local d = pos(b) - pos(a)
		expect(math.sqrt(d.X * d.X + d.Z * d.Z) >= 4).toBe(true)
		expect(math.abs(pos(b).X) <= 13).toBe(true)
		noErrors(env)
	end)

	it("dead players and junk arguments are ignored", function()
		local env, S = boot()
		local p = env.addPlayer("Ghost")
		env.advance(1)
		env.moveTo(p, env.D.Vector3.new(0, 4, 300))
		travel(env, p, nil)
		travel(env, p, { "Home" })
		travel(env, p, "Teleport", env.D.Vector3.new(0, 0, 2500))
		expect(pos(p).Z).toBe(300)
		p.Character:FindFirstChildOfClass("Humanoid").Health = 0
		travel(env, p, "Home")
		expect(pos(p).Z).toBe(300)
		noErrors(env)
	end)

	it("a steal right after travelling is not flagged as a teleport", function()
		local env, S = boot()
		local p = env.addPlayer("Runner")
		env.advance(1)
		S.GuardianService:setEnabled(1, false)
		travel(env, p, "Steal")
		local entity
		for _, pt in ipairs(S.CoreSpawnService:points(1)) do
			if pt.entity and pt.entity.state == "Nest" then
				entity = pt.entity
				break
			end
		end
		env.walkTo(p, env.D.Vector3.new(entity.position.X, 3, entity.position.Z - 6))
		entity.prompt.Triggered:Fire(p)
		env.advance(0.1)
		for _ = 1, 10 do
			p.Character.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame + env.D.Vector3.new(0, 0, -0.4)
			env.advance(1 / 30)
		end
		expect(S.CarryService:count(p)).toBe(1)
		noErrors(env)
	end)
end)

describe("Quick Travel UI", function()
	local function bootClient()
		local env, S = boot("both")
		local player = env.addPlayer("Client")
		env.advance(1)
		env.runScript("StarterPlayerScripts.Client.Main")
		env.advance(1)
		S.PlayerDataService:markDirty(player)
		env.advance(0.3)
		return env, S, player, player.PlayerGui.StealADisasterHud
	end

	it("has the five shortcuts; HOME travels and SHOP/ZONES open panels", function()
		local env, S, player, hud = bootClient()
		local col = hud.QuickTravel
		for _, n in ipairs({ "HomeButton", "StealButton", "ShopButton", "TrainButton", "ZonesButton" }) do
			expect(col:FindFirstChild(n) ~= nil).toBe(true)
		end
		env.moveTo(player, env.D.Vector3.new(0, 4, 300))
		col.HomeButton.Activated:Fire()
		env.advance(0.3)
		local home = S.BaseService:spawnCFrame(S.BaseService:slotOf(player)).Position
		expect((pos(player) - home).Magnitude < 3).toBe(true)
		col.ShopButton.Activated:Fire()
		expect(hud.ShopPanel.Visible).toBe(true)
		col.ZonesButton.Activated:Fire()
		expect(hud.ZonesPanel.Visible).toBe(true)
		expect(hud.ShopPanel.Visible).toBe(false)
		noErrors(env)
	end)

	it("Zones panel shows locks and travels to unlocked zones only", function()
		local env, S, player, hud = bootClient()
		local body = hud.ZonesPanel.Body
		expect(body.Zone1.Status.Text).toContain("BEST")
		expect(body.Zone2.Status.Text).toContain("600 more")
		expect(body.Zone2.Travel.Label.Text).toBe("LOCKED")
		expect(body.Zone9.ZoneName.Text).toBe("Void Realm")
		env.moveTo(player, env.D.Vector3.new(0, 4, 300))
		body.Zone2.Travel.Activated:Fire()
		env.advance(0.3)
		expect(pos(player).Z).toBe(300)
		body.Zone1.Travel.Activated:Fire()
		env.advance(0.3)
		expect(pos(player).Z).toBe(214)
		noErrors(env)
	end)
end)
