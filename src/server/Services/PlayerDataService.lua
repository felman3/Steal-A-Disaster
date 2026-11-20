--[[
	PlayerDataService — loading, saving and syncing player data.

	* DataStore UpdateAsync with retries and a soft session lock (another server
	  holding a fresh lock delays the load; a stale lock is taken over).
	* Everything loaded passes through DataSchema.sanitize().
	* If the DataStore is unreachable (e.g. Studio without API access) the
	  session runs from memory and is flagged `noSave` so real data is never
	  overwritten with defaults.
	* Releasing fires BEFORE the final save so other services can resolve
	  runtime-only state (in-transit steals, carried cores) first.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local DataSchema = require(Shared.Logic.DataSchema)
local UpgradeLogic = require(Shared.Logic.UpgradeLogic)
local SpeedLogic = require(Shared.Logic.SpeedLogic)
local EconomyLogic = require(Shared.Logic.EconomyLogic)
local Util = require(Shared.Util)
local Signal = require(Shared.Signal)
local Remotes = require(Shared.Remotes)
local MonetizationLogic = require(Shared.Logic.MonetizationLogic)

local PlayerDataService = { Name = "PlayerDataService" }
PlayerDataService.Loaded = Signal.new() -- (player, data, offlineSeconds)
PlayerDataService.Changed = Signal.new() -- (player)
PlayerDataService.Releasing = Signal.new() -- (player, data)

local LOCK_TTL = 150
local RETRIES = 3
local SYNC_INTERVAL = 0.15

local S
local store
local sessions = {}
local jobId

local function key(player)
	return "u_" .. tostring(player.UserId)
end

local function isStudioAccessError(err)
	local msg = tostring(err)
	return string.find(msg, "403", 1, true) ~= nil
		or string.find(msg, "Studio", 1, true) ~= nil
		or string.find(msg, "API", 1, true) ~= nil and string.find(msg, "access", 1, true) ~= nil
end

function PlayerDataService:Init(registry)
	S = registry
	jobId = game.JobId
	if jobId == nil or jobId == "" then
		jobId = "studio-" .. tostring(math.random(1, 1e9))
	end
	local ok, res = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok then
		store = res
	else
		warn("[PlayerData] DataStore unavailable, running from memory: " .. tostring(res))
	end
end

-- Load with lock handling. Returns raw (may be nil), status ("ok"|"memory"|"failed")
local function loadRaw(player)
	if not store then
		return nil, "memory"
	end
	local lastErr
	for attempt = 1, RETRIES + 1 do
		local raw = nil
		local locked = false
		local force = attempt > RETRIES
		local ok, err = pcall(function()
			store:UpdateAsync(key(player), function(old)
				if type(old) ~= "table" then
					old = {}
				end
				local lock = old.lock
				if not force and type(lock) == "table" and lock.job ~= jobId and type(lock.t) == "number" and os.time() - lock.t < LOCK_TTL then
					locked = true
					return nil
				end
				old.lock = { job = jobId, t = os.time() }
				raw = old
				return old
			end)
		end)
		if ok and not locked then
			return raw, "ok"
		end
		if not ok then
			lastErr = err
			if isStudioAccessError(err) then
				return nil, "memory"
			end
		end
		if attempt <= RETRIES then
			task.wait(locked and 4 or (1.5 * attempt))
		end
		if player.Parent ~= Players then
			return nil, "left"
		end
	end
	warn("[PlayerData] load failed for " .. player.Name .. ": " .. tostring(lastErr))
	return nil, "failed"
end

function PlayerDataService:_onPlayerAdded(player)
	if sessions[player] then
		return
	end
	local session = { data = nil, loaded = false, dirty = false, noSave = false, lastSync = 0, syncPending = false }
	sessions[player] = session
	local raw, status = loadRaw(player)
	if sessions[player] ~= session or player.Parent ~= Players then
		return
	end
	if status == "memory" or status == "failed" then
		session.noSave = true
	end
	session.memoryOnly = status == "memory"
	local data = DataSchema.sanitize(raw)
	local offline = 0
	if data.lastSeen > 0 then
		offline = math.clamp(os.time() - data.lastSeen, 0, Config.Economy.OfflineIncubationCap)
	end
	data.lastSeen = os.time()
	session.data = data
	session.loaded = true
	player:SetAttribute("DataLoaded", true)
	if status == "failed" then
		self:notify(player, "Your save couldn't load — progress this session won't be saved.", "error")
	end
	self.Loaded:Fire(player, data, offline)
	self:markDirty(player)
end

function PlayerDataService:get(player)
	local s = sessions[player]
	if s and s.loaded then
		return s.data
	end
	return nil
end

function PlayerDataService:isLoaded(player)
	local s = sessions[player]
	return s ~= nil and s.loaded
end

function PlayerDataService:waitFor(player, timeout)
	local deadline = os.clock() + (timeout or 30)
	while player.Parent == Players and os.clock() < deadline do
		local d = self:get(player)
		if d then
			return d
		end
		task.wait(0.1)
	end
	return self:get(player)
end

function PlayerDataService:markDirty(player)
	local s = sessions[player]
	if not s or not s.loaded then
		return
	end
	s.dirty = true
	s.syncPending = true
	self.Changed:Fire(player)
end

-- Purchases may only be granted into a session that will be saved (or a Studio
-- memory session). A live session whose load FAILED runs on defaults; granting
-- there would lose the purchase, so ProcessReceipt must retry later instead.
function PlayerDataService:canGrantPurchases(player)
	local s = sessions[player]
	return s ~= nil and s.loaded and (not s.noSave or s.memoryOnly == true)
end

-- Save now and report whether it reached the DataStore. Waits for an in-flight
-- save so the snapshot written includes the latest changes (receipt records).
function PlayerDataService:saveForReceipt(player)
	local s = sessions[player]
	if not s or not s.loaded then
		return false
	end
	local deadline = os.clock() + 15
	while s.saving and os.clock() < deadline do
		task.wait(0.1)
	end
	if s.saving then
		return false
	end
	return self:save(player, false)
end

function PlayerDataService:loadedPlayers()
	local out = {}
	for p, s in pairs(sessions) do
		if s.loaded and p.Parent == Players then
			table.insert(out, p)
		end
	end
	return out
end

function PlayerDataService:save(player, release)
	local s = sessions[player]
	if not s or not s.loaded or s.noSave or not store then
		return true
	end
	if s.saving then
		-- a save is in flight; queue another afterwards
		s.saveAgain = true
		return true
	end
	s.saving = true
	s.data.lastSeen = os.time()
	local snapshot = Util.deepCopy(s.data)
	local ok, err
	for attempt = 1, RETRIES do
		ok, err = pcall(function()
			store:UpdateAsync(key(player), function(old)
				local out = Util.deepCopy(snapshot)
				if not release then
					out.lock = { job = jobId, t = os.time() }
				end
				return out
			end)
		end)
		if ok then
			break
		end
		task.wait(attempt)
	end
	s.saving = false
	if ok then
		s.dirty = false
	else
		warn("[PlayerData] save failed for " .. player.Name .. ": " .. tostring(err))
	end
	if s.saveAgain and not release then
		s.saveAgain = false
		task.spawn(function()
			self:save(player, false)
		end)
	end
	return ok
end

function PlayerDataService:_onPlayerRemoving(player)
	local s = sessions[player]
	if not s then
		return
	end
	if s.loaded then
		self.Releasing:Fire(player, s.data)
		self:save(player, true)
	end
	sessions[player] = nil
end

-- Snapshot sent to the owning client for the HUD.
function PlayerDataService:snapshot(player)
	local data = self:get(player)
	if not data then
		return nil
	end
	local costs = {}
	for id in pairs(Config.Upgrades) do
		costs[id] = UpgradeLogic.nextCost(data, id) or -1
	end
	local disasters = {}
	for _, d in ipairs(data.disasters) do
		table.insert(disasters, { d = d.d, m = d.m, s = d.s })
	end
	local carried = {}
	if S.CarryService then
		for _, item in ipairs(S.CarryService:getItems(player)) do
			table.insert(carried, { c = item.coreId, m = item.mutation, kind = item.kind })
		end
	end
	local nextZone = SpeedLogic.nextZone(data.speed)
	return {
		money = data.money,
		speed = data.speed,
		walk = SpeedLogic.walkSpeedFor(data.speed),
		gainPerStep = SpeedLogic.gainPerStep(data.upgrades.Treadmill),
		income = S.EconomyService and S.EconomyService:incomeOf(player) or 0,
		upgrades = Util.deepCopy(data.upgrades),
		costs = costs,
		index = Util.deepCopy(data.index),
		disasters = disasters,
		podsUsed = #data.pods,
		storage = #data.storage,
		carried = carried,
		baseSlot = player:GetAttribute("BaseSlot") or 0,
		nextZone = nextZone and nextZone.id or "",
		nextZoneReq = nextZone and nextZone.speedReq or 0,
		stats = Util.deepCopy(data.stats),
		shieldUntil = player:GetAttribute("ShieldUntil") or 0,
		passes = Util.deepCopy(data.passes),
		boostSpeed = data.boostSpeed,
		hatchCredits = data.hatchCredits,
		speedMult = MonetizationLogic.speedMultiplier(data),
		incomeMult = MonetizationLogic.incomeMultiplier(data),
		cashPack = MonetizationLogic.cashPackAmount(EconomyLogic.totalIncome(data.disasters), data.speed),
	}
end

function PlayerDataService:notify(player, text, kind)
	local ev = Remotes.get("Notify")
	if ev then
		ev:FireClient(player, text, kind or "info")
	end
end

function PlayerDataService:Start()
	Players.PlayerAdded:Connect(function(p)
		self:_onPlayerAdded(p)
	end)
	Players.PlayerRemoving:Connect(function(p)
		self:_onPlayerRemoving(p)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_onPlayerAdded(p)
		end)
	end

	-- throttled client sync + leaderstats
	local syncEvent = Remotes.get("Sync")
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for p, s in pairs(sessions) do
			if s.loaded and s.syncPending and now - s.lastSync >= SYNC_INTERVAL then
				s.syncPending = false
				s.lastSync = now
				local snap = self:snapshot(p)
				if snap then
					syncEvent:FireClient(p, snap)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			for p, s in pairs(sessions) do
				if s.loaded and s.dirty then
					task.spawn(function()
						self:save(p, false)
					end)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for p, s in pairs(sessions) do
			if s.loaded then
				pending = pending + 1
				task.spawn(function()
					self.Releasing:Fire(p, s.data)
					self:save(p, true)
					pending = pending - 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

-- test hook
function PlayerDataService:_sessions()
	return sessions
end

return PlayerDataService
