--[[
	MonetizationService — Game Passes and Developer Products (server only).

	Developer Products are granted ONLY in MarketplaceService.ProcessReceipt:
	  * unknown player / data not loaded / unsaved session -> NotProcessedYet
	    (Roblox retries later, e.g. when the player rejoins);
	  * PurchaseId already recorded -> PurchaseGranted without granting again;
	  * otherwise grant, record the PurchaseId in the player's saved data, save,
	    and only then return PurchaseGranted. If the save fails we return
	    NotProcessedYet; the retry finds the recorded PurchaseId and does not
	    grant twice.

	Game Passes are verified with UserOwnsGamePassAsync on join and cached in
	saved data, so the entitlement survives reconnects and API outages.

	The RequestPurchase remote never grants anything on a live server: it only
	opens Roblox's purchase prompt. In Studio, items whose id is still 0 use a
	mock purchase that runs the same grant code (no Robux involved).
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local MConfig = require(Shared.Config.MonetizationConfig)
local MonetizationLogic = require(Shared.Logic.MonetizationLogic)
local EconomyLogic = require(Shared.Logic.EconomyLogic)
local RateLimiter = require(Shared.Logic.RateLimiter)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local MonetizationService = { Name = "MonetizationService" }

local S
local limiter
local productKeyById = {}
local passKeyById = {}
local pendingHatch = {} -- [player] = podSlot the player asked to hatch
local mockCounter = 0

function MonetizationService:Init(registry)
	S = registry
	limiter = RateLimiter.new(1, 3)
	productKeyById = MonetizationLogic.keysById("DeveloperProduct")
	passKeyById = MonetizationLogic.keysById("GamePass")
end

function MonetizationService:mockEnabled()
	return MConfig.MockInStudio == true and RunService:IsStudio()
end

local function notify(player, text, kind)
	S.PlayerDataService:notify(player, text, kind or "success")
end

function MonetizationService:_applyEffects(player)
	local data = S.PlayerDataService:get(player)
	if not data then
		return
	end
	player:SetAttribute("SpeedMult", MonetizationLogic.speedMultiplier(data))
	player:SetAttribute("BoostSeconds", math.ceil(data.boostSpeed or 0))
	S.EconomyService:recompute(player)
	S.BaseService:refresh(player)
	S.DisasterCollectionService:refreshIncomeLabels(player)
	S.PlayerDataService:markDirty(player)
end

-- Game Passes -------------------------------------------------------------------
function MonetizationService:owns(player, key)
	return MonetizationLogic.owns(S.PlayerDataService:get(player), key)
end

function MonetizationService:grantPass(player, key)
	local data = S.PlayerDataService:get(player)
	local item = MConfig.Items[key]
	if not data or not item or item.type ~= "GamePass" or data.passes[key] then
		return false
	end
	data.passes[key] = true
	self:_applyEffects(player)
	notify(player, item.icon .. " " .. item.name .. " unlocked! " .. item.benefit .. ".")
	return true
end

-- Re-check every configured pass with Roblox. A failed API call keeps the
-- cached entitlement; a successful "not owned" (e.g. refund) removes it.
function MonetizationService:refreshPasses(player)
	for key, item in pairs(MConfig.Items) do
		if item.type == "GamePass" and item.id > 0 then
			local ok, owned = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, item.id)
			end)
			local data = S.PlayerDataService:get(player)
			if player.Parent ~= Players or not data then
				return
			end
			if ok then
				data.passes[key] = owned == true or nil
			end
		end
	end
	self:_applyEffects(player)
end

-- Developer Products ------------------------------------------------------------
function MonetizationService:_instantHatch(player, preferredSlot)
	local data = S.PlayerDataService:get(player)
	local pod = MonetizationLogic.pickHatchPod(data.pods, preferredSlot, function(slot)
		return S.IncubatorService:isInTransit(player, slot)
	end)
	if pod and S.IncubatorService:finishPod(player, pod) then
		notify(player, "🥚 Instant Hatch! " .. Config.Cores[pod.c].name .. " is done.")
		return true
	end
	-- nothing to hatch right now: keep it as a credit so the purchase is never lost
	data.hatchCredits = data.hatchCredits + 1
	S.PlayerDataService:markDirty(player)
	notify(player, "🥚 No pod was incubating — your Instant Hatch is saved for later.", "info")
	return true
end

-- Apply one Developer Product. Must not yield (it runs before the receipt is recorded).
function MonetizationService:grantProduct(player, key)
	local data = S.PlayerDataService:get(player)
	local item = MConfig.Items[key]
	if not data or not item or item.type ~= "DeveloperProduct" then
		return false
	end
	if key == "InstantHatch" then
		local slot = pendingHatch[player]
		pendingHatch[player] = nil
		return self:_instantHatch(player, slot)
	elseif key == "SpeedBoost" then
		data.boostSpeed = (data.boostSpeed or 0) + item.durationSeconds
		self:_applyEffects(player)
		notify(player, "⚡ Speed Boost active: x" .. MonetizationLogic.speedMultiplier(data) .. " treadmill Speed for " .. Util.formatTime(data.boostSpeed) .. ".")
		return true
	elseif key == "CashPack" then
		local amount = MonetizationLogic.cashPackAmount(EconomyLogic.totalIncome(data.disasters), data.speed)
		S.EconomyService:addMoney(player, amount, "cashpack")
		notify(player, "💵 Cash Pack: +" .. Util.formatMoney(amount) .. "!")
		return true
	end
	return false
end

