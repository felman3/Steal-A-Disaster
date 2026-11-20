--[[
	BaseService — base assignment, spawning, base visuals, and base protection.

	* Every slot's base is built once at startup; joining players claim the
	  first free slot (attribute "BaseSlot").
	* Characters spawn on their own base.
	* "Lock Base" raises a shield for a few seconds (duration from the Shield
	  upgrade): no one can steal from a locked base and non-owners standing
	  inside are pushed out. Cooldown applies.
	* refresh(player) updates the owner sign, locked/unlocked pods & pedestals
	  and tier decor so upgrades are visible in the world.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local WorldLayout = require(Shared.Logic.WorldLayout)
local UpgradeLogic = require(Shared.Logic.UpgradeLogic)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local RateLimiter = require(Shared.Logic.RateLimiter)

local BaseBuilder = require(ServerScriptService.Server.World.BaseBuilder)

local BaseService = { Name = "BaseService" }

local S
local bases = {} -- [slot] = refs
local owners = {} -- [slot] = player
local slotOf = {} -- [player] = slot
local shields = {} -- [slot] = { untilT, cooldownUntil }
local shieldLimiter

function BaseService:Init(registry)
	S = registry
	local folder = Instance.new("Folder")
	folder.Name = "Bases"
	folder.Parent = workspace:WaitForChild("World")
	for i = 1, #Config.Bases.Slots do
		bases[i] = BaseBuilder.build(folder, i)
		shields[i] = { untilT = 0, cooldownUntil = 0 }
		self:_resetVisuals(i)
	end
	local rl = Config.RateLimits.Shield
	shieldLimiter = RateLimiter.new(rl[1], rl[2])
end

function BaseService:base(slot)
	return bases[slot]
end

function BaseService:slotOf(player)
	return slotOf[player]
end

function BaseService:ownerOf(slot)
	return owners[slot]
end

function BaseService:baseOf(player)
	local s = slotOf[player]
	return s and bases[s] or nil
end

function BaseService:inOwnBase(player, pos)
	local s = slotOf[player]
	if not s then
		return false
	end
	return WorldLayout.inBase(s, pos.X, pos.Z, 0)
end

function BaseService:spawnCFrame(slot)
	local p = WorldLayout.spawnPosition(slot)
	local cf = bases[slot].cf
	-- face toward the avenue (base local +X); the raw base rotation looks along local -Z,
	-- which put the camera against the entrance pylon in Studio
	return CFrame.new(p[1], p[2] + BaseBuilder.FLOOR_TOP, p[3]) * cf.Rotation * CFrame.Angles(0, -math.pi / 2, 0)
end

function BaseService:sendHome(player)
	local char = player.Character
	local s = slotOf[player]
	if not char or not s then
		return
	end
	char:PivotTo(self:spawnCFrame(s))
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
end

-- Shield -------------------------------------------------------------------
function BaseService:isShielded(slot)
	local sh = shields[slot]
	return sh ~= nil and os.clock() < sh.untilT
end

function BaseService:activateShield(player)
	local s = slotOf[player]
	local data = S.PlayerDataService:get(player)
	if not s or not data then
		return false, "No base"
	end
	if not shieldLimiter:allow(player) then
		return false, "Slow down"
	end
	local sh = shields[s]
	local now = os.clock()
	if now < sh.untilT then
		return false, "Already locked"
	end
	if now < sh.cooldownUntil then
		return false, "Shield recharging (" .. math.ceil(sh.cooldownUntil - now) .. "s)"
	end
	local duration = UpgradeLogic.shieldDuration(data.upgrades.Shield)
	sh.untilT = now + duration
	sh.cooldownUntil = sh.untilT + Config.Bases.ShieldCooldown
	player:SetAttribute("ShieldUntil", workspace:GetServerTimeNow() + duration)
	self:_applyShieldVisual(s)
	S.PlayerDataService:markDirty(player)
	return true, duration
end

function BaseService:_applyShieldVisual(slot)
	local b = bases[slot]
	b.shieldWall.Transparency = self:isShielded(slot) and 0.35 or 1
end

-- Visuals ------------------------------------------------------------------
function BaseService:_resetVisuals(slot)
	local b = bases[slot]
	b.ownerText.Text = "EMPTY BASE"
	b.infoText.Text = "Waiting for a storm chaser..."
	b.billboardName.Text = ""
	b.billboardInfo.Text = ""
	for i, pod in ipairs(b.pods) do
		self:_setLocked(pod, i > Config.Bases.StartPods, "")
	end
	for i, ped in ipairs(b.pedestals) do
		self:_setLocked(ped, i > Config.Bases.StartPedestals, "")
	end
	for _, list in pairs(b.tiers) do
		for _, d in ipairs(list) do
			d.part.Transparency = 1
		end
	end
	b.shieldWall.Transparency = 1
end

function BaseService:_setLocked(unit, locked, priceText)
	unit.locked = locked
	for _, d in ipairs(unit.model:GetDescendants()) do
		if d:IsA("BasePart") then
			local orig = d:GetAttribute("OrigTransparency")
			if orig == nil then
				orig = d.Transparency
				d:SetAttribute("OrigTransparency", orig)
			end
			if locked then
				d.Transparency = math.max(orig, 0.7)
			else
				d.Transparency = orig
			end
		end
	end
	unit.lock.Enabled = locked
	local label = unit.lock:FindFirstChild("Text")
	if label then
		label.Text = locked and ("🔒 " .. priceText) or ""
	end
end

local function tierOf(data)
	local u = data.upgrades
	local score = (u.Treadmill - 1) + (u.Carry - 1) * 3 + (u.Pods - 2) * 2 + (u.Pedestals - 4) + (u.Shield - 1) * 2
	if score >= 40 then
		return 4
	elseif score >= 18 then
		return 3
	elseif score >= 6 then
		return 2
	end
	return 1
end
BaseService.tierOf = tierOf

function BaseService:refresh(player)
	local s = slotOf[player]
	local data = S.PlayerDataService:get(player)
	if not s or not data then
		return
	end
	local b = bases[s]
	local podCount = data.upgrades.Pods
	local pedCount = data.upgrades.Pedestals
	local podCost = UpgradeLogic.nextCost(data, "Pods")
	local pedCost = UpgradeLogic.nextCost(data, "Pedestals")
	for i, pod in ipairs(b.pods) do
		local price = (i == podCount + 1 and podCost) and Util.formatMoney(podCost) or ""
		self:_setLocked(pod, i > podCount, price)
	end
	for i, ped in ipairs(b.pedestals) do
		local price = (i == pedCount + 1 and pedCost) and Util.formatMoney(pedCost) or ""
		self:_setLocked(ped, i > pedCount, price)
	end
	local tier = tierOf(data)
	for t, list in pairs(b.tiers) do
		for _, d in ipairs(list) do
			d.part.Transparency = (t <= tier) and d.transparency or 1
		end
	end
	local income = S.EconomyService and S.EconomyService:incomeOf(player) or 0
	b.ownerText.Text = string.upper(player.DisplayName) .. "'S BASE"
	b.infoText.Text = Util.formatMoney(income) .. "/s  •  " .. #data.disasters .. "/" .. pedCount .. " disasters  •  Tier " .. tier
	b.billboardName.Text = player.DisplayName
	b.billboardInfo.Text = Util.formatMoney(income) .. "/s"
	local gain = b.treadmill.gainLabel
	if gain then
		local SpeedLogic = require(Shared.Logic.SpeedLogic)
		gain.Text = "+" .. Util.formatNumber(SpeedLogic.gainPerStep(data.upgrades.Treadmill)) .. " SPEED / STEP"
	end
end

-- Assignment ---------------------------------------------------------------
function BaseService:_assign(player)
	if slotOf[player] then
		return slotOf[player]
	end
	for i = 1, #Config.Bases.Slots do
		if not owners[i] then
			owners[i] = player
			slotOf[player] = i
			player:SetAttribute("BaseSlot", i)
			bases[i].model:SetAttribute("Owner", player.UserId)
			return i
		end
	end
	return nil
end

function BaseService:_release(player)
	local s = slotOf[player]
	if not s then
		return
	end
	owners[s] = nil
	slotOf[player] = nil
	shields[s] = { untilT = 0, cooldownUntil = 0 }
	bases[s].model:SetAttribute("Owner", nil)
	self:_resetVisuals(s)
end

function BaseService:_onCharacter(player, char)
	local s = slotOf[player]
	if not s then
		return
	end
	task.defer(function()
		if char.Parent then
			char:PivotTo(self:spawnCFrame(s))
		end
	end)
end

function BaseService:Start()
	local function onPlayer(player)
		local slot = self:_assign(player)
		if not slot then
			player:Kick("Server is full — please try another server.")
			return
		end
		player.CharacterAdded:Connect(function(char)
			self:_onCharacter(player, char)
		end)
		if player.Character then
			self:_onCharacter(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		self:_release(p)
	end)
	S.PlayerDataService.Loaded:Connect(function(player)
		self:refresh(player)
	end)

	-- base terminals
	for slot, b in pairs(bases) do
		b.shieldTerminal.prompt.Triggered:Connect(function(player)
			if owners[slot] ~= player then
				S.PlayerDataService:notify(player, "That's not your base!", "error")
				return
			end
			local ok, res = self:activateShield(player)
			if ok then
				S.PlayerDataService:notify(player, "Base locked for " .. res .. "s!", "success")
			else
				S.PlayerDataService:notify(player, res, "error")
			end
		end)
		b.upgradeTerminal.prompt.Triggered:Connect(function(player)
			if owners[slot] == player then
				Remotes.get("OpenPanel"):FireClient(player, "Shop")
			end
		end)
	end
	Remotes.get("RequestShield").OnServerEvent:Connect(function(player)
		local ok, res = self:activateShield(player)
		if ok then
			S.PlayerDataService:notify(player, "Base locked for " .. res .. "s!", "success")
		else
			S.PlayerDataService:notify(player, res, "error")
		end
	end)

	-- shield upkeep: expire visuals, push intruders out
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 0.25 then
			return
		end
		acc = 0
		for slot, b in pairs(bases) do
			local shielded = self:isShielded(slot)
			if (b.shieldWall.Transparency < 1) ~= shielded then
				self:_applyShieldVisual(slot)
			end
			if shielded then
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= owners[slot] then
						local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
						if hrp and WorldLayout.inBase(slot, hrp.Position.X, hrp.Position.Z, 0) then
							local out = b.cf * CFrame.new(Config.Bases.Size / 2 + 8, 3, 0)
							p.Character:PivotTo(out)
							S.PlayerDataService:notify(p, "That base is locked!", "error")
						end
					end
				end
			end
		end
	end)
end

return BaseService
