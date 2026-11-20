--[[
	Theme — the visual language of the HUD.

	Bold cartoon typography with thick ink outlines, solid saturated fills,
	small corner radii, chunky square buttons. No glass, no gradients, no
	dashboard cards.
]]

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Ink = Color3.fromRGB(22, 20, 34)
Theme.White = Color3.fromRGB(255, 255, 255)
Theme.Cream = Color3.fromRGB(255, 247, 228)
Theme.CreamDark = Color3.fromRGB(240, 226, 196)
Theme.Money = Color3.fromRGB(110, 240, 90)
Theme.Speed = Color3.fromRGB(255, 220, 60)
Theme.Danger = Color3.fromRGB(255, 70, 80)
Theme.Frenzy = Color3.fromRGB(255, 60, 220)
Theme.Green = Color3.fromRGB(70, 200, 90)
Theme.Blue = Color3.fromRGB(60, 160, 255)
Theme.Purple = Color3.fromRGB(150, 80, 240)
Theme.Orange = Color3.fromRGB(255, 150, 40)
Theme.Gray = Color3.fromRGB(150, 150, 160)

Theme.FontBold = Enum.Font.FredokaOne
Theme.FontDisplay = Enum.Font.LuckiestGuy

function Theme.rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

function Theme.corner(parent, px)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px or 8)
	c.Parent = parent
	return c
end

-- outline for frames/buttons (border)
function Theme.outline(parent, thickness, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or Theme.Ink
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

-- outline for text glyphs
function Theme.textStroke(label, thickness, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2.5
	s.Color = color or Theme.Ink
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = label
	return s
end

function Theme.label(parent, o)
	local t = Instance.new("TextLabel")
	t.Name = o.name or "Label"
	t.BackgroundTransparency = 1
	t.Size = o.size or UDim2.new(1, 0, 1, 0)
	t.Position = o.position or UDim2.new(0, 0, 0, 0)
	t.AnchorPoint = o.anchor or Vector2.new(0, 0)
	t.Font = o.font or Theme.FontBold
	t.Text = o.text or ""
	t.TextColor3 = o.color or Theme.White
	t.TextScaled = o.scaled ~= false
	t.TextSize = o.textSize or 24
	t.TextWrapped = o.wrapped == true
	t.TextXAlignment = o.xAlign or Enum.TextXAlignment.Center
	t.TextYAlignment = o.yAlign or Enum.TextYAlignment.Center
	t.RichText = o.rich == true
	t.ZIndex = o.z or 2
	t.LayoutOrder = o.order or 0
	t.Parent = parent
	if o.stroke ~= false then
		Theme.textStroke(t, o.strokeThickness or 2.5, o.strokeColor)
	end
	if o.maxText then
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = o.maxText
		c.Parent = t
	end
	return t
end

function Theme.frame(parent, o)
	local f = Instance.new("Frame")
	f.Name = o.name or "Frame"
	f.Size = o.size or UDim2.new(1, 0, 1, 0)
	f.Position = o.position or UDim2.new(0, 0, 0, 0)
	f.AnchorPoint = o.anchor or Vector2.new(0, 0)
	f.BackgroundColor3 = o.color or Theme.Cream
	f.BackgroundTransparency = o.transparency or 0
	f.BorderSizePixel = 0
	f.ZIndex = o.z or 1
	f.LayoutOrder = o.order or 0
	f.Visible = o.visible ~= false
	f.Parent = parent
	if o.corner ~= false then
		Theme.corner(f, o.corner or 8)
	end
	if o.outline ~= false then
		Theme.outline(f, o.outline or 3)
	end
	return f
end

-- Pressable chunky button. o = { text, icon, color, size, position, anchor, onClick, textColor, name }
function Theme.button(parent, o)
	local b = Instance.new("TextButton")
	b.Name = o.name or "Button"
	b.Size = o.size or UDim2.new(0, 120, 0, 44)
	b.Position = o.position or UDim2.new(0, 0, 0, 0)
	b.AnchorPoint = o.anchor or Vector2.new(0, 0)
	b.BackgroundColor3 = o.color or Theme.Green
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Text = ""
	b.ZIndex = o.z or 3
	b.LayoutOrder = o.order or 0
	b.Parent = parent
	Theme.corner(b, o.corner or 10)
	Theme.outline(b, 3)
	-- lower lip for a chunky, pressable look
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.BackgroundColor3 = Color3.new(0, 0, 0)
	lip.BackgroundTransparency = 0.75
	lip.BorderSizePixel = 0
	lip.Size = UDim2.new(1, 0, 0, 5)
	lip.Position = UDim2.new(0, 0, 1, -5)
	lip.ZIndex = b.ZIndex
	lip.Parent = b
	Theme.corner(lip, 6)
	local scale = Instance.new("UIScale")
	scale.Parent = b
	if o.icon then
		Theme.label(b, { name = "Icon", text = o.icon, size = UDim2.new(1, 0, 0.62, 0), position = UDim2.new(0, 0, 0.04, 0), z = b.ZIndex + 1, stroke = false })
		Theme.label(b, { name = "Label", text = o.text or "", size = UDim2.new(1, -6, 0.3, 0), position = UDim2.new(0, 3, 0.64, 0), color = o.textColor or Theme.White, z = b.ZIndex + 1, strokeThickness = 2 })
	else
		Theme.label(b, { name = "Label", text = o.text or "", size = UDim2.new(1, -12, 1, -10), position = UDim2.new(0, 6, 0, 4), color = o.textColor or Theme.White, z = b.ZIndex + 1, strokeThickness = 2 })
	end
	local function press(to)
		TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = to }):Play()
	end
	b.MouseButton1Down:Connect(function()
		press(0.92)
	end)
	b.MouseButton1Up:Connect(function()
		press(1)
	end)
	b.MouseLeave:Connect(function()
		press(1)
	end)
	b.MouseEnter:Connect(function()
		press(1.05)
	end)
	if o.onClick then
		b.Activated:Connect(function()
			o.onClick(b)
		end)
	end
	return b
end

function Theme.setButtonText(b, text)
	local t = b:FindFirstChild("Label")
	if t then
		t.Text = text
	end
end

function Theme.pop(guiObject, from)
	local s = guiObject:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Parent = guiObject
	end
	s.Scale = from or 0.6
	TweenService:Create(s, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

return Theme
