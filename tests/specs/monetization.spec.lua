-- Monetization: pure rules, then the real server (ProcessReceipt, Game Pass
-- ownership, prompts, Studio mock) against the mocked MarketplaceService.

local IDS = { TurboTreadmill = 9001, DoubleCash = 9002, InstantHatch = 7001, SpeedBoost = 7002, CashPack = 7003 }

-- boot the server; `configured` = give every item a (fake) Roblox id first
local function boot(configured, studio)
	local env = Env.new({ mode = "server", verbose = VERBOSE })
	env.studio = studio
	local MConfig = env.require("ReplicatedStorage.Shared.Config.MonetizationConfig")
	for key, item in pairs(MConfig.Items) do
		item.id = configured and IDS[key] or 0
	end
	env.runScript("ServerScriptService.Server.Main")
	env.advance(0.5)
	local S = env.G.StealADisaster
	assert(S, "server did not boot: " .. table.concat(env.errors, "\n"))
	return env, S, MConfig
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

-- run ProcessReceipt the way Roblox does (in its own thread) and return the decision
local function receipt(env, player, productId, purchaseId)
	local market = env.G.game:GetService("MarketplaceService")
	local result
	env.run(function()
		result = market.ProcessReceipt({ PlayerId = player and player.UserId or 999999, ProductId = productId, PurchaseId = purchaseId, CurrencySpent = 0 })
	end)
	env.advance(8, 0.25)
	return result and result.Name
end

local function fireRemote(env, name, player, ...)
	env.G.game:GetService("ReplicatedStorage").Remotes[name].OnServerEvent:Fire(player, ...)
	env.advance(0.1)
end

