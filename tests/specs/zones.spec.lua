-- Validates every zone builder against docs/ZONE_CONTRACT.md.
local env = Env.new({ mode = "server" })
local D = env.D
local Config = env.require("ReplicatedStorage.Shared.Config.GameConfig")
local MapBuilder = env.require("ServerScriptService.Server.World.MapBuilder")

local refs
env.run(function()
	refs = MapBuilder.build()
end)
env.advance(0.1)

-- rotation-aware world AABB of a part
local function aabb(p)
	local cf, s = p.CFrame, p.Size / 2
	local minV, maxV
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local c = cf * D.Vector3.new(s.X * sx, s.Y * sy, s.Z * sz)
				minV = minV and minV:Min(c) or c
				maxV = maxV and maxV:Max(c) or c
			end
		end
	end
	return minV, maxV
end

local function zoneParts(i)
	local folder = refs.zones[i].folder
	local out = {}
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out, folder
end

local function isBuilderPart(p, folder)
	-- exclude MapBuilder-owned gate & nest
	local gate = folder:FindFirstChild("Gate")
	local nest = folder:FindFirstChild("Nest")
	return not ((gate and p:IsDescendantOf(gate)) or (nest and p:IsDescendantOf(nest)))
end

describe("zone builders", function()
	it("built every zone without errors or fallback", function()
		expect(#env.errors).toBe(0)
		local fails = {}
		for _, w in ipairs(env.warnings) do
			if string.find(w, "zone builder", 1, true) then
				table.insert(fails, w)
			end
		end
		if #fails > 0 then
			error(table.concat(fails, "\n"))
		end
	end)

	for i, zone in ipairs(Config.Zones) do
		it(zone.name .. " follows the contract", function()
			local parts, folder = zoneParts(i)
			local z0 = 200 + (i - 1) * 260
			local z1 = z0 + 260
			local nest = refs.zones[i].nestCenter
			local nestR = Config.Spawning.NestRadius + 14
			local count = 0
			local problems = {}
			local function problem(msg)
				if #problems < 8 then
					table.insert(problems, msg)
				end
			end
			-- sample ground coverage on a grid
			local ground = {}
			for _, p in ipairs(parts) do
				if isBuilderPart(p, folder) then
					count = count + 1
					local lo, hi = aabb(p)
					local c = p.Position
					if math.abs(c.X) > 80 or c.Z < z0 - 2 or c.Z > z1 + 2 or c.Y > 120 then
						problem("out of bounds: " .. p:GetFullName() .. " at " .. tostring(c))
					end
					if p.CanCollide then
						if math.abs(hi.Y) <= 0.7 and hi.Y - lo.Y >= 0.2 then
							table.insert(ground, { lo = lo, hi = hi })
						end
						-- corridor
						if hi.Y > 0.8 and lo.Y < 12 and lo.X < 13 and hi.X > -13 and hi.Z > z0 and lo.Z < nest.Z then
							problem("blocks corridor: " .. p:GetFullName() .. " " .. tostring(lo) .. " .. " .. tostring(hi))
						end
						-- exit path: nest -> next zone's gate must stay open too
						if i < #Config.Zones and hi.Y > 0.8 and lo.Y < 12 and lo.X < 13 and hi.X > -13 and hi.Z > nest.Z + nestR and lo.Z < z1 + 2 then
							problem("blocks exit path: " .. p:GetFullName() .. " " .. tostring(lo) .. " .. " .. tostring(hi))
						end
						-- nest
						if hi.Y > 0.8 then
							local cx = math.max(lo.X, math.min(nest.X, hi.X))
							local cz = math.max(lo.Z, math.min(nest.Z, hi.Z))
							if (D.Vector3.new(cx, 0, cz) - D.Vector3.new(nest.X, 0, nest.Z)).Magnitude < nestR then
								problem("blocks nest: " .. p:GetFullName())
							end
						end
					end
				end
			end
			expect(count).toBeAtMost(650)
			expect(count).toBeAtLeast(40)
			-- ground coverage: corridor + nest must be solid; whole zone for non-sky zones
			local holes = 0
			local corridorHoles = 0
			for gx = -70, 70, 10 do
				for gz = z0 + 5, z1 - 5, 10 do
					local covered = false
					for _, g in ipairs(ground) do
						if gx >= g.lo.X and gx <= g.hi.X and gz >= g.lo.Z and gz <= g.hi.Z then
							covered = true
							break
						end
					end
					local inCorridor = math.abs(gx) <= 10 and gz < nest.Z
					local inNest = (D.Vector3.new(gx, 0, gz) - D.Vector3.new(nest.X, 0, nest.Z)).Magnitude < nestR
					if not covered then
						holes = holes + 1
						if inCorridor or inNest then
							corridorHoles = corridorHoles + 1
						end
					end
				end
			end
			if corridorHoles > 0 then
				problem(corridorHoles .. " ground holes in corridor/nest")
			end
			if zone.id ~= "Skylands" and holes > 0 then
				problem(holes .. " ground holes")
			end
			if #problems > 0 then
				error(table.concat(problems, "\n"))
			end
			expect(refs.zones[i].palette ~= nil).toBe(true)
		end)
	end

	-- Found in Studio: exit landmarks (skull arch, ice cathedral, volcano tube) hid the next
	-- zone's gate sign until the player was right under it.
	-- Segment vs oriented box (slab test in the part's local space); exact for Ball parts.
	local function segmentHitsPart(a, b, p)
		if p:IsA("Part") and p.Shape == env.G.Enum.PartType.Ball then
			local ab = b - a
			local t = math.max(0, math.min(1, (p.Position - a):Dot(ab) / ab:Dot(ab)))
			return ((a + ab * t) - p.Position).Magnitude < p.Size.X / 2
		end
		local la = p.CFrame:PointToObjectSpace(a)
		local lb = p.CFrame:PointToObjectSpace(b)
		local half = p.Size / 2
		local t0, t1 = 0, 1
		for _, axis in ipairs({ "X", "Y", "Z" }) do
			local s, d, h = la[axis], lb[axis] - la[axis], half[axis]
			if math.abs(d) < 1e-9 then
				if s < -h or s > h then
					return false
				end
			else
				local ta, tb = (-h - s) / d, (h - s) / d
				if ta > tb then
					ta, tb = tb, ta
				end
				t0 = math.max(t0, ta)
				t1 = math.min(t1, tb)
				if t0 > t1 then
					return false
				end
			end
		end
		return true
	end

	for i = 2, #Config.Zones do
		it(Config.Zones[i].name .. " gate sign is readable from the previous zone", function()
			local gateZ = 200 + (i - 1) * 260
			local blockers = {}
			local parts = zoneParts(i - 1)
			-- the middle of the zone name and the speed line, seen from eye height 100 and 60 studs out
			-- (a landmark nicking the top edge of the letters is fine; hiding the line is not)
			for _, dist in ipairs({ 100, 60 }) do
				local eye = D.Vector3.new(0, 7, gateZ - dist)
				for _, y in ipairs({ 26.5, 24.2 }) do
					local sign = D.Vector3.new(0, y, gateZ - 1.2)
					for _, p in ipairs(parts) do
						if p.Transparency < 0.6 and segmentHitsPart(eye, sign, p) then
							blockers[p:GetFullName()] = true
						end
					end
				end
			end
			local names = {}
			for n in pairs(blockers) do
				table.insert(names, n)
			end
			if #names > 0 then
				error("gate sign hidden by: " .. table.concat(names, ", "))
			end
		end)
	end
end)
