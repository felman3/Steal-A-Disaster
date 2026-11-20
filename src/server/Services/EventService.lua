--[[
	EventService — the 5-minute world refresh and the 10-second Chaos Frenzy.

	Timeline (EventLogic): Normal → Warning (last 30 s) → refresh + Frenzy (10 s).
	On refresh, only *temporary world opportunities* (uncarried nest cores) are
	rerolled. Player money, cores, pods and disasters are never touched.

	Replicated state lives in ReplicatedStorage attributes so clients can show
	countdowns without extra traffic:
	  EventPhase      "Normal" | "Warning" | "Frenzy"
	  NextRefreshAt   server time (workspace:GetServerTimeNow()) of the next refresh
	  FrenzyEndsAt    server time when the current frenzy ends (0 otherwise)
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local EventLogic = require(Shared.Logic.EventLogic)
local Signal = require(Shared.Signal)
local Remotes = require(Shared.Remotes)

local EventService = { Name = "EventService" }
EventService.PhaseChanged = Signal.new() -- (newPhase, oldPhase, info)
EventService.Refreshed = Signal.new() -- (cycle)

local S
local startClock
local phase = "Normal"
local lastCycle = 0
local forcedOffset = 0

function EventService:Init(registry)
	S = registry
	startClock = os.clock()
end

function EventService:elapsed()
	return os.clock() - startClock + forcedOffset
end

function EventService:phase()
	return phase
end

function EventService:isFrenzy()
	return phase == "Frenzy"
end

function EventService:incubationRate()
	return phase == "Frenzy" and Config.Events.FrenzyIncubationMult or 1
end

function EventService:mutationMult()
	return phase == "Frenzy" and Config.Events.FrenzyMutationMult or 1
end

-- Debug/test helper: jump the cycle clock forward by `seconds`.
function EventService:skip(seconds)
	forcedOffset = forcedOffset + seconds
end

local function announceAll(payload)
	Remotes.get("Announce"):FireAllClients(payload)
end

function EventService:_publish(info)
	local now = workspace:GetServerTimeNow()
	ReplicatedStorage:SetAttribute("EventPhase", info.phase)
	ReplicatedStorage:SetAttribute("NextRefreshAt", now + info.toRefresh)
	ReplicatedStorage:SetAttribute("FrenzyEndsAt", info.phase == "Frenzy" and (now + info.frenzyLeft) or 0)
end

function EventService:_tick()
	local info = EventLogic.phaseAt(self:elapsed())
	if info.cycle > lastCycle then
		-- refresh exactly once per cycle boundary, even if several were skipped
		lastCycle = info.cycle
		self.Refreshed:Fire(info.cycle)
	end
	if info.phase ~= phase then
		local old = phase
		phase = info.phase
		self:_publish(info)
		if phase == "Warning" then
			announceAll({
				kind = "warning",
				title = "CHAOS FRENZY INCOMING",
				subtitle = "Cores refresh in " .. Config.Events.Warning .. "s — get in position!",
				color = { 255, 90, 220 },
			})
		elseif phase == "Frenzy" then
			announceAll({
				kind = "frenzy",
				title = "⚡ CHAOS FRENZY! ⚡",
				subtitle = "Rare cores everywhere • Chaos Cores spawned • Incubation x" .. Config.Events.FrenzyIncubationMult,
				color = { 255, 60, 230 },
			})
		elseif old == "Frenzy" then
			announceAll({ kind = "info", title = "FRENZY OVER", subtitle = "Next frenzy in 5:00", color = { 200, 200, 255 } })
		end
		self.PhaseChanged:Fire(phase, old, info)
	end
	return info
end

function EventService:Start()
	self:_publish(EventLogic.phaseAt(0))
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 0.1 then
			return
		end
		acc = 0
		self:_tick()
	end)
	-- re-publish periodically so late joiners & drift stay correct
	task.spawn(function()
		while true do
			task.wait(5)
			self:_publish(EventLogic.phaseAt(self:elapsed()))
		end
	end)
end

return EventService
