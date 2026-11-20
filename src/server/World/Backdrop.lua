--[[
	Backdrop — scenery beyond the playable strip, so the world no longer floats
	in empty sky. Built once by MapBuilder into World.Backdrop (separate from the
	zone folders, which keep their own contract).

	* Ground skirts continue each zone's ground out to the horizon (and around
	  the hub), slightly below the playable ground.
	* Each zone gets themed silhouettes 200-480 studs out on both sides:
	  hills + town, giant trees, mesas, snow peaks, volcanoes, trench cliffs,
	  a prehistoric volcano, a cloud sea with floating islands, void shards.

	Everything is decorative: no collision, no touch, no queries, no shadows,
	and nothing inside |x| <= 80 (the route walls are at |x| = 76).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local WorldLayout = require(Shared.Logic.WorldLayout)
local Kit = require(Shared.Models.Kit)

local Backdrop = {}

local NEAR, FAR = 220, 480 -- silhouette distance band from the route centre
local SKIRT_OUT = 640 -- ground skirt reaches this far from the centre

local function deco(parent, o)
	o.collide = false
	o.castShadow = false
	o.query = false
	return Kit.part(parent, o)
end

local function ball(parent, pos, d, color, material)
	return deco(parent, { name = "Hill", shape = "Ball", size = Vector3.new(d, d, d), cf = CFrame.new(pos), color = color, material = material or Enum.Material.Grass })
end

-- square pyramid from four wedges (same construction as the Frostfall peaks)
local function peak(parent, pos, w, h, color, material, yaw)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
	for i = 0, 3 do
		deco(parent, {
			name = "Peak",
			shape = "Wedge",
			size = Vector3.new(w, h, w / 2),
			cf = base * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, h / 2, -w / 4),
			color = color,
			material = material,
		})
	end
end

local function block(parent, pos, size, color, material, yaw)
	return deco(parent, { name = "Block", size = size, cf = CFrame.new(pos + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, yaw or 0, 0), color = color, material = material })
end

local function column(parent, pos, h, d, color, material)
	return deco(parent, { name = "Column", shape = "Cylinder", size = Vector3.new(h, d, d), cf = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color = color, material = material })
end

