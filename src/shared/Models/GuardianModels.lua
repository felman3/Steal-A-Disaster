--[[
	GuardianModels — builds the big zone guardians that patrol each core nest.

	One builder per `GameConfig.Zones[i].guardian.kind`: Hound (topiary hedge
	dog), Stalker (vine creature), Scorpion, Yeti, Wyrm (magma serpent-dragon),
	Angler (deep-sea anglerfish), Rex (T-rex), Roc (storm bird), Warden (void
	knight). Chunky silhouettes, glowing eyes.

	Model contract:
	  * returns a Model whose PrimaryPart "Root" (invisible) sits at the ground
	    center (origin); the bottom of the feet is at y = 0
	  * the guardian faces -Z (Root.CFrame.LookVector is forward)
	  * contains a part named "Head"; attributes GuardianKind (and ZoneIndex)
	  * all parts anchored, non-colliding, CanTouch false
	  * 10-18 studs tall
]]

local Kit = require(script.Parent.Kit)

local GuardianModels = {}

local M = Enum.Material
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local PI = math.pi

local INK = { 22, 20, 30 }
local WHITE = { 250, 250, 245 }

-- Target height (studs) per guardian kind.
GuardianModels.Heights = {
	Hound = 11,
	Stalker = 13,
	Scorpion = 10.5,
	Yeti = 14,
	Wyrm = 15,
	Angler = 12.5,
	Rex = 15,
	Roc = 16,
	Warden = 17,
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function toCF(at)
	if typeof(at) == "Vector3" then
		return CF(at)
	end
	return at or CF()
end

local function part(m, name, size, at, color, mat, tr, shape)
	return Kit.part(m, {
		name = name,
		size = size,
		cf = toCF(at),
		color = color,
		material = mat or M.SmoothPlastic,
		transparency = tr,
		shape = shape,
		collide = false,
	})
end

local function ball(m, name, d, at, color, mat, tr)
	return Kit.ball(m, { name = name, diameter = d, cf = toCF(at), color = color, material = mat or M.SmoothPlastic, transparency = tr, collide = false })
end

-- Block spanning a -> b. Cross-section w (local X) by wz (local Y).
local function seg(m, name, a, b, w, color, mat, tr, wz)
	local len = math.max((b - a).Magnitude, 0.05)
	return part(m, name, V(w, wz or w, len), CFrame.lookAt((a + b) / 2, b), color, mat, tr)
end

-- Round limb spanning a -> b.
local function rod(m, name, a, b, d, color, mat, tr)
	local len = math.max((b - a).Magnitude, 0.05)
	return part(m, name, V(len, d, d), CFrame.lookAt((a + b) / 2, b) * ANG(0, PI / 2, 0), color, mat, tr, "Cylinder")
end

-- Diamond (45 degree) tooth: reads as a fang from the front.
local function tooth(m, at, s, color)
	return part(m, "Tooth", V(s, s, s * 0.7), toCF(at) * ANG(0, 0, PI / 4), color or WHITE)
end

-- Glowing eyes with angry brows. `pos` is the point between the eyes.
local function eyes(m, pos, gap, d, glow, browAngle, browColor)
	for s = -1, 1, 2 do
		local e = ball(m, "Eye", d, pos + V(s * gap, 0, 0), glow, M.Neon)
		if s == 1 then
			Kit.light(e, glow, d * 10, 1.4)
		end
		if browAngle then
			part(m, "Brow", V(d * 1.4, d * 0.32, d * 0.5), CF(pos + V(s * gap - s * d * 0.08, d * 0.75, -d * 0.1)) * ANG(0, 0, s * browAngle), browColor or INK)
		end
	end
end

local function orbit(p, speed)
	p:SetAttribute("Orbit", speed)
	return p
end

local function partExtent(p)
	local cf, s = p.CFrame, p.Size
	if p:IsA("Part") and p.Shape == Enum.PartType.Ball then
		local r = math.min(s.X, s.Y, s.Z) / 2
		return V(r, r, r)
	end
	local rv, uv, zv = cf.RightVector, cf.UpVector, cf.LookVector
	if p:IsA("Part") and p.Shape == Enum.PartType.Cylinder then
		local hx, r = s.X / 2, math.min(s.Y, s.Z) / 2
		local function ax(a)
			return math.abs(a) * hx + r * math.sqrt(math.max(0, 1 - a * a))
		end
		return V(ax(rv.X), ax(rv.Y), ax(rv.Z))
	end
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	return V(
		math.abs(rv.X) * hx + math.abs(uv.X) * hy + math.abs(zv.X) * hz,
		math.abs(rv.Y) * hx + math.abs(uv.Y) * hy + math.abs(zv.Y) * hz,
		math.abs(rv.Z) * hx + math.abs(uv.Z) * hy + math.abs(zv.Z) * hz
	)
end

local function bounds(m, skip)
	local lo, hi
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d ~= skip then
			local e = partExtent(d)
			local pos = d.CFrame.Position
			local a, b = pos - e, pos + e
			lo = lo and lo:Min(a) or a
			hi = hi and hi:Max(b) or b
		end
	end
	return lo or Vector3.zero, hi or Vector3.zero
end
GuardianModels.bounds = bounds

-- Scale the design about the vertical axis to `targetH`, feet at y = 0.
local function normalize(m, root, targetH)
	local lo, hi = bounds(m, root)
	local s = targetH / math.max(hi.Y - lo.Y, 0.1)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			local cf = d.CFrame
			local pos = cf.Position
			d.Size = d.Size * s
			d.CFrame = CF(pos.X * s, (pos.Y - lo.Y) * s, pos.Z * s) * cf.Rotation
		elseif d:IsA("PointLight") then
			d.Range = d.Range * s
		end
	end
end

---------------------------------------------------------------------------
-- Builders (design space, forward = -Z; normalized afterwards)
---------------------------------------------------------------------------
local G = {}

-- Suburb: a giant topiary hedge dog with a collar and name tag.
function G.Hound(m)
	local hedge, light, dark = { 62, 128, 52 }, { 84, 154, 66 }, { 44, 96, 40 }
	local LM = M.LeafyGrass
	for _, x in ipairs({ -1.7, 1.7 }) do
		for _, z in ipairs({ -2.6, 2.6 }) do
			ball(m, "Paw", 2.3, V(x, 1.15, z), light, LM)
			part(m, "Leg", V(1.5, 3.2, 1.5), V(x, 3.4, z), hedge, LM)
		end
	end
	part(m, "Body", V(4.6, 3.4, 7.4), V(0, 6.3, 0), hedge, LM)
	ball(m, "Chest", 4.0, V(0, 6.6, -3.3), light, LM)
	ball(m, "Rump", 3.6, V(0, 6.9, 3.2), light, LM)
	part(m, "Neck", V(2.6, 2.4, 2.6), CF(0, 8.4, -3.7) * ANG(0.3, 0, 0), hedge, LM)
	local head = part(m, "Head", V(3.6, 3.2, 3.4), V(0, 10.0, -4.6), hedge, LM)
	part(m, "Snout", V(2.1, 1.6, 2.2), V(0, 9.2, -7.1), light, LM)
	ball(m, "Nose", 0.9, V(0, 9.75, -8.2), INK)
	for s = -1, 1, 2 do
		part(m, "Ear", V(0.9, 2.6, 1.7), CF(s * 2.15, 9.6, -4.4) * ANG(0, 0, s * 0.25), dark, LM)
	end
	eyes(m, V(0, 10.6, -6.35), 0.95, 0.9, { 255, 225, 70 }, 0.35, dark)
	part(m, "Mouth", V(1.9, 0.35, 0.3), V(0, 8.65, -8.15), INK)
	tooth(m, V(-0.55, 8.4, -8.25), 0.35)
	tooth(m, V(0.55, 8.4, -8.25), 0.35)
	-- red collar with a gold tag
	part(m, "Collar", V(3.0, 0.7, 3.0), CF(0, 8.0, -3.75) * ANG(0.3, 0, 0), { 200, 40, 45 }, M.Fabric)
	part(m, "Tag", V(0.15, 1.0, 1.0), CF(0, 7.0, -5.4) * ANG(0, PI / 2, 0), { 255, 200, 50 }, M.Foil, nil, "Cylinder")
	rod(m, "Tail", V(0, 7.4, 3.6), V(0, 9.6, 5.4), 0.8, dark, LM)
	ball(m, "TailPom", 1.9, V(0, 10.0, 5.7), light, LM)
	local flowers = { V(1.8, 8.05, 1.0), V(-1.6, 8.05, -1.5), V(0.6, 8.05, 2.6) }
	for _, p in ipairs(flowers) do
		ball(m, "Flower", 0.55, p, { 255, 140, 190 })
	end
	return head
end

-- Overgrowth: a hunched vine creature with a flytrap head.
function G.Stalker(m)
	local vine, dark, bark = { 58, 120, 46 }, { 40, 80, 34 }, { 92, 74, 44 }
	local jaw, glow, claw = { 190, 50, 60 }, { 170, 255, 90 }, { 220, 210, 170 }
	for s = -1, 1, 2 do
		local hip, knee, foot = V(s * 1.1, 5.2, 0.8), V(s * 1.6, 2.8, 0.2), V(s * 1.5, 0.45, 0.8)
		rod(m, "Leg", hip, knee, 1.0, bark, M.Wood)
		rod(m, "Leg", knee, foot, 0.9, bark, M.Wood)
		rod(m, "Root", foot, foot + V(s * 0.9, -0.2, -0.9), 0.5, bark, M.Wood)
		rod(m, "Root", foot, foot + V(-s * 0.3, -0.2, -1.1), 0.5, bark, M.Wood)
	end
	ball(m, "Pelvis", 2.2, V(0, 5.4, 0.8), dark, M.Grass)
	rod(m, "Vine", V(-0.5, 5.4, 0.9), V(0.4, 9.2, -0.6), 1.0, vine, M.Grass)
	rod(m, "Vine", V(0.5, 5.4, 0.9), V(-0.4, 9.2, -0.6), 1.0, vine, M.Grass)
	rod(m, "Vine", V(0, 5.6, 1.1), V(0, 9.0, 0.2), 0.9, dark, M.Grass)
	ball(m, "Chest", 3.0, V(0, 9.6, -0.6), vine, M.Grass)
	for s = -1, 1, 2 do
		local sh, el, hand = V(s * 1.6, 10.0, -0.6), V(s * 2.9, 7.2, -1.6), V(s * 2.7, 3.6, -2.6)
		rod(m, "Arm", sh, el, 0.75, vine, M.Grass)
		rod(m, "Arm", el, hand, 0.7, dark, M.Grass)
		for k = -1, 1, 2 do
			seg(m, "Claw", hand, hand + V(s * 0.25 + k * 0.35, -1.2, -0.5), 0.22, claw)
		end
		rod(m, "HangingVine", V(s * 1.4, 9.6, -0.2), V(s * 1.2, 6.6, -0.3), 0.3, dark, M.Grass)
		part(m, "Leaf", V(0.2, 1.2, 1.4), CF(s * 1.8, 10.9, 0) * ANG(0, s * PI / 2, 0) * ANG(-0.4, 0, 0), vine, M.Grass, nil, "Wedge")
		part(m, "Leaf", V(0.2, 1.0, 1.2), CF(s * 0.9, 7.6, 1.3) * ANG(0, s * PI / 2, 0) * ANG(-0.6, 0, 0), dark, M.Grass, nil, "Wedge")
	end
	local head = ball(m, "Head", 2.6, V(0, 11.4, -1.8), vine, M.Grass)
	-- open flytrap jaws
	local upper = CF(0, 12.5, -3.2) * ANG(0.55, 0, 0)
	local lower = CF(0, 10.6, -3.1) * ANG(-0.35, 0, 0)
	part(m, "Jaw", V(2.8, 0.45, 2.6), upper, vine, M.Grass)
	part(m, "JawInner", V(2.5, 0.15, 2.3), upper * CF(0, -0.28, 0), jaw)
	part(m, "Jaw", V(2.6, 0.5, 2.4), lower, vine, M.Grass)
	part(m, "JawInner", V(2.3, 0.15, 2.1), lower * CF(0, 0.3, 0), jaw)
	for _, x in ipairs({ -0.9, 0, 0.9 }) do
		part(m, "Tooth", V(0.22, 0.6, 0.22), upper * CF(x, -0.5, -1.15), WHITE)
		part(m, "Tooth", V(0.22, 0.55, 0.22), lower * CF(x, 0.5, -1.05), WHITE)
	end
	-- glowing eyes on stalks above the trap
	for s = -1, 1, 2 do
		rod(m, "EyeStalk", V(s * 0.5, 12.4, -1.5), V(s * 0.85, 13.7, -2.0), 0.3, dark, M.Grass)
	end
	eyes(m, V(0, 13.8, -2.05), 0.85, 0.8, glow)
	for i = 1, 3 do
		part(m, "Thorn", V(0.3, 0.8, 0.3), CF(0, 7.6 + i * 0.9, 1.0 - i * 0.25) * ANG(-0.6, PI / 4, 0), bark, M.Wood)
	end
	ball(m, "Bud", 0.8, V(0, 10.8, 0.95), { 255, 120, 200 }, M.Neon)
	return head
end

-- Droughtlands: a desert scorpion with its stinger raised over its back.
function G.Scorpion(m)
	local shell, dark, glow, sting = { 196, 150, 84 }, { 130, 90, 48 }, { 255, 70, 40 }, { 255, 150, 40 }
	part(m, "Body", V(4.2, 1.7, 3.4), V(0, 2.4, -0.6), shell, M.Sandstone)
	part(m, "Plate", V(3.6, 1.6, 2.6), V(0, 2.5, 2.0), dark, M.Sandstone)
	part(m, "Plate", V(2.9, 1.5, 2.2), V(0, 2.6, 4.1), shell, M.Sandstone)
	local head = part(m, "Head", V(3.2, 1.4, 2.2), V(0, 2.3, -3.2), shell, M.Sandstone)
	for s = -1, 1, 2 do
		ball(m, "Eye", 0.45, V(s * 0.45, 3.1, -4.15), glow, M.Neon)
		ball(m, "Eye", 0.38, V(s * 1.0, 2.95, -4.2), glow, M.Neon)
		part(m, "Mandible", V(0.4, 0.7, 0.5), CF(s * 0.5, 1.8, -4.45) * ANG(0, 0, s * 0.3), dark)
	end
	Kit.light(head, glow, 10, 1.2)
	-- eight legs
	for s = -1, 1, 2 do
		for _, z in ipairs({ -1.9, -0.7, 0.5, 1.7 }) do
			local base, knee, foot = V(s * 2.0, 2.3, z), V(s * 3.5, 3.4, z * 1.15), V(s * 4.6, 0.25, z * 1.35)
			rod(m, "Leg", base, knee, 0.5, dark)
			rod(m, "Leg", knee, foot, 0.45, dark)
		end
	end
	-- pincers
	for s = -1, 1, 2 do
		local sh, el, wr = V(s * 1.4, 2.4, -3.8), V(s * 2.7, 2.9, -5.4), V(s * 2.3, 2.7, -6.9)
		rod(m, "Arm", sh, el, 0.7, shell)
		rod(m, "Arm", el, wr, 0.65, shell)
		part(m, "Claw", V(1.5, 1.1, 1.6), wr + V(0, 0, -0.6), shell, M.Sandstone)
		part(m, "Pincer", V(0.45, 0.5, 1.5), CF(wr + V(s * 0.4, 0.15, -2.0)) * ANG(0, s * 0.25, 0), shell, M.Sandstone)
		part(m, "Pincer", V(0.4, 0.45, 1.3), CF(wr + V(-s * 0.35, 0.05, -1.9)) * ANG(0, -s * 0.3, 0), dark, M.Sandstone)
	end
	-- arched tail
	local pts = { V(0, 2.9, 5.0), V(0, 4.3, 6.3), V(0, 6.0, 6.7), V(0, 7.6, 6.2), V(0, 8.8, 5.0), V(0, 9.4, 3.5) }
	for i = 1, #pts - 1 do
		local w = 1.5 - i * 0.1
		seg(m, "Tail", pts[i], pts[i + 1], w, (i % 2 == 0) and dark or shell, M.Sandstone)
		if i > 1 then
			ball(m, "TailJoint", w + 0.1, pts[i], shell, M.Sandstone)
		end
	end
	local bulb = ball(m, "Stinger", 1.4, V(0, 9.3, 2.5), shell, M.Sandstone)
	seg(m, "Barb", V(0, 9.0, 2.0), V(0, 8.0, 1.0), 0.35, sting, M.Neon)
	ball(m, "Venom", 0.3, V(0, 7.8, 0.85), sting, M.Neon)
	Kit.light(bulb, sting, 12, 1.5)
	return head
end

-- Frostfall: a hulking frost yeti with curled horns.
function G.Yeti(m)
	local fur, skin, horn = { 236, 242, 250 }, { 112, 140, 178 }, { 222, 214, 196 }
	local glow, ice = { 110, 220, 255 }, { 170, 230, 255 }
	for s = -1, 1, 2 do
		part(m, "Foot", V(2.4, 0.9, 3.0), V(s * 1.5, 0.45, -0.3), skin)
		part(m, "Leg", V(2.1, 3.2, 2.2), V(s * 1.5, 2.5, 0.1), fur, M.Fabric)
		ball(m, "Shoulder", 3.4, V(s * 3.2, 8.4, 0.1), fur, M.Fabric)
		rod(m, "Arm", V(s * 3.6, 8.0, 0.1), V(s * 4.4, 4.6, -0.7), 2.2, fur, M.Fabric)
		part(m, "Hand", V(2.2, 2.4, 2.2), V(s * 4.5, 3.0, -0.9), skin)
		rod(m, "Horn", V(s * 1.6, 11.6, -0.4), V(s * 2.6, 12.4, 0.1), 0.8, horn)
		rod(m, "Horn", V(s * 2.6, 12.4, 0.1), V(s * 2.5, 13.6, 0.9), 0.6, horn)
		ball(m, "Tuft", 1.6, V(s * 0.9, 12.1, -0.3), fur, M.Fabric)
	end
	part(m, "Torso", V(6.2, 5.0, 4.2), V(0, 6.4, 0.2), fur, M.Fabric)
	part(m, "Belly", V(3.8, 3.4, 0.4), V(0, 6.0, -1.95), { 170, 195, 220 })
	local head = part(m, "Head", V(3.8, 3.4, 3.4), V(0, 10.4, -0.6), fur, M.Fabric)
	ball(m, "Tuft", 1.8, V(0, 12.3, 0), fur, M.Fabric)
	part(m, "FacePlate", V(2.8, 2.3, 0.4), V(0, 10.2, -2.35), skin)
	eyes(m, V(0, 10.65, -2.62), 0.7, 0.75, glow, 0.4, { 40, 50, 80 })
	local mouth = part(m, "Mouth", V(1.7, 0.6, 0.3), V(0, 9.5, -2.6), INK)
	tooth(m, V(-0.55, 9.3, -2.72), 0.45)
	tooth(m, V(0.55, 9.3, -2.72), 0.45)
	for i = -1, 1 do
		part(m, "IceSpike", V(0.6, 2.0, 0.6), CF(i * 1.2, 9.0 + (1 - math.abs(i)) * 0.6, 2.4) * ANG(-0.5, PI / 4, i * 0.3), ice, M.Glass, 0.15)
	end
	Kit.particles(mouth, { color = WHITE, size = 0.8, sizeEnd = 1.6, rate = 6, speed = 2, lifetime = 1, spread = 20, transparency = 0.5, emission = 0 })
	return head
end

-- Magma Basin: a magma serpent-dragon rising out of its coils.
function G.Wyrm(m)
	local rock, plate, lava, glow, horn = { 62, 38, 32 }, { 92, 52, 40 }, { 255, 110, 30 }, { 255, 200, 50 }, { 40, 28, 26 }
	for k = 0, 4 do
		local a = k / 5 * PI * 2 + 0.3
		ball(m, "Coil", 3.0, V(math.cos(a) * 2.6, 1.5, 2.6 + math.sin(a) * 2.6), rock, M.Basalt)
	end
	part(m, "LavaCrack", V(0.25, 0.25, 2.2), CF(-2.0, 2.75, 1.0) * ANG(0, 0.6, 0), lava, M.Neon)
	part(m, "LavaCrack", V(0.25, 0.25, 1.8), CF(1.4, 2.75, 4.5) * ANG(0, -0.4, 0), lava, M.Neon)
	local neck = { { 1.8, 3.4, 1.2, 3.0 }, { 2.2, 5.4, 0.4, 2.8 }, { 1.3, 7.3, -0.3, 2.6 }, { -0.4, 8.8, -0.7, 2.4 }, { -0.9, 10.3, -1.2, 2.2 }, { -0.1, 11.5, -1.8, 2.1 } }
	for i, n in ipairs(neck) do
		local p = V(n[1], n[2], n[3])
		ball(m, "Neck", n[4], p, (i % 2 == 0) and plate or rock, M.Basalt)
		if i >= 2 and i <= 5 then
			part(m, "Belly", V(1.4, 1.0, 0.3), p + V(0, 0, -n[4] / 2 + 0.05), lava, M.Neon)
		end
		if i <= 5 then
			part(m, "Spike", V(0.4, 1.2, 1.0), CF(p + V(0, n[4] * 0.42, n[4] * 0.32)) * ANG(-0.6, 0, 0), horn, M.Slate, nil, "Wedge")
		end
	end
	local head = part(m, "Head", V(3.0, 2.4, 3.2), V(0, 12.5, -2.9), plate, M.Basalt)
	part(m, "Snout", V(2.2, 1.5, 2.4), V(0, 12.1, -5.2), plate, M.Basalt)
	part(m, "Jaw", V(2.0, 0.6, 2.8), CF(0, 10.9, -4.6) * ANG(-0.3, 0, 0), rock, M.Basalt)
	local maw = part(m, "MouthGlow", V(1.7, 0.25, 2.2), V(0, 11.35, -4.7), lava, M.Neon)
	tooth(m, V(-0.6, 11.15, -6.3), 0.45)
	tooth(m, V(0.6, 11.15, -6.3), 0.45)
	for s = -1, 1, 2 do
		rod(m, "Horn", V(s * 1.0, 13.5, -2.2), V(s * 1.7, 14.6, -0.6), 0.7, horn)
		rod(m, "Horn", V(s * 1.7, 14.6, -0.6), V(s * 1.9, 15.2, 0.6), 0.45, horn)
		ball(m, "Nostril", 0.3, V(s * 0.5, 12.6, -6.42), lava, M.Neon)
		rod(m, "WingBone", V(s * 1.8, 8.0, 0.0), V(s * 5.0, 10.5, 1.5), 0.4, horn)
		part(m, "Wing", V(0.2, 2.6, 3.0), CF(s * 3.6, 8.6, 1.4) * ANG(0, 0, s * 0.7), { 120, 40, 30 })
	end
	eyes(m, V(0, 13.0, -4.55), 1.0, 0.8, glow, 0.4, horn)
	Kit.light(maw, lava, 14, 2)
	Kit.particles(maw, { color = glow, color2 = lava, size = 0.5, rate = 10, speed = 2, lifetime = 0.8, spread = 30, accel = V(0, -6, 0), emission = 1 })
	return head
end

-- Deep Abyss: a huge anglerfish walking on its fins, glowing lure out front.
function G.Angler(m)
	local skin, belly, fin = { 44, 48, 78 }, { 78, 86, 120 }, { 60, 70, 110 }
	local glow, eye = { 120, 255, 230 }, { 220, 255, 245 }
	local head = ball(m, "Head", 8.0, V(0, 6.2, 0), skin)
	ball(m, "Hump", 6.0, V(0, 6.6, 2.4), Kit.shade(skin, 0.85))
	part(m, "Jaw", V(7.0, 1.8, 5.6), V(0, 3.3, -1.6), belly)
	part(m, "Mouth", V(6.0, 1.6, 0.5), V(0, 4.6, -3.85), INK)
	for i = 0, 4 do
		tooth(m, V(-2.2 + i * 1.1, 5.35, -4.05), 0.6)
	end
	for i = 0, 3 do
		tooth(m, V(-1.65 + i * 1.1, 4.15, -4.35), 0.55)
	end
	for s = -1, 1, 2 do
		ball(m, "Eye", 1.0, V(s * 2.0, 8.1, -3.05), eye, M.Neon)
		ball(m, "Pupil", 0.4, V(s * 2.0, 8.1, -3.55), INK)
		part(m, "Brow", V(1.4, 0.35, 0.5), CF(s * 1.95, 8.85, -3.0) * ANG(0, 0, s * 0.4), Kit.shade(skin, 0.6))
		seg(m, "Fin", V(s * 3.5, 4.6, -0.8), V(s * 4.4, 0.2, -1.8), 0.5, fin, M.SmoothPlastic, nil, 1.6)
		seg(m, "Fin", V(s * 3.4, 4.6, 2.2), V(s * 4.3, 0.2, 3.2), 0.5, fin, M.SmoothPlastic, nil, 1.6)
		ball(m, "Spot", 0.45, V(s * 3.85, 6.5, 0.9), glow, M.Neon)
		ball(m, "Spot", 0.4, V(s * 3.3, 4.4, 1.8), glow, M.Neon)
	end
	-- lure
	rod(m, "LureStalk", V(0, 10.0, -0.6), V(0, 12.0, -2.4), 0.35, fin)
	rod(m, "LureStalk", V(0, 12.0, -2.4), V(0, 11.2, -4.9), 0.3, fin)
	local lure = ball(m, "Lure", 1.3, V(0, 10.75, -5.2), glow, M.Neon)
	Kit.light(lure, glow, 24, 3)
	Kit.particles(lure, { color = glow, size = 0.25, rate = 6, speed = 0.6, lifetime = 1.6, emission = 1 })
	-- tail
	part(m, "TailStalk", V(1.6, 2.4, 2.4), V(0, 6.2, 5.4), skin)
	seg(m, "TailFin", V(0, 6.6, 6.0), V(0, 9.4, 7.8), 0.35, fin, M.SmoothPlastic, nil, 2.0)
	seg(m, "TailFin", V(0, 5.8, 6.0), V(0, 3.2, 7.8), 0.35, fin, M.SmoothPlastic, nil, 2.0)
	local spines = { { V(0, 10.0, 1.2), V(0, 11.6, 2.2) }, { V(0, 9.6, 2.6), V(0, 11.0, 3.6) }, { V(0, 9.0, 3.8), V(0, 10.2, 4.8) } }
	for _, sp in ipairs(spines) do
		rod(m, "Spine", sp[1], sp[2], 0.2, fin)
	end
	return head
end

-- Prehistoric: a T-rex with tiny arms and a big toothy head.
function G.Rex(m)
	local skin, belly, dark = { 86, 118, 62 }, { 190, 180, 120 }, { 56, 80, 42 }
	local glow, claw = { 255, 90, 40 }, { 230, 225, 210 }
	for s = -1, 1, 2 do
		part(m, "Foot", V(2.0, 1.0, 3.2), V(s * 1.9, 0.5, -0.7), dark)
		part(m, "Toe", V(0.4, 0.4, 0.5), CF(s * 1.4, 0.3, -2.45) * ANG(0, 0, PI / 4), claw)
		part(m, "Toe", V(0.4, 0.4, 0.5), CF(s * 2.4, 0.3, -2.45) * ANG(0, 0, PI / 4), claw)
		rod(m, "Shin", V(s * 1.9, 1.0, 0.3), V(s * 1.9, 4.6, 1.5), 1.5, skin)
		part(m, "Thigh", V(2.3, 3.8, 3.4), CF(s * 2.0, 6.2, 0.8) * ANG(-0.2, 0, 0), skin)
		rod(m, "Arm", V(s * 1.9, 9.6, -2.6), V(s * 2.1, 8.4, -3.6), 0.6, skin)
		rod(m, "Claw", V(s * 2.1, 8.4, -3.6), V(s * 2.1, 7.9, -4.1), 0.25, claw)
	end
	part(m, "Body", V(4.4, 4.4, 7.0), CF(0, 8.4, 0.6) * ANG(0.22, 0, 0), skin)
	part(m, "Belly", V(3.4, 3.0, 0.5), CF(0, 8.3, -2.65) * ANG(0.22, 0, 0), belly)
	local tail = { V(0, 8.6, 3.9), V(0, 8.0, 6.6), V(0, 7.1, 9.0), V(0, 6.0, 11.0), V(0, 5.2, 12.6) }
	local widths = { 3.4, 2.6, 1.8, 1.1 }
	for i = 1, 4 do
		seg(m, "Tail", tail[i], tail[i + 1], widths[i], skin)
	end
	part(m, "Neck", V(2.8, 3.2, 2.8), CF(0, 11.0, -2.6) * ANG(0.5, 0, 0), skin)
	local head = part(m, "Head", V(3.4, 2.9, 5.4), V(0, 12.8, -4.9), skin)
	part(m, "Jaw", V(3.0, 1.0, 4.8), CF(0, 10.9, -5.0) * ANG(-0.22, 0, 0), Kit.shade(skin, 0.85))
	part(m, "MouthInner", V(2.8, 0.8, 4.4), V(0, 11.6, -5.1), { 120, 30, 30 })
	for _, t in ipairs({ { -0.55, -7.4 }, { 0.55, -7.4 }, { -1.4, -6.4 }, { 1.4, -6.4 } }) do
		tooth(m, V(t[1], 11.2, t[2]), 0.5)
	end
	tooth(m, V(-0.9, 11.75, -6.9), 0.4)
	tooth(m, V(0.9, 11.75, -6.9), 0.4)
	for s = -1, 1, 2 do
		ball(m, "Eye", 0.8, V(s * 1.55, 13.4, -5.6), glow, M.Neon)
		part(m, "Brow", V(1.0, 0.4, 1.2), CF(s * 1.5, 14.0, -5.6) * ANG(0, 0, s * 0.3), dark)
		ball(m, "Nostril", 0.35, V(s * 0.6, 13.3, -7.62), INK)
	end
	Kit.light(head, glow, 12, 1.2)
	local spikes = { V(0, 10.9, -0.8), V(0, 10.6, 1.2), V(0, 10.1, 3.2), V(0, 9.4, 5.4), V(0, 8.4, 7.8), V(0, 7.2, 10.0) }
	for i, p in ipairs(spikes) do
		local sz = 1.3 - i * 0.1
		part(m, "Spike", V(0.5, sz, sz * 1.1), p + V(0, sz * 0.3, 0), { 200, 110, 50 }, M.SmoothPlastic, nil, "Wedge")
	end
	return head
end

-- Skylands: a giant storm bird with half-spread wings and a lightning crest.
function G.Roc(m)
	local navy, chest, beak = { 60, 70, 122 }, { 150, 162, 205 }, { 250, 196, 60 }
	local leg, glow, feather2 = { 232, 182, 64 }, { 255, 250, 160 }, { 90, 100, 160 }
	for s = -1, 1, 2 do
		local ankle = V(s * 1.4, 0.6, 0.1)
		rod(m, "Toe", ankle, V(s * 1.0, 0.25, -1.7), 0.5, leg)
		rod(m, "Toe", ankle, V(s * 2.0, 0.25, -1.4), 0.5, leg)
		rod(m, "Toe", ankle, V(s * 1.4, 0.25, 1.1), 0.5, leg)
		rod(m, "Shin", ankle, V(s * 1.5, 4.6, 0.5), 0.8, leg)
		part(m, "Thigh", V(2.0, 2.8, 2.4), V(s * 1.5, 5.6, 0.6), navy)
	end
	ball(m, "Body", 5.8, V(0, 8.6, 0.8), navy)
	ball(m, "Chest", 4.6, V(0, 8.3, -0.6), chest)
	rod(m, "Neck", V(0, 10.2, -0.4), V(0, 11.8, -1.4), 2.4, navy)
	local head = ball(m, "Head", 3.4, V(0, 12.8, -1.8), navy)
	part(m, "Beak", V(1.3, 1.1, 2.2), V(0, 12.5, -4.0), beak)
	part(m, "BeakHook", V(1.0, 1.1, 0.9), CF(0, 11.85, -4.85) * ANG(0.5, 0, 0), Kit.shade(beak, 0.85))
	eyes(m, V(0, 13.15, -3.25), 0.95, 0.75, glow, 0.45, { 30, 30, 60 })
	-- lightning crest
	local crest = { V(0, 14.2, -1.4), V(0.5, 15.0, -1.1), V(-0.2, 15.4, -0.7), V(0.4, 16.3, -0.3) }
	for i = 1, #crest - 1 do
		seg(m, "Crest", crest[i], crest[i + 1], 0.4, glow, M.Neon)
	end
	seg(m, "CrestFeather", V(0, 14.0, -0.8), V(0, 15.0, 0.6), 0.3, navy, M.SmoothPlastic, nil, 0.9)
	-- wings
	for s = -1, 1, 2 do
		local sh, wr = V(s * 2.6, 10.2, 0.8), V(s * 5.8, 12.0, 1.6)
		rod(m, "WingArm", sh, wr, 1.1, navy)
		for k = 0, 4 do
			local r0 = sh:Lerp(wr, 0.2 + 0.2 * k)
			seg(m, "Feather", r0, r0 + V(s * (1.2 + 0.5 * k), -3.4 + 0.5 * k, 0.6), 0.3, (k % 2 == 0) and navy or feather2, M.SmoothPlastic, nil, 1.1)
		end
		seg(m, "WingBolt", sh + V(s * 0.8, 0, -0.6), wr + V(0, 0, -0.6), 0.25, glow, M.Neon)
	end
	for i = -1, 1 do
		seg(m, "TailFeather", V(0, 7.4, 3.4), V(i * 1.2, 4.6 - (1 - math.abs(i)) * 0.4, 6.8 + (1 - math.abs(i)) * 0.4), 1.0, navy, M.SmoothPlastic, nil, 0.3)
	end
	local top = m:FindFirstChild("Crest")
	Kit.light(top, glow, 14, 2)
	Kit.particles(top, { color = glow, size = 0.4, rate = 10, speed = 4, lifetime = 0.3, emission = 1 })
	return head
end

-- Void Realm: an armored void knight with a glowing visor and orbiting shards.
function G.Warden(m)
	local armor, trim, glow = { 44, 38, 64 }, { 90, 70, 130 }, { 200, 90, 255 }
	local cape, steel = { 40, 14, 60 }, { 120, 110, 150 }
	for s = -1, 1, 2 do
		part(m, "Sabaton", V(1.9, 1.0, 2.6), V(s * 1.25, 0.5, -0.3), armor, M.Metal)
		part(m, "Greave", V(1.6, 4.2, 1.8), V(s * 1.2, 3.1, 0), armor, M.Metal)
		part(m, "KneeGuard", V(1.8, 1.0, 0.6), V(s * 1.2, 3.6, -0.95), trim, M.Metal)
		part(m, "Pauldron", V(2.3, 1.5, 2.7), V(s * 3.1, 11.0, 0), trim, M.Metal)
		rod(m, "PauldronSpike", V(s * 3.2, 11.6, 0), V(s * 3.9, 13.0, 0), 0.45, armor, M.Metal)
		rod(m, "Arm", V(s * 3.2, 10.4, 0), V(s * 3.4, 7.4, -0.5), 1.4, armor, M.Metal)
		part(m, "Gauntlet", V(1.6, 1.9, 1.6), V(s * 3.4, 6.5, -0.7), trim, M.Metal)
		part(m, "Rune", V(0.2, 1.6, 0.1), V(s * 1.3, 8.6, -1.47), glow, M.Neon)
		rod(m, "Horn", V(s * 1.0, 13.6, 0), V(s * 1.8, 15.4, 0.6), 0.55, armor, M.Metal)
		ball(m, "HornTip", 0.4, V(s * 1.8, 15.4, 0.6), glow, M.Neon)
	end
	part(m, "Tasset", V(4.4, 1.8, 2.8), V(0, 5.9, 0), armor, M.Metal)
	part(m, "Torso", V(4.8, 4.4, 2.9), V(0, 9.0, 0), armor, M.Metal)
	local core = ball(m, "VoidCore", 1.3, V(0, 9.4, -1.45), glow, M.Neon)
	Kit.light(core, glow, 14, 2)
	part(m, "Gorget", V(3.0, 0.8, 2.6), V(0, 11.3, -0.1), trim, M.Metal)
	part(m, "Cape", V(4.4, 9.5, 0.3), CF(0, 7.6, 1.65) * ANG(-0.08, 0, 0), cape, M.Fabric)
	-- greatsword held point-down in the right hand
	rod(m, "Grip", V(3.4, 5.6, -0.7), V(3.4, 7.4, -0.7), 0.35, INK)
	ball(m, "Pommel", 0.5, V(3.4, 7.6, -0.7), glow, M.Neon)
	part(m, "Guard", V(2.6, 0.4, 0.6), V(3.4, 5.4, -0.7), trim, M.Metal)
	part(m, "Blade", V(0.35, 5.0, 1.1), V(3.4, 2.85, -0.7), steel, M.Metal)
	part(m, "BladeEdge", V(0.4, 4.6, 0.15), V(3.4, 2.9, -1.3), glow, M.Neon)
	local head = part(m, "Head", V(2.5, 2.9, 2.7), V(0, 12.6, -0.2), armor, M.Metal)
	part(m, "Visor", V(1.9, 0.32, 0.15), V(0, 12.8, -1.56), glow, M.Neon)
	eyes(m, V(0, 12.8, -1.6), 0.5, 0.55, glow)
	part(m, "HelmCrest", V(0.4, 1.0, 2.2), V(0, 14.3, -0.1), trim, M.Metal)
	for k = 0, 3 do
		local a = k * PI / 2 + 0.5
		local p = part(m, "Shard", V(0.6, 1.6, 0.6), CF(math.cos(a) * 5.2, 8 + k * 1.2, math.sin(a) * 5.2) * ANG(0.3, a, 0.3), glow, M.Neon, 0.1)
		orbit(p, 0.8)
		p:SetAttribute("SelfSpin", 1.5)
	end
	Kit.particles(core, { color = glow, color2 = cape, size = 0.5, rate = 10, speed = 1, lifetime = 1.6, emission = 1 })
	return head
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--[[
	GuardianModels.build(kind, zoneIndex) -> Model
]]
function GuardianModels.build(kind, zoneIndex)
	local builder = G[kind]
	if not builder then
		error("Unknown guardian kind " .. tostring(kind))
	end
	local m = Instance.new("Model")
	m.Name = kind .. "Guardian"
	local root = Kit.part(m, { name = "Root", size = V(2, 0.2, 2), transparency = 1, collide = false })
	m.PrimaryPart = root
	builder(m)
	normalize(m, root, GuardianModels.Heights[kind] or 14)
	m:SetAttribute("GuardianKind", kind)
	if zoneIndex then
		m:SetAttribute("ZoneIndex", zoneIndex)
	end
	Kit.setCollide(m, false)
	return m
end

function GuardianModels.kinds()
	local out = {}
	for k in pairs(G) do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

return GuardianModels
