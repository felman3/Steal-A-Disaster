-- Model factory checks: disasters (every id, with and without mutations) and
-- guardians (every zone guardian kind) against docs/ART_CONTRACT.md.
local env = Env.new({ mode = "server" })
local G = env.G
local Config = env.require("ReplicatedStorage.Shared.Config.GameConfig")
local DisasterModels = env.require("ReplicatedStorage.Shared.Models.DisasterModels")
local GuardianModels = env.require("ReplicatedStorage.Shared.Models.GuardianModels")

local Enum = G.Enum
local Vector3 = G.Vector3

local function sortedKeys(t)
	local out = {}
	for k in pairs(t) do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

local function parts(model)
	local out = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

-- Rotation-aware world AABB of every BasePart except `skip`. (The mock's
-- GetBoundingBox ignores part rotation, which misreads rotated cylinders.)
local function extent(p)
	local cf, s = p.CFrame, p.Size
	if p:IsA("Part") and p.Shape == Enum.PartType.Ball then
		local r = math.min(s.X, s.Y, s.Z) / 2
		return Vector3.new(r, r, r)
	end
	local rv, uv, zv = cf.RightVector, cf.UpVector, cf.LookVector
	if p:IsA("Part") and p.Shape == Enum.PartType.Cylinder then
		local hx, r = s.X / 2, math.min(s.Y, s.Z) / 2
		local function ax(a)
			return math.abs(a) * hx + r * math.sqrt(math.max(0, 1 - a * a))
		end
		return Vector3.new(ax(rv.X), ax(rv.Y), ax(rv.Z))
	end
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	return Vector3.new(
		math.abs(rv.X) * hx + math.abs(uv.X) * hy + math.abs(zv.X) * hz,
		math.abs(rv.Y) * hx + math.abs(uv.Y) * hy + math.abs(zv.Y) * hz,
		math.abs(rv.Z) * hx + math.abs(uv.Z) * hy + math.abs(zv.Z) * hz
	)
end

local function bounds(model, skip)
	local lo, hi
	for _, p in ipairs(parts(model)) do
		if p ~= skip then
			local e, pos = extent(p), p.CFrame.Position
			lo = lo and lo:Min(pos - e) or (pos - e)
			hi = hi and hi:Max(pos + e) or (pos + e)
		end
	end
	return lo, hi
end

