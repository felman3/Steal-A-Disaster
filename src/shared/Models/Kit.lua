--[[
	Kit — part-construction helpers shared by the world builders and model
	factories. Everything is plain Parts (no external assets), so the whole game
	builds from source.
]]

local Kit = {}

local function rgb(c)
	if typeof(c) == "Color3" then
		return c
	end
	return Color3.fromRGB(c[1], c[2], c[3])
end
Kit.rgb = rgb

function Kit.shade(c, f)
	local col = rgb(c)
	return Color3.new(math.clamp(col.R * f, 0, 1), math.clamp(col.G * f, 0, 1), math.clamp(col.B * f, 0, 1))
end

function Kit.mix(a, b, t)
	return rgb(a):Lerp(rgb(b), t)
end

--[[
	Kit.part(parent, {
		size = Vector3, cf = CFrame, color = {r,g,b}|Color3, material = Enum.Material.X,
		shape = "Ball"|"Cylinder"|"Block"|"Wedge"|"CornerWedge", transparency, name,
		collide = bool (default true), anchored = bool (default true), reflectance,
		castShadow = bool,
	})
]]
function Kit.part(parent, o)
	local p
	if o.shape == "Wedge" then
		p = Instance.new("WedgePart")
	elseif o.shape == "CornerWedge" then
		p = Instance.new("CornerWedgePart")
	else
		p = Instance.new("Part")
		if o.shape == "Ball" then
			p.Shape = Enum.PartType.Ball
		elseif o.shape == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder
		end
	end
	p.Name = o.name or "Part"
	p.Anchored = o.anchored ~= false
	p.CanCollide = o.collide ~= false
	p.CanTouch = o.touch == true
	p.CanQuery = o.query ~= false
	p.CastShadow = o.castShadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = o.size or Vector3.new(4, 1, 4)
	p.CFrame = o.cf or CFrame.new()
	p.Color = rgb(o.color or { 163, 162, 165 })
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.Transparency = o.transparency or 0
	p.Reflectance = o.reflectance or 0
	p.Parent = parent
	return p
end

function Kit.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name or "Model"
	m.Parent = parent
	return m
end

function Kit.folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Vertical cylinder (Roblox cylinders run along X; rotate so the axis is Y).
function Kit.cylinder(parent, o)
	local h, d = o.height or 1, o.diameter or 4
	local cf = (o.cf or CFrame.new()) * CFrame.Angles(0, 0, math.pi / 2)
	return Kit.part(parent, {
		name = o.name,
		size = Vector3.new(h, d, d),
		cf = cf,
		color = o.color,
		material = o.material,
		shape = "Cylinder",
		transparency = o.transparency,
		collide = o.collide,
		castShadow = o.castShadow,
		reflectance = o.reflectance,
	})
end

function Kit.ball(parent, o)
	local d = o.diameter or 4
	return Kit.part(parent, {
		name = o.name,
		size = Vector3.new(d, d, d),
		cf = o.cf or CFrame.new(),
		color = o.color,
		material = o.material,
		shape = "Ball",
		transparency = o.transparency,
		collide = o.collide,
		castShadow = o.castShadow,
		reflectance = o.reflectance,
	})
end

-- A wedge ramp/roof between two heights along local Z.
function Kit.wedge(parent, o)
	return Kit.part(parent, {
		name = o.name,
		size = o.size,
		cf = o.cf,
		color = o.color,
		material = o.material,
		shape = "Wedge",
		collide = o.collide,
		transparency = o.transparency,
	})
end

function Kit.light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = rgb(color)
	l.Range = range or 12
	l.Brightness = brightness or 1.5
	l.Shadows = false
	l.Parent = parent
	return l
end

function Kit.particles(parent, o)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(rgb(o.color or { 255, 255, 255 }), rgb(o.color2 or o.color or { 255, 255, 255 }))
	e.Size = NumberSequence.new(o.size or 0.6, o.sizeEnd or 0)
	e.Transparency = NumberSequence.new(o.transparency or 0.2, 1)
	e.Lifetime = NumberRange.new(o.lifetime or 1, (o.lifetime or 1) * 1.5)
	e.Rate = o.rate or 10
	e.Speed = NumberRange.new(o.speed or 2, (o.speed or 2) * 1.5)
	e.SpreadAngle = Vector2.new(o.spread or 180, o.spread or 180)
	e.LightEmission = o.emission or 0.6
	e.Acceleration = o.accel or Vector3.new(0, 0, 0)
	e.Drag = o.drag or 0
	if o.texture then
		e.Texture = o.texture
	end
	e.Parent = parent
	return e
end

-- Weld every BasePart in `model` to `root` (used for carried/animated models).
function Kit.weldAll(model, root)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = root
		end
	end
end

function Kit.setCollide(model, collide)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = collide
			d.CanTouch = false
			if not collide then
				d.CanQuery = false
			end
		end
	end
end

function Kit.setAnchored(model, anchored)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = anchored
		end
	end
end

function Kit.setMassless(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Massless = true
		end
	end
end

-- Bold, outlined world-space label.
function Kit.billboard(adornee, o)
	local bb = Instance.new("BillboardGui")
	bb.Name = o.name or "Label"
	bb.Size = o.size or UDim2.new(0, 220, 0, 60)
	bb.StudsOffset = o.offset or Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = o.alwaysOnTop == true
	bb.MaxDistance = o.maxDistance or 120
	bb.LightInfluence = 0
	bb.Adornee = adornee
	bb.Parent = adornee
	return bb
end

function Kit.text(parent, o)
	local t = Instance.new("TextLabel")
	t.Name = o.name or "Text"
	t.BackgroundTransparency = 1
	t.Size = o.size or UDim2.new(1, 0, 1, 0)
	t.Position = o.position or UDim2.new(0, 0, 0, 0)
	t.AnchorPoint = o.anchor or Vector2.new(0, 0)
	t.Text = o.text or ""
	t.TextColor3 = rgb(o.color or { 255, 255, 255 })
	t.TextStrokeColor3 = rgb(o.strokeColor or { 20, 20, 30 })
	t.TextStrokeTransparency = o.stroke == false and 1 or 0
	t.Font = o.font or Enum.Font.FredokaOne
	-- TextWrapped must be set before TextScaled: in Roblox, TextWrapped = false turns TextScaled off.
	t.TextWrapped = o.wrapped == true
	t.TextScaled = o.scaled ~= false
	t.TextSize = o.textSize or 24
	t.TextXAlignment = o.xAlign or Enum.TextXAlignment.Center
	t.RichText = o.rich == true
	t.ZIndex = o.z or 1
	t.Parent = parent
	return t
end

return Kit
