--[[
	WorldLayout — pure geometry for the map. Both the MapBuilder and the
	gameplay services use this so positions never drift apart.
	All positions are {x, y, z} arrays.
]]

local Config = require(script.Parent.Parent.Config.GameConfig)

local W = Config.World
local WorldLayout = {}

function WorldLayout.zoneStartZ(index)
	return W.RouteStartZ + (index - 1) * W.ZoneLength
end

function WorldLayout.zoneEndZ(index)
	return WorldLayout.zoneStartZ(index) + W.ZoneLength
end

function WorldLayout.zoneCenter(index)
	return { 0, W.GroundY, WorldLayout.zoneStartZ(index) + W.ZoneLength / 2 }
end

-- 0 = hub / bases, 1..n = zone index, -1 = out of bounds
function WorldLayout.zoneAt(x, z)
	if z < W.RouteStartZ then
		return 0
	end
	local idx = math.floor((z - W.RouteStartZ) / W.ZoneLength) + 1
	if idx > #Config.Zones then
		return -1
	end
	if math.abs(x) > W.ZoneWidth / 2 + 40 then
		return -1
	end
	return idx
end

function WorldLayout.nestCenter(index)
	return {
		0,
		W.GroundY,
		WorldLayout.zoneStartZ(index) + W.ZoneLength * Config.Spawning.NestDepth,
	}
end

function WorldLayout.nestPoints(index)
	local center = WorldLayout.nestCenter(index)
	local n = Config.Spawning.NestPointsPerZone
	local r = Config.Spawning.NestRadius
	local pts = {}
	for i = 1, n do
		local a = (i - 1) / n * math.pi * 2 + index * 0.4
		table.insert(pts, { center[1] + math.cos(a) * r, center[2], center[3] + math.sin(a) * r })
	end
	return pts
end

function WorldLayout.baseSlot(slotIndex)
	return Config.Bases.Slots[slotIndex]
end

-- Is (x, z) inside base `slotIndex`'s safe footprint?
function WorldLayout.inBase(slotIndex, x, z, margin)
	local slot = Config.Bases.Slots[slotIndex]
	if not slot then
		return false
	end
	local half = Config.Bases.Size / 2 + (margin or 0)
	return math.abs(x - slot.x) <= half and math.abs(z - slot.z) <= half
end

function WorldLayout.baseAt(x, z)
	for i = 1, #Config.Bases.Slots do
		if WorldLayout.inBase(i, x, z, 0) then
			return i
		end
	end
	return nil
end

--[[
	Base-local layout. Local space: origin at base center, +X local points from
	the back wall toward the avenue (the "front"). `face` flips X for the right
	column. Returned positions are world {x, y, z}.
]]
function WorldLayout.baseLocalToWorld(slotIndex, lx, ly, lz)
	local slot = Config.Bases.Slots[slotIndex]
	return { slot.x + lx * slot.face, ly, slot.z + lz * slot.face }
end

-- Incubator pods: row along the back wall.
function WorldLayout.podPosition(slotIndex, podIndex)
	local col = (podIndex - 1) % 4
	local row = math.floor((podIndex - 1) / 4)
	return WorldLayout.baseLocalToWorld(slotIndex, -24 + row * 10, 0, -18 + col * 12)
end

-- Display pedestals: 4x4 grid in the front half.
function WorldLayout.pedestalPosition(slotIndex, pedIndex)
	local col = (pedIndex - 1) % 4
	local row = math.floor((pedIndex - 1) / 4)
	return WorldLayout.baseLocalToWorld(slotIndex, -2 + row * 8, 0, -18 + col * 12)
end

function WorldLayout.treadmillPosition(slotIndex)
	return WorldLayout.baseLocalToWorld(slotIndex, -10, 0, 30)
end

function WorldLayout.spawnPosition(slotIndex)
	return WorldLayout.baseLocalToWorld(slotIndex, 31, 3, 22)
end

function WorldLayout.shieldButtonPosition(slotIndex)
	return WorldLayout.baseLocalToWorld(slotIndex, 31, 0, -28)
end

return WorldLayout