describe("MonetizationLogic", function()
	local env = Env.new({ mode = "server" })
	local L = env.require("ReplicatedStorage.Shared.Logic.MonetizationLogic")
	local Config = env.require("ReplicatedStorage.Shared.Config.GameConfig")
	local DataSchema = env.require("ReplicatedStorage.Shared.Logic.DataSchema")

	it("Speed multiplier is additive and never above x3", function()
		expect(L.speedMultiplier({ passes = {}, boostSpeed = 0 })).toBe(1)
		expect(L.speedMultiplier({ passes = { TurboTreadmill = true }, boostSpeed = 0 })).toBe(2)
		expect(L.speedMultiplier({ passes = {}, boostSpeed = 900 })).toBe(2)
		expect(L.speedMultiplier({ passes = { TurboTreadmill = true }, boostSpeed = 99999 })).toBe(3)
	end)

	it("Double Cash doubles income only when owned", function()
		expect(L.incomeMultiplier({ passes = {} })).toBe(1)
		expect(L.incomeMultiplier({ passes = { DoubleCash = true } })).toBe(2)
	end)

	it("Cash Pack is 10 min of base income with a zone-based minimum", function()
		-- new player: no income, Suburb only -> floor = 2/s * 600 * 2
		expect(L.cashPackAmount(0, 0)).toBe(2400)
		-- Frostfall unlocked (12K Speed), small income -> Frostfall floor 50 * 600 * 2
		expect(L.cashPackAmount(10, 12000)).toBe(60000)
		-- big income dominates the floor
		expect(L.cashPackAmount(86000, 3000000)).toBe(86000 * 600)
		expect(L.cashPackAmount(-5, 0)).toBe(2400)
	end)

	it("Instant Hatch picks the requested pod, else the longest one, never ready or stolen pods", function()
		local pods = {
			{ s = 1, c = "GustCore", z = 1, p = 0 },
			{ s = 2, c = "BlackHoleCore", z = 9, p = 0 },
			{ s = 3, c = "HailCore", z = 1, p = 1e6 }, -- already ready
		}
		expect(L.pickHatchPod(pods, 1, nil).s).toBe(1)
		expect(L.pickHatchPod(pods, 3, nil).s).toBe(2) -- ready pod is not eligible
		expect(L.pickHatchPod(pods, nil, nil).s).toBe(2)
		local stolen = function(s)
			return s == 2
		end
		expect(L.pickHatchPod(pods, 2, stolen).s).toBe(1)
		expect(L.pickHatchPod({}, nil, nil) == nil).toBe(true)
	end)

	it("receipt history is bounded and searchable", function()
		local list = {}
		for i = 1, 230 do
			L.addReceipt(list, "p" .. i)
		end
		expect(#list).toBe(200)
		expect(L.hasReceipt(list, "p230")).toBe(true)
		expect(L.hasReceipt(list, "p1")).toBe(false)
	end)

	it("sanitizer keeps only valid monetization data", function()
		local receipts = {}
		for i = 1, 250 do
			table.insert(receipts, "r" .. i)
		end
		table.insert(receipts, 42)
		table.insert(receipts, string.rep("x", 500))
		local d = DataSchema.sanitize({ passes = { TurboTreadmill = true, DoubleCash = "yes", FakePass = true, CashPack = true }, boostSpeed = -10, hatchCredits = 1e9, receipts = receipts })
		expect(d.passes.TurboTreadmill).toBe(true)
		expect(d.passes.DoubleCash == nil).toBe(true)
		expect(d.passes.FakePass == nil).toBe(true)
		expect(d.passes.CashPack == nil).toBe(true) -- a product is never a pass
		expect(d.boostSpeed).toBe(0)
		expect(d.hatchCredits).toBe(1000)
		expect(#d.receipts).toBe(200)
		expect(d.receipts[200]).toBe("r250")
		local fresh = DataSchema.default()
		expect(fresh.hatchCredits).toBe(0)
		expect(#fresh.receipts).toBe(0)
		expect(Config ~= nil).toBe(true)
	end)
end)

describe("Developer Products (ProcessReceipt)", function()
	it("starts cleanly and owns ProcessReceipt", function()
		local env = boot(true, false)
		expect(type(env.G.game:GetService("MarketplaceService").ProcessReceipt)).toBe("function")
		noErrors(env)
	end)

	it("Cash Pack grants once per PurchaseId (duplicate receipts are ignored)", function()
		local env, S = boot(true, false)
		local p = env.addPlayer("Buyer", 3001)
		env.advance(1)
		local data = S.PlayerDataService:get(p)
		local before = data.money
		expect(receipt(env, p, IDS.CashPack, "purchase-A")).toBe("PurchaseGranted")
		expect(data.money - before).toBe(2400)
		expect(receipt(env, p, IDS.CashPack, "purchase-A")).toBe("PurchaseGranted")
		expect(receipt(env, p, IDS.CashPack, "purchase-A")).toBe("PurchaseGranted")
		expect(data.money - before).toBe(2400)
		expect(receipt(env, p, IDS.CashPack, "purchase-B")).toBe("PurchaseGranted")
		expect(data.money - before).toBe(4800)
		noErrors(env)
	end)

	it("Cash Pack uses base income, not Double Cash income", function()
		local env, S = boot(true, false)
		local p = env.addPlayer("Rich", 3002)
		env.advance(1)
		local data = S.PlayerDataService:get(p)
		data.disasters = { { s = 1, d = "BlackHole", z = 9 } }
		data.passes.DoubleCash = true
		local base = env.require("ReplicatedStorage.Shared.Logic.EconomyLogic").totalIncome(data.disasters)
		local before = data.money
		expect(receipt(env, p, IDS.CashPack, "rich-1")).toBe("PurchaseGranted")
		local gained = data.money - before
		-- income keeps flowing during the call, so allow a few seconds of it
		expect(gained).toBeAtLeast(base * 600)
		expect(gained).toBeAtMost(base * 600 + base * 2 * 12)
		noErrors(env)
	end)

	it("returns NotProcessedYet for an unknown player or product, and grants nothing", function()
		local env, S = boot(true, false)
		local p = env.addPlayer("Here", 3003)
		env.advance(1)
		local data = S.PlayerDataService:get(p)
		local before = data.money
		expect(receipt(env, nil, IDS.CashPack, "ghost-1")).toBe("NotProcessedYet")
		expect(receipt(env, p, 123456, "unknown-product")).toBe("NotProcessedYet")
		expect(data.money).toBe(before)
		noErrors(env)
	end)

	it("save failure -> NotProcessedYet; the retry is granted without a second reward", function()
		local env, S = boot(true, false)
		local p = env.addPlayer("Flaky", 3004)
		env.advance(1)
		local data = S.PlayerDataService:get(p)
		local before = data.money
		env.datastore.failNext = 3 -- every attempt of this save fails
		expect(receipt(env, p, IDS.CashPack, "flaky-1")).toBe("NotProcessedYet")
		expect(data.money - before).toBe(2400)
		-- Roblox retries the same receipt later
		expect(receipt(env, p, IDS.CashPack, "flaky-1")).toBe("PurchaseGranted")
		expect(data.money - before).toBe(2400)
		noErrors(env)
	end)

	it("never grants into a session whose save failed to load", function()
		local env, S = boot(true, false)
		env.datastore.failNext = 100
		local p = env.addPlayer("NoLoad", 3005)
		env.advance(30, 0.25)
		env.datastore.failNext = 0
		local data = S.PlayerDataService:get(p)
		expect(data ~= nil).toBe(true)
		local before = data.money
		expect(receipt(env, p, IDS.CashPack, "noload-1")).toBe("NotProcessedYet")
		expect(data.money).toBe(before)
	end)

	it("receipts survive a reconnect: a replayed PurchaseId is not granted again", function()
		local env, S = boot(true, false)
		local p = env.addPlayer("Rejoin", 3006)
		env.advance(1)
		expect(receipt(env, p, IDS.CashPack, "rejoin-1")).toBe("PurchaseGranted")
		local money = S.PlayerDataService:get(p).money
		env.removePlayer(p)
		env.advance(1)
		local p2 = env.addPlayer("Rejoin", 3006)
		env.advance(1)
		local d2 = S.PlayerDataService:get(p2)
		expect(d2.money).toBeAtLeast(money)
		local after = d2.money
		expect(receipt(env, p2, IDS.CashPack, "rejoin-1")).toBe("PurchaseGranted")
		expect(d2.money).toBe(after)
		noErrors(env)
	end)

	it("Speed Boost: 15 min of play time, repeat buys add time, multiplier stays capped", function()
		local env, S = boot(true, false)
		local p = env.addPlayer("Runner", 3007)
		env.advance(1)
		local data = S.PlayerDataService:get(p)
		expect(receipt(env, p, IDS.SpeedBoost, "boost-1")).toBe("PurchaseGranted")
		expect(data.boostSpeed).toBeAtLeast(880)
		expect(data.boostSpeed).toBeAtMost(900)
		expect(S.SpeedService:addSteps(p, 1)).toBe(10) -- 5 per step x2
		expect(receipt(env, p, IDS.SpeedBoost, "boost-2")).toBe("PurchaseGranted")
		expect(data.boostSpeed).toBeAtLeast(1770)
		expect(S.SpeedService:addSteps(p, 1)).toBe(10) -- still x2, not x4
		data.passes.TurboTreadmill = true
		expect(S.SpeedService:addSteps(p, 1)).toBe(15) -- Turbo + Boost = x3 max
		-- counts down while playing and expires
		local left = data.boostSpeed
		env.advance(10, 0.5)
		expect(data.boostSpeed).toBeAtMost(left - 9)
		data.boostSpeed = 1
		env.advance(2, 0.5)
		expect(data.boostSpeed).toBe(0)
		expect(S.SpeedService:addSteps(p, 1)).toBe(10) -- Turbo only
		noErrors(env)
	end)

	it("Instant Hatch finishes the requested pod with the same core, rarity and mutation", function()
		local env, S, MConfig = boot(true, false)
		local Config = env.require("ReplicatedStorage.Shared.Config.GameConfig")
		local p = env.addPlayer("Hatcher", 3008)
		env.advance(1)
		local data = S.PlayerDataService:get(p)
		-- two slow cores so neither finishes on its own during the test
		S.IncubatorService:receive(p, { c = "BlackHoleCore", z = 9 })
		S.IncubatorService:receive(p, { c = "BlackHoleCore", z = 9, m = "Golden" })
		-- owner asks to hatch pod 2 (the Black Hole) via its world prompt
		local root = S.BaseService:baseOf(p).pods[2].root
		expect(root.HatchPrompt.Enabled).toBe(true)
		root.HatchPrompt.Triggered:Fire(p)
		env.advance(0.1)
		expect(#env.market.prompts).toBe(1)
		expect(env.market.prompts[1].id).toBe(IDS.InstantHatch)
		expect(#data.disasters).toBe(0) -- prompting grants nothing
		expect(receipt(env, p, IDS.InstantHatch, "hatch-1")).toBe("PurchaseGranted")
		expect(#data.disasters).toBe(1)
		local d = data.disasters[1]
		expect(d.d).toBe(Config.Cores.BlackHoleCore.disaster)
		expect(d.m).toBe("Golden")
		expect(Config.Disasters[d.d].rarity).toBe(Config.Cores.BlackHoleCore.rarity)
		expect(#data.pods).toBe(1) -- the other (unmutated) core is still incubating
		expect(data.pods[1].m == nil).toBe(true)
		expect(receipt(env, p, IDS.InstantHatch, "hatch-1")).toBe("PurchaseGranted")
		expect(#data.pods).toBe(1) -- duplicate receipt: nothing else hatched
		noErrors(env)
	end)

	it("Instant Hatch with nothing incubating becomes a saved credit, used later for free", function()
		local env, S = boot(true, false)
		local p = env.addPlayer("Early", 3009)
		env.advance(1)
		local data = S.PlayerDataService:get(p)
		expect(receipt(env, p, IDS.InstantHatch, "credit-1")).toBe("PurchaseGranted")
		expect(data.hatchCredits).toBe(1)
		S.IncubatorService:receive(p, { c = "HailCore", z = 1 })
		local prompts = #env.market.prompts
		fireRemote(env, "RequestPurchase", p, "InstantHatch", 1)
		expect(data.hatchCredits).toBe(0)
		expect(#env.market.prompts).toBe(prompts) -- used the credit, no new purchase
		expect(#data.disasters).toBe(1)
		noErrors(env)
	end)

	it("a pod being stolen cannot be instant-hatched", function()
		local env, S = boot(true, false)
		local owner = env.addPlayer("Owner", 3010)
		local thief = env.addPlayer("Thief", 3011)
		env.advance(1)
		S.IncubatorService:receive(owner, { c = "HailCore", z = 1 })
		S.IncubatorService:beginTransit(owner, 1, thief)
		local root = S.BaseService:baseOf(owner).pods[1].root
		expect(root.HatchPrompt.Enabled).toBe(false)
		fireRemote(env, "RequestPurchase", owner, "InstantHatch", 1)
		expect(#env.market.prompts).toBe(0)
		noErrors(env)
	end)
end)

describe("Game Passes", function()
	it("purchase-finished grants the pass; Double Cash doubles income, Turbo doubles steps", function()
		local env, S = boot(true, false)
		local p = env.addPlayer("Fan", 3020)
		env.advance(1)
		local data = S.PlayerDataService:get(p)
		data.disasters = { { s = 1, d = "DustDevil", z = 1 } }
		S.DisasterCollectionService:rebuildAll(p)
		local base = S.EconomyService:recompute(p)
		local market = env.G.game:GetService("MarketplaceService")
		market.PromptGamePassPurchaseFinished:Fire(p, IDS.DoubleCash, true)
		market.PromptGamePassPurchaseFinished:Fire(p, IDS.TurboTreadmill, false) -- cancelled
		env.advance(0.1)
		expect(data.passes.DoubleCash).toBe(true)
		expect(data.passes.TurboTreadmill == nil).toBe(true)
		expect(S.EconomyService:incomeOf(p)).toBe(base * 2)
		expect(S.SpeedService:addSteps(p, 1)).toBe(5)
		-- the pedestal label shows what the disaster really earns now
		local label = S.BaseService:baseOf(p).pedestals[1].root.DisasterLabel
		expect(label.Income.Text).toBe("$4/s")
		market.PromptGamePassPurchaseFinished:Fire(p, IDS.TurboTreadmill, true)
		env.advance(0.1)
		expect(S.SpeedService:addSteps(p, 1)).toBe(10)
		noErrors(env)
	end)

	it("ownership is verified on join, cached across reconnects, and survives an API outage", function()
		local env, S = boot(true, false)
		env.market.owned["3021:" .. IDS.TurboTreadmill] = true
		local p = env.addPlayer("Owner", 3021)
		env.advance(2)
		expect(S.PlayerDataService:get(p).passes.TurboTreadmill).toBe(true)
		env.removePlayer(p)
		env.advance(1)
		-- rejoin while MarketplaceService is down: cached entitlement still applies
		env.market.ownershipFails = true
		local p2 = env.addPlayer("Owner", 3021)
		env.advance(2)
		expect(S.PlayerDataService:get(p2).passes.TurboTreadmill).toBe(true)
		expect(S.SpeedService:addSteps(p2, 1)).toBe(10)
		env.removePlayer(p2)
		env.advance(1)
		-- API back and says not owned (refund): entitlement removed
		env.market.ownershipFails = false
		env.market.owned["3021:" .. IDS.TurboTreadmill] = nil
		local p3 = env.addPlayer("Owner", 3021)
		env.advance(2)
		expect(S.PlayerDataService:get(p3).passes.TurboTreadmill == nil).toBe(true)
		noErrors(env)
	end)

	it("already-owned passes are not prompted again", function()
		local env, S = boot(true, false)
		local p = env.addPlayer("Owned", 3022)
		env.advance(1)
		S.PlayerDataService:get(p).passes.DoubleCash = true
		fireRemote(env, "RequestPurchase", p, "DoubleCash")
		expect(#env.market.prompts).toBe(0)
		noErrors(env)
	end)
end)

describe("purchase requests never grant on a live server", function()
	it("configured items only open the Roblox prompt", function()
		local env, S = boot(true, false)
		local p = env.addPlayer("Live", 3030)
		env.advance(1)
		local data = S.PlayerDataService:get(p)
		local money = data.money
		fireRemote(env, "RequestPurchase", p, "CashPack")
		env.advance(1.1)
		fireRemote(env, "RequestPurchase", p, "TurboTreadmill")
		expect(#env.market.prompts).toBe(2)
		expect(env.market.prompts[1].kind).toBe("product")
		expect(env.market.prompts[2].kind).toBe("pass")
		expect(data.money).toBe(money)
		expect(data.passes.TurboTreadmill == nil).toBe(true)
		noErrors(env)
	end)

	it("unconfigured items (id 0) are not sold and not granted outside Studio", function()
		local env, S = boot(false, false)
		local p = env.addPlayer("Live0", 3031)
		env.advance(1)
		local data = S.PlayerDataService:get(p)
		local money = data.money
		fireRemote(env, "RequestPurchase", p, "CashPack")
		env.advance(1.1)
		fireRemote(env, "RequestPurchase", p, "DoubleCash")
		expect(#env.market.prompts).toBe(0)
		expect(data.money).toBe(money)
		expect(data.passes.DoubleCash == nil).toBe(true)
		noErrors(env)
	end)

	it("bad remote arguments and spam are ignored", function()
		local env, S = boot(true, false)
		local p = env.addPlayer("Spam", 3032)
		env.advance(1)
		fireRemote(env, "RequestPurchase", p, nil)
		fireRemote(env, "RequestPurchase", p, { "CashPack" })
		fireRemote(env, "RequestPurchase", p, "FreeMoney")
		for _ = 1, 20 do
			fireRemote(env, "RequestPurchase", p, "CashPack")
		end
		expect(#env.market.prompts).toBeAtMost(3)
		noErrors(env)
	end)

	it("only the base owner can use the treadmill Speed Boost prompt", function()
		local env, S = boot(true, false)
		local owner = env.addPlayer("Owner", 3033)
		local other = env.addPlayer("Other", 3034)
		env.advance(1)
		local prompt = S.BaseService:baseOf(owner).treadmill.console.BoostPrompt
		prompt.Triggered:Fire(other)
		env.advance(0.1)
		expect(#env.market.prompts).toBe(0)
		prompt.Triggered:Fire(owner)
		env.advance(0.1)
		expect(#env.market.prompts).toBe(1)
		expect(env.market.prompts[1].id).toBe(IDS.SpeedBoost)
		noErrors(env)
	end)
end)

describe("Studio mock purchases", function()
	it("unconfigured items can be test-bought in Studio through the real grant path", function()
		local env, S = boot(false, true)
		local p = env.addPlayer("Tester", 3040)
		env.advance(1)
		local data = S.PlayerDataService:get(p)
		local money = data.money
		fireRemote(env, "RequestPurchase", p, "CashPack")
		env.advance(1)
		expect(data.money - money).toBeAtLeast(2400)
		fireRemote(env, "RequestPurchase", p, "TurboTreadmill")
		env.advance(1)
		expect(data.passes.TurboTreadmill).toBe(true)
		expect(#data.receipts).toBe(1) -- the mock product went through receipt recording
		expect(#env.market.prompts).toBe(0)
		noErrors(env)
	end)
end)

describe("shop Boosts section (client)", function()
	local function bootClient(configured, studio, prices)
		local env = Env.new({ mode = "both", verbose = VERBOSE })
		env.studio = studio
		local MConfig = env.require("ReplicatedStorage.Shared.Config.MonetizationConfig")
		for key, item in pairs(MConfig.Items) do
			item.id = configured and IDS[key] or 0
		end
		for id, price in pairs(prices or {}) do
			env.market.prices[id] = price
		end
		env.runScript("ServerScriptService.Server.Main")
		env.advance(0.5)
		local S = env.G.StealADisaster
		local player = env.addPlayer("Client")
		env.advance(1)
		env.runScript("StarterPlayerScripts.Client.Main")
		env.advance(1)
		S.PlayerDataService:markDirty(player) -- push a fresh snapshot to the client
		env.advance(0.3)
		local body = player.PlayerGui.StealADisasterHud.ShopPanel.Body
		return env, S, player, body
	end

	local function buttonText(row)
		local b = row.Buy
		local inner = b:FindFirstChild("Label") or b:FindFirstChildWhichIsA("TextLabel")
		return inner and inner.Text or b.Text
	end

	it("shows Roblox prices, marks owned passes, and Buy only sends a request", function()
		local env, S, player, body = bootClient(true, false, { [IDS.TurboTreadmill] = 149, [IDS.DoubleCash] = 149, [IDS.CashPack] = 79 })
		expect(body:FindFirstChild("BoostsHeader") ~= nil).toBe(true)
		expect(buttonText(body.Boost_TurboTreadmill)).toBe("R$ 149")
		expect(buttonText(body.Boost_CashPack)).toBe("R$ 79")
		expect(body.Boost_CashPack.Effect.Text).toContain("$2.4K")
		S.PlayerDataService:get(player).passes.DoubleCash = true
		S.PlayerDataService:markDirty(player)
		env.advance(0.3)
		expect(buttonText(body.Boost_DoubleCash)).toBe("OWNED ✓")
		body.Boost_CashPack.Buy.Activated:Fire()
		env.advance(0.3)
		expect(#env.market.prompts).toBe(1)
		expect(env.market.prompts[1].id).toBe(IDS.CashPack)
		noErrors(env)
	end)

	it("hides unconfigured items on live servers and labels Studio test prices", function()
		local env, S, player, body = bootClient(false, false)
		expect(body.Boost_TurboTreadmill.Visible).toBe(false)
		expect(body.Boost_CashPack.Visible).toBe(false)
		local env2, S2, player2, body2 = bootClient(false, true)
		expect(body2.Boost_TurboTreadmill.Visible).toBe(true)
		expect(buttonText(body2.Boost_TurboTreadmill)).toBe("R$ 149 (test)")
		expect(buttonText(body2.Boost_CashPack)).toBe("R$ 79 (test)")
		noErrors(env)
		noErrors(env2)
	end)
end)

describe("shop categories", function()
	it("groups upgrades and Robux items under headers, and every product has a row", function()
		local env = Env.new({ mode = "both", verbose = VERBOSE })
		env.studio = true
		env.runScript("ServerScriptService.Server.Main")
		env.advance(0.5)
		local S = env.G.StealADisaster
		local player = env.addPlayer("Client")
		env.advance(1)
		env.runScript("StarterPlayerScripts.Client.Main")
		env.advance(1)
		S.PlayerDataService:markDirty(player)
		env.advance(0.3)
		local body = player.PlayerGui.StealADisasterHud.ShopPanel.Body
		for _, h in ipairs({ "SpeedHeader", "BaseHeader", "IncubatorHeader", "BoostsHeader", "ProductsHeader" }) do
			expect(body:FindFirstChild(h) ~= nil).toBe(true)
		end
		-- each row sits after its header
		expect(body.Treadmill.LayoutOrder > body.SpeedHeader.LayoutOrder).toBe(true)
		expect(body.Pods.LayoutOrder > body.IncubatorHeader.LayoutOrder).toBe(true)
		expect(body.Boost_TurboTreadmill.LayoutOrder < body.ProductsHeader.LayoutOrder).toBe(true)
		expect(body.Boost_SpeedBoost.LayoutOrder > body.ProductsHeader.LayoutOrder).toBe(true)
		expect(body.Boost_InstantHatch.Visible).toBe(true)
		noErrors(env)
	end)

	it("an unaffordable upgrade says how much money is missing", function()
		local env = Env.new({ mode = "server", verbose = VERBOSE })
		env.runScript("ServerScriptService.Server.Main")
		env.advance(0.5)
		local S = env.G.StealADisaster
		local p = env.addPlayer("Broke")
		env.advance(1)
		S.PlayerDataService:get(p).money = 10
		env.G.game:GetService("ReplicatedStorage").Remotes.RequestUpgrade.OnServerEvent:Fire(p, "Treadmill")
		env.advance(0.1)
		local found = false
		for _, r in ipairs(env.M.remoteLog) do
			if r.remote == "Notify" and r.target == p and type(r.args[1]) == "string" and string.find(r.args[1], "$30 more", 1, true) then
				found = true
			end
		end
		expect(found).toBe(true)
		noErrors(env)
	end)
end)
