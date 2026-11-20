--[[
	IncubatorLogic — incubation timers and progress.

	A pod entry is { s = slot, c = coreId, m = mutation|nil, z = zoneIndex, p = progressSeconds }.
]]

local Config = require(script.Parent.Parent.Config.GameConfig)

local IncubatorLogic = {}

local ZONE_TIME_BONUS = 0.08 -- +8% incubation time per zone index

function IncubatorLogic.incubationTime(coreId, zoneIndex)
	local c = Config.Cores[coreId]
	if not c then
		return 15
	end
	local base = Config.Rarities[c.rarity].incubate
	local zi = Config.ZoneIndex[c.zone] or tonumber(zoneIndex) or 1
	return math.floor(base * (1 + ZONE_TIME_BONUS * (zi - 1)) + 0.5)
end

-- Advance a pod by dt seconds at `rate` (1 normally, Frenzy mult during frenzy).
-- Returns true when the pod has finished.
function IncubatorLogic.advance(pod, dt, rate)
	local total = IncubatorLogic.incubationTime(pod.c, pod.z)
	pod.p = math.min(total, (pod.p or 0) + math.max(0, dt) * (rate or 1))
	return pod.p >= total
end

function IncubatorLogic.fraction(pod)
	local total = IncubatorLogic.incubationTime(pod.c, pod.z)
	if total <= 0 then
		return 1
	end
	return math.min(1, (pod.p or 0) / total)
end

function IncubatorLogic.remaining(pod)
	return math.max(0, IncubatorLogic.incubationTime(pod.c, pod.z) - (pod.p or 0))
end

-- Mutation roll at hatch for cores that have none yet.
function IncubatorLogic.hatchMutation(existing, rng, mutationMult)
	if existing then
		return existing
	end
	local SpawnLogic = require(script.Parent.SpawnLogic)
	return SpawnLogic.rollMutation(rng, mutationMult)
end

return IncubatorLogic