-- Per-zone themes. `ground` = skirt colour/material (nil = no ground: Skylands),
-- `feature(parent, pos, side, rng)` places one landmark cluster at `pos`.
local THEMES = {
	Suburb = {
		ground = { { 104, 172, 84 }, Enum.Material.Grass },
		feature = function(p, pos, side, rng)
			ball(p, pos + Vector3.new(0, -30, 0), rng(90, 140), { 92, 160, 76 })
			for i = 0, 2 do
				local h = rng(30, 70)
				block(p, pos + Vector3.new(side * (40 + i * 22), 0, rng(-30, 30)), Vector3.new(18, h, 18), Kit.mix({ 230, 220, 205 }, { 150, 170, 200 }, rng()), Enum.Material.SmoothPlastic)
			end
		end,
	},
	Overgrowth = {
		ground = { { 58, 120, 54 }, Enum.Material.Grass },
		feature = function(p, pos, side, rng)
			local h = rng(90, 150)
			column(p, pos, h, rng(14, 20), { 90, 64, 44 }, Enum.Material.Wood)
			for _ = 1, 3 do
				-- canopy balls (radius >= 25) stay within 18 studs of the trunk top so none float free
				ball(p, pos + Vector3.new(rng(-18, 18), h + rng(-6, 12), rng(-18, 18)), rng(50, 80), { 46, 110, 52 }, Enum.Material.Grass)
			end
		end,
	},
	Droughtlands = {
		ground = { { 214, 162, 110 }, Enum.Material.Sandstone },
		feature = function(p, pos, side, rng)
			local w, d = rng(60, 110), rng(50, 90)
			local h = rng(40, 80)
			block(p, pos, Vector3.new(w, h, d), { 190, 120, 80 }, Enum.Material.Sandstone, rng(0, 1))
			block(p, pos + Vector3.new(0, h, 0), Vector3.new(w * 0.86, 8, d * 0.86), { 222, 160, 108 }, Enum.Material.Sandstone)
		end,
	},
	Frostfall = {
		ground = { { 232, 240, 250 }, Enum.Material.Snow },
		feature = function(p, pos, side, rng)
			local w, h = rng(120, 180), rng(110, 170)
			peak(p, pos, w, h, { 120, 130, 150 }, Enum.Material.Rock, rng(0, 1))
			peak(p, pos + Vector3.new(0, h * 0.55, 0), w * 0.45, h * 0.45, { 245, 250, 255 }, Enum.Material.Snow, rng(0, 1))
		end,
	},
	MagmaBasin = {
		ground = { { 54, 46, 46 }, Enum.Material.Basalt },
		feature = function(p, pos, side, rng)
			local w, h = rng(120, 170), rng(80, 120)
			peak(p, pos, w, h, { 46, 38, 40 }, Enum.Material.Basalt, rng(0, 1))
			deco(p, { name = "Lava", shape = "Ball", size = Vector3.new(w * 0.22, w * 0.22, w * 0.22), cf = CFrame.new(pos + Vector3.new(0, h * 0.92, 0)), color = { 255, 120, 30 }, material = Enum.Material.Neon })
			deco(p, { name = "LavaPool", size = Vector3.new(w * 0.7, 0.4, w * 0.4), cf = CFrame.new(pos + Vector3.new(side * w * 0.6, 0.3, 0)), color = { 255, 90, 20 }, material = Enum.Material.Neon })
		end,
	},
	DeepAbyss = {
		ground = { { 34, 52, 82 }, Enum.Material.Sand },
		feature = function(p, pos, side, rng)
			block(p, pos, Vector3.new(rng(50, 80), rng(110, 170), rng(70, 120)), { 22, 34, 58 }, Enum.Material.Slate)
			for _ = 1, 2 do
				column(p, pos + Vector3.new(-side * rng(40, 70), 0, rng(-40, 40)), rng(30, 60), rng(4, 7), { 60, 230, 255 }, Enum.Material.Neon)
			end
		end,
	},
	Prehistoric = {
		ground = { { 84, 112, 54 }, Enum.Material.Grass },
		feature = function(p, pos, side, rng)
			if rng() < 0.4 then
				peak(p, pos, 150, 120, { 70, 56, 46 }, Enum.Material.Rock, rng(0, 1))
				deco(p, { name = "Smoke", shape = "Ball", size = Vector3.new(40, 40, 40), cf = CFrame.new(pos + Vector3.new(0, 130, 0)), color = { 120, 110, 105 }, material = Enum.Material.SmoothPlastic, transparency = 0.35 })
			else
				ball(p, pos + Vector3.new(0, -25, 0), rng(80, 120), { 70, 120, 50 })
				for _ = 1, 3 do
					local h = rng(30, 50)
					column(p, pos + Vector3.new(rng(-35, 35), 10, rng(-35, 35)), h, 3, { 110, 84, 56 }, Enum.Material.Wood)
				end
			end
		end,
	},
	Skylands = {
		ground = nil, -- open sky: a cloud sea below instead
		clouds = true,
		feature = function(p, pos, side, rng)
			local y = rng(10, 70)
			local w = rng(40, 70)
			deco(p, { name = "Island", shape = "Ball", size = Vector3.new(w, w, w), cf = CFrame.new(pos + Vector3.new(0, y - w * 0.35, 0)), color = { 120, 100, 80 }, material = Enum.Material.Rock })
			deco(p, { name = "IslandTop", shape = "Cylinder", size = Vector3.new(4, w * 1.05, w * 1.05), cf = CFrame.new(pos + Vector3.new(0, y + w * 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2), color = { 120, 200, 110 }, material = Enum.Material.Grass })
		end,
	},
	VoidRealm = {
		ground = { { 24, 14, 40 }, Enum.Material.Glass },
		feature = function(p, pos, side, rng)
			for _ = 1, 3 do
				local h = rng(60, 140)
				deco(p, { name = "Shard", size = Vector3.new(rng(8, 16), h, rng(8, 16)), cf = CFrame.new(pos + Vector3.new(rng(-40, 40), h / 2 - 5, rng(-40, 40))) * CFrame.Angles(rng(-0.3, 0.3), rng(0, 3), rng(-0.3, 0.3)), color = Kit.mix({ 150, 60, 255 }, { 40, 200, 255 }, rng()), material = Enum.Material.Neon, transparency = 0.15 })
			end
		end,
	},
}

local function skirts(parent, z0, z1, color, material)
	local len = z1 - z0
	for side = -1, 1, 2 do
		deco(parent, { name = "Skirt", size = Vector3.new(SKIRT_OUT - 76, 2, len), cf = CFrame.new(side * (76 + (SKIRT_OUT - 76) / 2), -1.3, (z0 + z1) / 2), color = Kit.shade(color, 0.92), material = material })
	end
end

function Backdrop.build(root, rng)
	local m = Kit.model(root, "Backdrop")
	-- hub surroundings: grass all round, low hills behind the bases
	local hub = Config.World
	local hz0 = hub.HubCenter[3] - hub.HubSize[2] / 2
	local hz1 = hub.HubCenter[3] + hub.HubSize[2] / 2
	for side = -1, 1, 2 do
		deco(m, { name = "HubSkirt", size = Vector3.new(SKIRT_OUT - 160, 2, hz1 - hz0 + 400), cf = CFrame.new(side * (160 + (SKIRT_OUT - 160) / 2), -1.3, (hz0 + hz1) / 2 - 200), color = { 98, 166, 80 }, material = Enum.Material.Grass })
		for i = 0, 4 do
			ball(m, Vector3.new(side * rng(260, 420), -40, hz0 - 120 + i * 120 + rng(-30, 30)), rng(110, 170), { 90, 158, 74 })
		end
	end
	deco(m, { name = "HubBack", size = Vector3.new(SKIRT_OUT * 2, 2, 400), cf = CFrame.new(0, -1.3, hz0 - 200), color = { 98, 166, 80 }, material = Enum.Material.Grass })

	for i, zone in ipairs(Config.Zones) do
		local theme = THEMES[zone.id]
		if theme then
			local z0 = WorldLayout.zoneStartZ(i)
			local z1 = z0 + Config.World.ZoneLength
			local zm = Kit.model(m, zone.id)
			if theme.ground then
				-- zone 1 skirt starts at the hub edge so there is no gap at the route link
				skirts(zm, (i == 1) and hz1 or z0, z1, theme.ground[1], theme.ground[2])
			end
			if theme.clouds then
				for side = -1, 1, 2 do
					for k = 0, 2 do
						deco(zm, { name = "CloudSea", shape = "Ball", size = Vector3.new(160, 160, 160), cf = CFrame.new(side * (170 + k * 140), -95, z0 + 60 + k * 70), color = { 250, 252, 255 }, material = Enum.Material.SmoothPlastic, transparency = 0.1 })
					end
				end
			end
			for side = -1, 1, 2 do
				for k = 0, 1 do
					local x = side * rng(NEAR, FAR)
					local z = z0 + (k + 0.5) * (z1 - z0) / 2 + rng(-40, 40)
					theme.feature(zm, Vector3.new(x, 0, z), side, rng)
				end
			end
		end
	end
	-- beyond the end wall: more void ground so the route doesn't end at the sky
	local last = Config.Zones[#Config.Zones]
	local endZ = WorldLayout.zoneStartZ(#Config.Zones) + Config.World.ZoneLength
	if THEMES[last.id] and THEMES[last.id].ground then
		deco(m, { name = "EndSkirt", size = Vector3.new(SKIRT_OUT * 2, 2, 500), cf = CFrame.new(0, -1.3, endZ + 250), color = Kit.shade(THEMES[last.id].ground[1], 0.92), material = THEMES[last.id].ground[2] })
		for k = -2, 2 do
			THEMES[last.id].feature(m, Vector3.new(k * 110, 0, endZ + 220 + math.abs(k) * 30), (k < 0) and -1 or 1, rng)
		end
	end
	return m
end

return Backdrop
