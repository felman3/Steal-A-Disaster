--[[
	SpeedLogic — Speed stat math, treadmill step accounting, zone gating.
]]

local Config = require(script.Parent.Parent.Config.GameConfig)

local S = Config.Speed
local SpeedLogic = {}

function SpeedLogic.walkSpeedFor(speed)
	speed = math.max(0, speed or 0)
	local w = S.BaseWalkSpeed + S.WalkPerDoubling * math.log(1 + speed / S.WalkScale, 2)
	return math.min(w, S.MaxWalkSpeed)
end

function SpeedLogic.gainPerStep(treadmillLevel)
	local level = math.max(1, math.floor(treadmillLevel or 1))
	return math.floor(S.BaseGainPerStep * S.GainGrowth ^ (level - 1) + 0.5)
end

function SpeedLogic.canStealInZone(speed, zoneIndex)
	local zone = Config.Zones[zoneIndex]
	if not zone then
		return false
	end
	return (speed or 0) >= zone.speedReq
end

-- Highest zone index the player may steal in (always >= 1).
function SpeedLogic.highestUnlockedZone(speed)
	local best = 1
	for i, zone in ipairs(Config.Zones) do
		if (speed or 0) >= zone.speedReq then
			best = i
		end
	end
	return best
end

-- Next zone the player has NOT unlocked, or nil when all are unlocked.
function SpeedLogic.nextZone(speed)
	for _, zone in ipairs(Config.Zones) do
		if (speed or 0) < zone.speedReq then
			return zone
		end
	end
	return nil
end

--[[
	Step accumulator. The server calls tick() every Heartbeat for each player
	who is physically on their own treadmill belt and moving. It converts
	elapsed running time into whole steps at a capped rate, so frame rate or
	client spam can never produce extra steps.
]]
function SpeedLogic.newStepState()
	return { carry = 0 }
end

function SpeedLogic.tickSteps(state, dt, running)
	if not running or dt <= 0 then
		-- lose partial progress when stopping so tapping can't farm fractions
		state.carry = 0
		return 0
	end
	dt = math.min(dt, 0.5) -- ignore huge server hitches
	state.carry = state.carry + dt * S.StepsPerSecond
	local steps = math.floor(state.carry + 1e-6)
	state.carry = math.max(0, state.carry - steps)
	return steps
end

return SpeedLogic
