-- Client integration: server + client in one VM ("both" mode). Remotes are
-- bridged to the local player, RenderStepped fires, and the real HUD runs.

local function boot()
	local env = Env.new({ mode = "both", verbose = VERBOSE })
	env.runScript("ServerScriptService.Server.Main")
	env.advance(0.5)
	local S = env.G.StealADisaster
	local player = env.addPlayer("Client")
	env.advance(1)
	env.runScript("StarterPlayerScripts.Client.Main")
	env.advance(0.5)
	return env, S, player
end

local function noErrors(env)
	if #env.errors > 0 then
		error("runtime errors:\n" .. table.concat(env.errors, "\n----\n"), 2)
	end
end

local function hud(player)
	return player.PlayerGui:FindFirstChild("StealADisasterHud")
end

describe("client HUD", function()
	it("mounts the HUD, left nav and panels without errors", function()
		local env, S, player = boot()
		noErrors(env)
		local screen = hud(player)
		expect(screen ~= nil).toBe(true)
		expect(screen:FindFirstChild("Money") ~= nil).toBe(true)
		expect(screen:FindFirstChild("LeftNav") ~= nil).toBe(true)
		expect(#screen.LeftNav:GetChildren()).toBeAtLeast(3)
		expect(screen:FindFirstChild("ShopPanel").Visible).toBe(false)
	end)

	it("money and speed follow server sync", function()
		local env, S, player = boot()
		local data = S.PlayerDataService:get(player)
		data.money = 12345
		data.speed = 650
		S.PlayerDataService:markDirty(player)
		env.advance(0.3)
		local screen = hud(player)
		expect(screen.Money.Amount.Text).toBe("$12.3K")
		expect(screen.SpeedBox.Speed.Text).toBe("⚡ 650 SPEED")
		expect(screen.SpeedBox.BarBg.Next.Text).toContain("DROUGHTLANDS")
		noErrors(env)
	end)

	it("shop button opens the panel and Buy sends a validated upgrade", function()
		local env, S, player = boot()
		local data = S.PlayerDataService:get(player)
		data.money = 1000
		S.PlayerDataService:markDirty(player)
		env.advance(0.3)
		local screen = hud(player)
		screen.LeftNav.ShopButton.Activated:Fire()
		env.advance(0.1)
		expect(screen.ShopPanel.Visible).toBe(true)
		local row = screen.ShopPanel.Body.Treadmill
		expect(row.Buy.Label.Text).toBe("$40")
		row.Buy.Activated:Fire()
		env.advance(0.4)
		expect(data.upgrades.Treadmill).toBe(2)
		expect(row.Buy.Label.Text).toBe("$86")
		-- close button
		screen.ShopPanel.Header.Close.Activated:Fire()
		expect(screen.ShopPanel.Visible).toBe(false)
		noErrors(env)
	end)

	it("index shows discovered disasters", function()
		local env, S, player = boot()
		local data = S.PlayerDataService:get(player)
		data.index.MiniTornado = true
		S.PlayerDataService:markDirty(player)
		env.advance(0.3)
		local screen = hud(player)
		screen.LeftNav.IndexButton.Activated:Fire()
		local cell = screen.IndexPanel.Body.SuburbGrid.MiniTornado
		expect(cell.DisasterName.Text).toBe("Mini Tornado")
		expect(screen.IndexPanel.Body.SuburbGrid.DustDevil.DisasterName.Text).toBe("???")
		expect(screen.IndexPanel.Body.Progress.Text).toContain("1 / 37")
		noErrors(env)
	end)

	it("zone entry announces and carrying shows the run-home objective + waypoint", function()
		local env, S, player = boot()
		local D = env.D
		S.GuardianService:setEnabled(1, false)
		local entity
		for _, p in ipairs(S.CoreSpawnService:points(1)) do
			entity = p.entity
			break
		end
		local screen = hud(player)
		env.walkTo(player, D.Vector3.new(0, 3, 215))
		env.advance(0.3)
		expect(screen.Banner.Visible).toBe(true)
		expect(screen.Banner.Title.Text).toBe("SUBURB")
		env.walkTo(player, D.Vector3.new(entity.position.X, 3, entity.position.Z - 6))
		entity.prompt.Triggered:Fire(player)
		env.advance(0.4)
		expect(screen.CarryBanner.Visible).toBe(true)
		expect(screen.CarryBanner.Title.Text).toContain("RUN HOME")
		expect(env.G.workspace:FindFirstChild("HomeWaypoint") ~= nil).toBe(true)
		noErrors(env)
	end)

	it("animates tagged models near the camera", function()
		local env, S, player = boot()
		local WorldFx = env.require("StarterPlayerScripts.Client.World.WorldFx")
		local count = 0
		for _ in pairs(WorldFx._animated()) do
			count = count + 1
		end
		expect(count).toBeGreaterThan(10)
		-- move the camera near a nest so something is in range
		local cam = env.G.workspace.CurrentCamera
		local entity = S.CoreSpawnService:points(1)[1].entity
		cam.CFrame = env.D.CFrame.new(entity.position + env.D.Vector3.new(0, 5, 10))
		env.advance(0.2)
		expect((env.bulkMoves or 0)).toBeGreaterThan(0)
		noErrors(env)
	end)

	it("hides steal prompts on your own base", function()
		local env, S, player = boot()
		S.IncubatorService:receive(player, { c = "GustCore", z = 1 })
		env.advance(0.2)
		local base = S.BaseService:baseOf(player)
		local prompt = base.pods[1].root:FindFirstChild("PodStealPrompt")
		expect(prompt.Enabled).toBe(false)
		noErrors(env)
	end)
end)
