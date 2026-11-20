--[[
	TravelLogic — pure rules for Quick Travel (HOME / STEAL / TRAIN / ZONES).

	Travel never skips progression: a zone is a valid destination only when the
	player's Speed lets them steal there, and nobody may travel while carrying a
	core (that would skip the run home).
]]

local Config = require(script.Parent.Parent.Config.GameConfig)
local SpeedLogic = require(script.Parent.SpeedLogic)
local WorldLayout = require(script.Parent.WorldLayout)
local Util = require(script.Parent.Parent.Util)

local TravelLogic = {}

TravelLogic.COOLDOWN = 4 -- seconds between trips (server-enforced)
TravelLogic.ENTRANCE_DEPTH = 14 -- studs inside a zone gate
TravelLogic.SPOT_OFFSETS = { 0, 5, -5, 9, -9 } -- sideways tries to avoid other players
TravelLogic.CLEAR_RADIUS = 4 -- min distance to another player's root

TravelLogic.Destinations = { Home = true, Steal = true, Train = true, Zone = true }

-- Highest zone the player may steal in (always at least 1).
function TravelLogic.stealZone(speed)
	return SpeedLogic.highestUnlockedZone(speed or 0)
end

function TravelLogic.zoneUnlocked(speed, index)
	index = tonumber(index)
	if not index or index ~= math.floor(index) or not Config.Zones[index] then
		return false
	end
	return SpeedLogic.canStealInZone(speed or 0, index)
end

-- Just inside a zone gate, on the clear central corridor. Returns {x, y, z}.
function TravelLogic.zoneEntrance(index)
	return { 0, 4, WorldLayout.zoneStartZ(index) + TravelLogic.ENTRANCE_DEPTH }
end

-- Validate a request. Returns ok, reason (reason is player-facing on failure).
-- `now` and `readyAt` are seconds; `carrying` is the number of carried cores.
function TravelLogic.check(dest, arg, speed, carrying, now, readyAt)
	if type(dest) ~= "string" or not TravelLogic.Destinations[dest] then
		return false, "Unknown destination."
	end
	if (carrying or 0) > 0 then
		return false, "You can't fast-travel while carrying a core — run it home!"
	end
	if readyAt and now < readyAt then
		return false, "Travel ready in " .. math.ceil(readyAt - now) .. "s."
	end
	if dest == "Zone" and not TravelLogic.zoneUnlocked(speed, arg) then
		local zone = Config.Zones[tonumber(arg) or 0]
		if zone then
			return false, zone.name .. " is locked — reach ⚡" .. Util.formatNumber(zone.speedReq) .. " Speed first."
		end
		return false, "Unknown zone."
	end
	return true, nil
end

-- Pick the first spot (base point shifted sideways by SPOT_OFFSETS) that is at
-- least CLEAR_RADIUS from every position in `others` ({x, z} pairs).
-- `side` is the unit sideways direction {x, z}. Returns the offset used.
function TravelLogic.clearOffset(base, side, others)
	for _, off in ipairs(TravelLogic.SPOT_OFFSETS) do
		local x = base[1] + side[1] * off
		local z = base[3] + side[2] * off
		local free = true
		for _, o in ipairs(others or {}) do
			if (o[1] - x) ^ 2 + (o[2] - z) ^ 2 < TravelLogic.CLEAR_RADIUS ^ 2 then
				free = false
				break
			end
		end
		if free then
			return off
		end
	end
	return TravelLogic.SPOT_OFFSETS[1]
end

return TravelLogic