-- Shared by ProcessReceipt and the Studio mock. Returns a ProductPurchaseDecision.
function MonetizationService:_grantReceipt(player, key, purchaseId)
	local NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet
	local data = S.PlayerDataService:get(player)
	if not data or not S.PlayerDataService:canGrantPurchases(player) then
		return NOT_YET
	end
	if MonetizationLogic.hasReceipt(data.receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local ok, granted = pcall(self.grantProduct, self, player, key)
	if not ok or not granted then
		warn("[Monetization] could not grant " .. tostring(key) .. " to " .. player.Name .. ": " .. tostring(granted))
		return NOT_YET
	end
	-- recorded in the same data document as the reward, so they persist together
	MonetizationLogic.addReceipt(data.receipts, purchaseId)
	S.PlayerDataService:markDirty(player)
	if not S.PlayerDataService:saveForReceipt(player) then
		return NOT_YET
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService:processReceipt(receipt)
	local NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet
	if type(receipt) ~= "table" or receipt.PurchaseId == nil then
		return NOT_YET
	end
	local key = productKeyById[receipt.ProductId]
	if not key then
		warn("[Monetization] receipt for unknown product " .. tostring(receipt.ProductId))
		return NOT_YET
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return NOT_YET
	end
	return self:_grantReceipt(player, key, tostring(receipt.PurchaseId))
end

-- Purchase requests (prompts) ------------------------------------------------------
-- Opens Roblox's purchase prompt. On a live server this never grants anything.
function MonetizationService:requestPurchase(player, key, opts)
	if not limiter:allow(player) then
		return false, "rate"
	end
	local item = type(key) == "string" and MConfig.Items[key] or nil
	local data = S.PlayerDataService:get(player)
	if not item or not data then
		return false, "invalid"
	end
	if item.type == "GamePass" and data.passes[key] then
		notify(player, "You already own " .. item.name .. ".", "info")
		return false, "owned"
	end
	if key == "InstantHatch" then
		local slot = type(opts) == "table" and tonumber(opts.podSlot) or nil
		local inTransit = function(s)
			return S.IncubatorService:isInTransit(player, s)
		end
		local pod = MonetizationLogic.pickHatchPod(data.pods, slot, inTransit)
		if not pod then
			notify(player, "No core is incubating right now.", "info")
			return false, "no pod"
		end
		if data.hatchCredits > 0 then
			data.hatchCredits = data.hatchCredits - 1
			S.IncubatorService:finishPod(player, pod)
			S.PlayerDataService:markDirty(player)
			notify(player, "🥚 Used a saved Instant Hatch on " .. Config.Cores[pod.c].name .. ".")
			return true, "credit"
		end
		pendingHatch[player] = pod.s
	end
	if item.id > 0 then
		local ok, err = pcall(function()
			if item.type == "GamePass" then
				MarketplaceService:PromptGamePassPurchase(player, item.id)
			else
				MarketplaceService:PromptProductPurchase(player, item.id)
			end
		end)
		if not ok then
			warn("[Monetization] prompt failed: " .. tostring(err))
			return false, "prompt failed"
		end
		return true, "prompted"
	end
	if self:mockEnabled() then
		mockCounter = mockCounter + 1
		if item.type == "GamePass" then
			self:grantPass(player, key)
		else
			self:_grantReceipt(player, key, "studio-mock-" .. tostring(player.UserId) .. "-" .. mockCounter)
		end
		notify(player, "[Studio test purchase — no Robux spent]", "info")
		return true, "mock"
	end
	notify(player, item.name .. " isn't available yet.", "info")
	return false, "unconfigured"
end

-- World prompts ----------------------------------------------------------------------
function MonetizationService:_wireTreadmillPrompts()
	for slot = 1, #Config.Bases.Slots do
		local base = S.BaseService:base(slot)
		local console = base and base.treadmill and base.treadmill.console
		if console then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "BoostPrompt"
			prompt.ActionText = "Speed Boost"
			prompt.ObjectText = "⚡ 2× treadmill Speed • 15 min"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 7
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("BaseSlot", slot)
			prompt:SetAttribute("OwnerOnly", true)
			prompt:SetAttribute("Range", 7)
			prompt.Parent = console
			prompt.Triggered:Connect(function(player)
				if S.BaseService:slotOf(player) == slot then
					self:requestPurchase(player, "SpeedBoost")
				end
			end)
		end
	end
end

function MonetizationService:Start()
	MarketplaceService.ProcessReceipt = function(receipt)
		return self:processReceipt(receipt)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passKeyById[passId]
		if purchased and key then
			self:grantPass(player, key)
		end
	end)
	Remotes.get("RequestPurchase").OnServerEvent:Connect(function(player, key, podSlot)
		self:requestPurchase(player, key, { podSlot = podSlot })
	end)
	S.PlayerDataService.Loaded:Connect(function(player)
		self:_applyEffects(player)
		task.spawn(function()
			self:refreshPasses(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		pendingHatch[player] = nil
	end)
	self:_wireTreadmillPrompts()

	-- Speed Boost counts down only while the player is in game
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 1 then
			return
		end
		local elapsed = math.min(acc, 5)
		acc = 0
		for _, player in ipairs(S.PlayerDataService:loadedPlayers()) do
			local data = S.PlayerDataService:get(player)
			if data and (data.boostSpeed or 0) > 0 then
				data.boostSpeed = math.max(0, data.boostSpeed - elapsed)
				player:SetAttribute("BoostSeconds", math.ceil(data.boostSpeed))
				S.PlayerDataService:markDirty(player)
				if data.boostSpeed <= 0 then
					self:_applyEffects(player)
					notify(player, "⚡ Speed Boost ended.", "info")
				else
					S.BaseService:refreshTreadmillLabel(player)
				end
			end
		end
	end)
end

-- test hooks
function MonetizationService:_pendingHatch()
	return pendingHatch
end

return MonetizationService