local function checkCommon(model, maxParts)
	local root = model.PrimaryPart
	expect(root ~= nil).toBe(true)
	expect(root.Name).toBe("Root")
	expect(root.Transparency).toBe(1)
	local list = parts(model)
	expect(#list).toBeAtMost(maxParts)
	expect(#list).toBeGreaterThan(8)
	local eyes = 0
	for _, p in ipairs(list) do
		if not p.Anchored then
			error(p.Name .. " is not anchored")
		end
		if p.CanCollide then
			error(p.Name .. " can collide")
		end
		if p.CanTouch then
			error(p.Name .. " can touch")
		end
		local orbitSpeed = p:GetAttribute("Orbit")
		if orbitSpeed ~= nil and type(orbitSpeed) ~= "number" then
			error(p.Name .. " has a non-number Orbit")
		end
		if p.Name == "Eye" then
			eyes = eyes + 1
		end
	end
	expect(eyes).toBeAtLeast(2)
	-- the mock bounding box must at least be sane (it ignores rotation)
	local _, size = model:GetBoundingBox()
	expect(size.Y).toBeGreaterThan(1)
	return root
end

local disasterIds = sortedKeys(Config.Disasters)
local mutations = Config.MutationOrder

describe("DisasterModels", function()
	for idx, id in ipairs(disasterIds) do
		local def = Config.Disasters[id]
		local variants = { false, mutations[(idx - 1) % #mutations + 1] }
		for _, mut in ipairs(variants) do
			local label = id .. " (" .. def.archetype .. (mut and (", " .. mut) or "") .. ")"
			it("builds " .. label .. " within the contract", function()
				local model = DisasterModels.build(id, mut or nil)
				expect(model:IsA("Model")).toBe(true)
				local root = checkCommon(model, 45)
				expect(root.CFrame.Position.Magnitude).toBeLessThan(0.01)
				expect(model:GetAttribute("DisasterId")).toBe(id)
				expect(model:GetAttribute("Rarity")).toBe(def.rarity)
				expect(type(model:GetAttribute("AnimBob"))).toBe("number")
				expect(type(model:GetAttribute("AnimSpin"))).toBe("number")
				if mut then
					expect(model:GetAttribute("Mutation")).toBe(mut)
					expect(model:FindFirstChild("MutationAura") ~= nil).toBe(true)
				else
					expect(model:GetAttribute("Mutation")).toBeNil()
					expect(model:FindFirstChild("MutationAura")).toBeNil()
				end
				local lo, hi = bounds(model, root)
				local h = hi.Y - lo.Y
				expect(math.abs(lo.Y)).toBeAtMost(0.6)
				expect(h).toBeAtLeast(3.8)
				expect(h).toBeAtMost(mut and 10 or 9.5)
				-- footprint stays pedestal-sized
				expect(math.max(hi.X - lo.X, hi.Z - lo.Z)).toBeAtMost(13)
			end)
		end
	end

	it("grows with rarity (Common shorter than Mythic)", function()
		local _, hiC = bounds(DisasterModels.build("DustDevil"), nil)
		local _, hiM = bounds(DisasterModels.build("Supervolcano"), nil)
		expect(hiM.Y).toBeGreaterThan(hiC.Y + 2.5)
	end)

	it("Golden mutation turns the body gold", function()
		local model = DisasterModels.build("QuakeTitan", "Golden")
		local foil = 0
		for _, p in ipairs(parts(model)) do
			if p.Material == Enum.Material.Foil then
				foil = foil + 1
			end
		end
		expect(foil).toBeGreaterThan(5)
	end)

	it("animates with Orbit layers on vortex disasters", function()
		local model = DisasterModels.build("MiniTornado")
		local speeds = {}
		for _, p in ipairs(parts(model)) do
			local s = p:GetAttribute("Orbit")
			if s and p.Name == "Layer" then
				speeds[string.format("%.2f", s)] = true
			end
		end
		expect(#sortedKeys(speeds)).toBeAtLeast(3)
	end)

	it("rejects unknown ids", function()
		expect(function()
			DisasterModels.build("NotADisaster")
		end).toThrow()
	end)
end)

local kinds = {}
for _, zone in ipairs(Config.Zones) do
	table.insert(kinds, { kind = zone.guardian.kind, index = zone.index })
end

describe("GuardianModels", function()
	for _, k in ipairs(kinds) do
		it("builds the " .. k.kind .. " guardian within the contract", function()
			local model = GuardianModels.build(k.kind, k.index)
			local root = checkCommon(model, 70)
			expect(root.CFrame.Position.Magnitude).toBeLessThan(0.01)
			local look = root.CFrame.LookVector
			expect(look.Z).toBeNear(-1, 1e-6)
			expect(model:GetAttribute("GuardianKind")).toBe(k.kind)
			local head = model:FindFirstChild("Head")
			expect(head ~= nil).toBe(true)
			expect(head:IsA("BasePart")).toBe(true)
			-- facing -Z: the head is at or in front of the root
			expect(head.CFrame.Position.Z).toBeAtMost(0.5)
			local lo, hi = bounds(model, root)
			local h = hi.Y - lo.Y
			expect(math.abs(lo.Y)).toBeAtMost(0.6)
			expect(h).toBeAtLeast(10)
			expect(h).toBeAtMost(18)
			-- glowing eyes
			local glowing = 0
			for _, p in ipairs(parts(model)) do
				if p.Name == "Eye" and p.Material == Enum.Material.Neon then
					glowing = glowing + 1
				end
			end
			expect(glowing).toBeAtLeast(2)
		end)
	end

	it("rejects unknown kinds", function()
		expect(function()
			GuardianModels.build("Nope", 1)
		end).toThrow()
	end)
end)
