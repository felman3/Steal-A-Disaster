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

	it("HUD and world text stay TextScaled (Roblox resets it when TextWrapped is set false)", function()
		local env, S, player = boot()
		local screen = hud(player)
		expect(screen.Money.Amount.TextScaled).toBe(true)
		expect(screen.SpeedBox.Speed.TextScaled).toBe(true)
		local gate = env.G.workspace.World.Zones.Suburb.Gate.Header.GateGui
		expect(gate.ZoneName.TextScaled).toBe(true)
		expect(gate.Requirement.TextScaled).toBe(true)
		noErrors(env)
	end)

	it("index: search only finds discovered names; rarity and owned filters; owned badges", function()
		local env, S, player = boot()
		local data = S.PlayerDataService:get(player)
		data.index.DustDevil = true
		data.disasters = { { s = 1, d = "DustDevil", z = 1 }, { s = 2, d = "DustDevil", z = 1 } }
		S.PlayerDataService:markDirty(player)
		env.advance(0.3)
		local panel = hud(player).IndexPanel
		local body = panel.Body
		local cell = body.SuburbGrid.DustDevil
		expect(cell.Owned.Text).toBe("×2")
		expect(body.Progress.Text).toContain("Discovered 1 / ")
		-- searching an undiscovered disaster name finds nothing (no spoilers)
		body.Toolbar.Search.Text = "black hole"
		env.advance(0.1)
		expect(body.VoidRealmGrid.Visible).toBe(false)
		body.Toolbar.Search.Text = "dust"
		env.advance(0.1)
		expect(cell.Visible).toBe(true)
		expect(body.SuburbGrid.Visible).toBe(true)
		expect(body.OvergrowthGrid.Visible).toBe(false)
		body.Toolbar.Search.Text = ""
		body.Toolbar.Chip_Mythic.Activated:Fire()
		env.advance(0.1)
		expect(cell.Visible).toBe(false)
		body.Toolbar.Chip_All.Activated:Fire()
		body.Toolbar.OwnedOnly.Activated:Fire()
		env.advance(0.1)
		expect(cell.Visible).toBe(true)
		expect(body.OvergrowthGrid.Visible).toBe(false)
		body.Toolbar.Sort.Activated:Fire()
		env.advance(0.1)
		expect(body.Toolbar.Sort.Label.Text).toBe("SORT: RARITY")
		noErrors(env)
	end)

	it("stats panel shows server progress, income, collection and boosts", function()
		local env, S, player = boot()
		local data = S.PlayerDataService:get(player)
		data.speed = 3000
		data.money = 12345
		data.index.DustDevil = true
		data.disasters = { { s = 1, d = "DustDevil", z = 1 } }
		data.passes.DoubleCash = true
		data.boostSpeed = 300
		data.stats.hatched = 7
		S.EconomyService:recompute(player)
		S.PlayerDataService:markDirty(player)
		env.advance(0.3)
		local screen = hud(player)
		screen.LeftNav.StatsButton.Activated:Fire()
		expect(screen.StatsPanel.Visible).toBe(true)
		local body = screen.StatsPanel.Body
		expect(body.Zone.Value.Text).toBe("3. Droughtlands")
		expect(body.Next.Value.Text).toContain("Frostfall")
		expect(body.Income.Value.Text).toContain("(x2)")
		expect(body.Disasters.Value.Text).toBe("1 / 4")
		expect(body.Collection.Value.Text).toContain("1 / 37")
		expect(body.Passes.Value.Text).toBe("2x Cash")
		expect(body.Boost.Value.Text).toContain("left")
		expect(body.Hatched.Value.Text).toBe("7")
		noErrors(env)
	end)

	it("toasts and banners draw above open panels", function()
		local env, S, player = boot()
		local screen = hud(player)
		expect(screen.Toasts.ZIndex > screen.ShopPanel.ZIndex).toBe(true)
		expect(screen.Banner.ZIndex > screen.ShopPanel.ZIndex).toBe(true)
		noErrors(env)
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
		-- 3D previews: known = full color, unknown = silhouette
		env.advance(0.1)
		local vp = cell:FindFirstChild("Preview")
		expect(vp ~= nil).toBe(true)
		expect(vp.ImageColor3.R).toBe(1)
		expect(screen.IndexPanel.Body.SuburbGrid.DustDevil.Preview.ImageColor3.R).toBe(0)
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
