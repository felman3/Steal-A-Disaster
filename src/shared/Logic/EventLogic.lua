--[[
	EventLogic — the 5-minute refresh cycle with a 10-second Chaos Frenzy.

	Timeline for one cycle of length I (default 300 s), with t measured from
	server start:
	    [0, F)          Frenzy (begins exactly at each refresh)
	    [F, I - W)      Normal
	    [I - W, I)      Warning
	The very first cycle starts in Normal (no frenzy at t = 0).
]]

local Config = require(script.Parent.Parent.Config.GameConfig)

local EventLogic = {}

function EventLogic.phaseAt(t, cfg)
	cfg = cfg or Config.Events
	local I, W, F = cfg.Interval, cfg.Warning, cfg.FrenzyDuration
	if t < 0 then
		t = 0
	end
	local cycle = math.floor(t / I)
	local inCycle = t - cycle * I
	local toNext = I - inCycle
	if cycle >= 1 and inCycle < F then
		return { phase = "Frenzy", frenzyLeft = F - inCycle, toRefresh = toNext, cycle = cycle }
	end
	if inCycle >= I - W then
		return { phase = "Warning", frenzyLeft = 0, toRefresh = toNext, cycle = cycle }
	end
	return { phase = "Normal", frenzyLeft = 0, toRefresh = toNext, cycle = cycle }
end

-- Number of refreshes that happened in (t0, t1].
function EventLogic.refreshesBetween(t0, t1, cfg)
	cfg = cfg or Config.Events
	return math.max(0, math.floor(t1 / cfg.Interval) - math.floor(t0 / cfg.Interval))
end

return EventLogic
