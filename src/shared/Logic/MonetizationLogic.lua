--[[
	MonetizationLogic — pure rules for purchases (unit-tested headlessly).
]]

local Config = require(script.Parent.Parent.Config.GameConfig)
local MConfig = require(script.Parent.Parent.Config.MonetizationConfig)
local SpeedLogic = require(script.Parent.SpeedLogic)
local IncubatorLogic = require(script.Parent.IncubatorLogic)

local MonetizationLogic = {}

local function owns(data, key)
	return type(data) == "table" and type(data.passes) == "table" and data.passes[key] == true
end
MonetizationLogic.owns = owns

-- Treadmill Speed multiplier: additive, so it can never exceed x3.
function MonetizationLogic.speedMultiplier(data)
	local m = 1
	if owns(data, "TurboTreadmill") then
		m = m + MConfig.TurboSpeedBonus
	end
	if type(data) == "table" and (data.boostSpeed or 0) > 0 then
		m = m + MConfig.BoostSpeedBonus
	end
	return m
end

function MonetizationLogic.incomeMultiplier(data)
	if owns(data, "DoubleCash") then
		return MConfig.DoubleCashMult
	end
	return 1
end

-- Cash Pack: ~10 minutes of BASE income (Double Cash is not applied), with a
-- floor from the highest unlocked zone so it is useful at every stage.
function MonetizationLogic.cashPackAmount(baseIncome, speed)
	local item = MConfig.Items.CashPack
	local zone = Config.Zones[SpeedLogic.highestUnlockedZone(speed or 0)] or Config.Zones[1]
	local floorAmount = zone.baseIncome * item.incomeSeconds * item.minimumZoneIncomes
	local fromIncome = math.max(0, tonumber(baseIncome) or 0) * item.incomeSeconds
	return math.floor(math.max(fromIncome, floorAmount))
end

-- Pick the pod Instant Hatch finishes: the requested one if it is still
-- incubating, otherwise the incubating pod with the most time left.
-- `inTransit(slot)` excludes pods that are being stolen.
function MonetizationLogic.pickHatchPod(pods, preferredSlot, inTransit)
	local best, bestLeft
	for _, pod in ipairs(pods or {}) do
		local busy = inTransit and inTransit(pod.s)
		if not busy and IncubatorLogic.fraction(pod) < 1 then
			if pod.s == preferredSlot then
				return pod
			end
			local left = IncubatorLogic.remaining(pod)
			if not bestLeft or left > bestLeft then
				best, bestLeft = pod, left
			end
		end
	end
	return best
end

function MonetizationLogic.hasReceipt(list, purchaseId)
	for _, id in ipairs(list or {}) do
		if id == purchaseId then
			return true
		end
	end
	return false
end

function MonetizationLogic.addReceipt(list, purchaseId)
	table.insert(list, purchaseId)
	while #list > MConfig.ReceiptHistorySize do
		table.remove(list, 1)
	end
end

-- Lookup tables from Roblox id -> item key (only configured items).
function MonetizationLogic.keysById(itemType)
	local out = {}
	for key, item in pairs(MConfig.Items) do
		if item.type == itemType and type(item.id) == "number" and item.id > 0 then
			out[item.id] = key
		end
	end
	return out
end

return MonetizationLogic
