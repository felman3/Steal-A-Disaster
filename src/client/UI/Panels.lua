--[[
	Panels — the left navigation and the two modal panels (Shop, Index).

	Compact left column of chunky square buttons; one centered panel at a time
	with a colored title bar, solid cream body and a big red close button.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local Util = require(Shared.Util)
local SpeedLogic = require(Shared.Logic.SpeedLogic)
local EconomyLogic = require(Shared.Logic.EconomyLogic)
local UpgradeLogic = require(Shared.Logic.UpgradeLogic)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Panels = {}

local open = nil
local panels = {}

local ARCH_ICON = {
	Vortex = "🌪",
	Cloud = "☁",
	StormCloud = "⛈",
	Golem = "🗿",
	Serpent = "🐍",
	Beast = "🐾",
	Wisp = "✨",
	Maw = "🕳",
	Volcano = "🌋",
	Meteor = "☄",
	Wave = "🌊",
	Bird = "🐦",
	Entity = "👁",
	BlackHole = "⚫",
}
Panels.ARCH_ICON = ARCH_ICON

local UPGRADE_ICON = { Treadmill = "🏃", Carry = "🎒", Pods = "🥚", Pedestals = "🏛", Shield = "🛡" }

local function makePanel(screen, name, title, color)
	local p = Theme.frame(screen, { name = name, size = UDim2.new(0, 560, 0, 440), position = UDim2.new(0.5, 0, 0.5, 0), anchor = Vector2.new(0.5, 0.5), color = Theme.Cream, corner = 14, visible = false, z = 10 })
	local sizeC = Instance.new("UISizeConstraint")
	sizeC.MaxSize = Vector2.new(560, 440)
	sizeC.Parent = p
	local header = Theme.frame(p, { name = "Header", size = UDim2.new(1, 0, 0, 58), color = color, corner = 14, z = 11 })
	Theme.label(header, { name = "Title", text = title, size = UDim2.new(1, -90, 1, -12), position = UDim2.new(0, 16, 0, 6), font = Theme.FontDisplay, xAlign = Enum.TextXAlignment.Left, z = 12, strokeThickness = 3 })
	Theme.button(header, {
		name = "Close",
		text = "X",
		color = Theme.Danger,
		size = UDim2.new(0, 46, 0, 46),
		position = UDim2.new(1, -8, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		z = 13,
		onClick = function()
			Panels.close()
		end,
	})
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Size = UDim2.new(1, -24, 1, -78)
	body.Position = UDim2.new(0, 12, 0, 68)
	body.ScrollBarThickness = 8
	body.ScrollBarImageColor3 = Theme.Ink
	body.CanvasSize = UDim2.new(0, 0, 0, 0)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.ZIndex = 11
	body.Parent = p
	return p, body
end

-- Shop ---------------------------------------------------------------------------
local function effectText(id, snap)
	local lvl = snap.upgrades[id]
	if id == "Treadmill" then
		return "+" .. Util.formatNumber(SpeedLogic.gainPerStep(lvl)) .. " → +" .. Util.formatNumber(SpeedLogic.gainPerStep(lvl + 1)) .. " Speed per step"
	elseif id == "Carry" then
		return "Carry " .. lvl .. " → " .. (lvl + 1) .. " cores at once"
	elseif id == "Pods" then
		return lvl .. " → " .. (lvl + 1) .. " incubator pods"
	elseif id == "Pedestals" then
		return lvl .. " → " .. (lvl + 1) .. " display pedestals"
	elseif id == "Shield" then
		return UpgradeLogic.shieldDuration(lvl) .. "s → " .. UpgradeLogic.shieldDuration(lvl + 1) .. "s base lock"
	end
	return ""
end

local function buildShop(screen)
	local p, body = makePanel(screen, "ShopPanel", "🛒 UPGRADES", Theme.Green)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	local rows = {}
	for i, id in ipairs(Config.UpgradeOrder) do
		local def = Config.Upgrades[id]
		local row = Theme.frame(body, { name = id, size = UDim2.new(1, -12, 0, 76), color = Theme.White, corner = 10, order = i, z = 12 })
		Theme.label(row, { name = "Icon", text = UPGRADE_ICON[id] or "⬆", size = UDim2.new(0, 56, 0, 56), position = UDim2.new(0, 10, 0.5, 0), anchor = Vector2.new(0, 0.5), stroke = false, z = 13 })
		local name = Theme.label(row, { name = "UpgradeName", text = def.name, size = UDim2.new(0.5, 0, 0.44, 0), position = UDim2.new(0, 76, 0.08, 0), xAlign = Enum.TextXAlignment.Left, color = Theme.Ink, stroke = false, z = 13 })
		local effect = Theme.label(row, { name = "Effect", text = "", size = UDim2.new(0.55, 0, 0.34, 0), position = UDim2.new(0, 76, 0.56, 0), xAlign = Enum.TextXAlignment.Left, color = Color3.fromRGB(90, 90, 110), stroke = false, z = 13 })
		local buy = Theme.button(row, {
			name = "Buy",
			text = "$0",
			color = Theme.Green,
			size = UDim2.new(0, 130, 0, 52),
			position = UDim2.new(1, -10, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			z = 14,
			onClick = function()
				Remotes.get("RequestUpgrade"):FireServer(id)
			end,
		})
		rows[id] = { name = name, effect = effect, buy = buy }
	end
	local function refresh(snap)
		for id, r in pairs(rows) do
			local def = Config.Upgrades[id]
			local lvl = snap.upgrades[id] or def.startLevel
			r.name.Text = def.name .. "  Lv " .. lvl
			local cost = snap.costs[id]
			if not cost or cost < 0 then
				r.effect.Text = "Fully upgraded!"
				Theme.setButtonText(r.buy, "MAX")
				r.buy.BackgroundColor3 = Theme.Gray
			else
				r.effect.Text = effectText(id, snap)
				Theme.setButtonText(r.buy, Util.formatMoney(cost))
				r.buy.BackgroundColor3 = (snap.money >= cost) and Theme.Green or Color3.fromRGB(170, 170, 180)
			end
		end
	end
	State.Changed:Connect(refresh)
	if State.get() then
		refresh(State.get())
	end
	return p
end

-- Index ----------------------------------------------------------------------------
local function buildIndex(screen)
	local p, body = makePanel(screen, "IndexPanel", "📖 DISASTER INDEX", Theme.Purple)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	local progress = Theme.label(body, { name = "Progress", text = "", size = UDim2.new(1, -12, 0, 30), color = Theme.Ink, stroke = false, order = 0, z = 12 })
	local cells = {}
	local order = 1
	local zones = {}
	for _, z in ipairs(Config.Zones) do
		table.insert(zones, z)
	end
	for _, zone in ipairs(zones) do
		Theme.label(body, { name = zone.id .. "Header", text = string.upper(zone.name) .. "  •  ⚡ " .. Util.formatNumber(zone.speedReq), size = UDim2.new(1, -12, 0, 28), color = Theme.White, order = order, z = 12, xAlign = Enum.TextXAlignment.Left })
		order = order + 1
		local grid = Instance.new("Frame")
		grid.Name = zone.id .. "Grid"
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, -12, 0, 112)
		grid.LayoutOrder = order
		grid.Parent = body
		order = order + 1
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.new(0.24, -6, 0, 108)
		gl.CellPadding = UDim2.new(0, 8, 0, 8)
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		gl.Parent = grid
		for ci, coreId in ipairs(zone.cores) do
			local core = Config.Cores[coreId]
			local d = Config.Disasters[core.disaster]
			local rarity = Config.Rarities[d.rarity]
			local cell = Theme.frame(grid, { name = core.disaster, color = Color3.fromRGB(50, 46, 70), corner = 10, order = ci, z = 12 })
			local stroke = cell:FindFirstChildOfClass("UIStroke")
			stroke.Color = Theme.rgb(rarity.color)
			stroke.Thickness = 3
			local icon = Theme.label(cell, { name = "Icon", text = "❔", size = UDim2.new(1, 0, 0.5, 0), position = UDim2.new(0, 0, 0.06, 0), stroke = false, z = 13 })
			local nm = Theme.label(cell, { name = "DisasterName", text = "???", size = UDim2.new(1, -8, 0.22, 0), position = UDim2.new(0, 4, 0.56, 0), z = 13, strokeThickness = 1.5 })
			local info = Theme.label(cell, { name = "Info", text = d.rarity, size = UDim2.new(1, -8, 0.18, 0), position = UDim2.new(0, 4, 0.79, 0), color = Theme.rgb(rarity.color), z = 13, strokeThickness = 1.5 })
			cells[core.disaster] = { cell = cell, icon = icon, name = nm, info = info, def = d }
		end
	end
	-- the event-only Chaos Storm
	do
		Theme.label(body, { name = "ChaosHeader", text = "CHAOS FRENZY EXCLUSIVE", size = UDim2.new(1, -12, 0, 28), color = Theme.Frenzy, order = order, z = 12, xAlign = Enum.TextXAlignment.Left })
		order = order + 1
		local grid = Instance.new("Frame")
		grid.Name = "ChaosGrid"
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, -12, 0, 112)
		grid.LayoutOrder = order
		grid.Parent = body
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.new(0.24, -6, 0, 108)
		gl.Parent = grid
		local d = Config.Disasters.ChaosStorm
		local cell = Theme.frame(grid, { name = "ChaosStorm", color = Color3.fromRGB(70, 30, 80), corner = 10, z = 12 })
		local icon = Theme.label(cell, { name = "Icon", text = "❔", size = UDim2.new(1, 0, 0.5, 0), position = UDim2.new(0, 0, 0.06, 0), stroke = false, z = 13 })
		local nm = Theme.label(cell, { name = "DisasterName", text = "???", size = UDim2.new(1, -8, 0.22, 0), position = UDim2.new(0, 4, 0.56, 0), z = 13, strokeThickness = 1.5 })
		local info = Theme.label(cell, { name = "Info", text = "Chaos", size = UDim2.new(1, -8, 0.18, 0), position = UDim2.new(0, 4, 0.79, 0), color = Theme.Frenzy, z = 13, strokeThickness = 1.5 })
		cells.ChaosStorm = { cell = cell, icon = icon, name = nm, info = info, def = d }
	end
	local total = 0
	for _ in pairs(cells) do
		total = total + 1
	end
	local function refresh(snap)
		local found = 0
		for id, c in pairs(cells) do
			if snap.index[id] then
				found = found + 1
				c.icon.Text = ARCH_ICON[c.def.archetype] or "🌪"
				c.name.Text = c.def.name
				local inc = EconomyLogic.incomeFor({ d = id, z = 1 })
				c.info.Text = c.def.rarity .. " • " .. Util.formatMoney(inc) .. "/s"
			else
				c.icon.Text = "❔"
				c.name.Text = "???"
				c.info.Text = c.def.rarity
			end
		end
		progress.Text = "Discovered " .. found .. " / " .. total
	end
	State.Changed:Connect(refresh)
	if State.get() then
		refresh(State.get())
	end
	return p
end

function Panels.toggle(name)
	if open == name then
		Panels.close()
		return
	end
	Panels.close()
	local p = panels[name]
	if p then
		p.Visible = true
		open = name
		Theme.pop(p, 0.7)
	end
end

function Panels.openPanel(name)
	if open ~= name then
		Panels.toggle(name)
	end
end

function Panels.close()
	if open and panels[open] then
		panels[open].Visible = false
	end
	open = nil
end

function Panels.isOpen(name)
	return open == name
end

function Panels.mount(screen)
	panels.Shop = buildShop(screen)
	panels.Index = buildIndex(screen)

	-- compact left nav
	local nav = Instance.new("Frame")
	nav.Name = "LeftNav"
	nav.BackgroundTransparency = 1
	nav.Size = UDim2.new(0, 84, 0, 3 * 88)
	nav.Position = UDim2.new(0, 10, 0.5, 0)
	nav.AnchorPoint = Vector2.new(0, 0.5)
	nav.Parent = screen
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = nav
	local buttons = {}
	buttons.Shop = Theme.button(nav, { name = "ShopButton", icon = "🛒", text = "SHOP", color = Theme.Green, size = UDim2.new(0, 78, 0, 78), order = 1, onClick = function()
		Panels.toggle("Shop")
	end })
	buttons.Index = Theme.button(nav, { name = "IndexButton", icon = "📖", text = "INDEX", color = Theme.Purple, size = UDim2.new(0, 78, 0, 78), order = 2, onClick = function()
		Panels.toggle("Index")
	end })
	buttons.Lock = Theme.button(nav, { name = "LockButton", icon = "🛡", text = "LOCK", color = Theme.Blue, size = UDim2.new(0, 78, 0, 78), order = 3, onClick = function()
		Remotes.get("RequestShield"):FireServer()
	end })

	-- lock button shows the remaining shield time
	local RunService = game:GetService("RunService")
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc = acc + dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local untilT = Players.LocalPlayer:GetAttribute("ShieldUntil") or 0
		local left = untilT - workspace:GetServerTimeNow()
		if left > 0 then
			Theme.setButtonText(buttons.Lock, math.ceil(left) .. "s")
			buttons.Lock.BackgroundColor3 = Color3.fromRGB(40, 120, 220)
		else
			Theme.setButtonText(buttons.Lock, "LOCK")
			buttons.Lock.BackgroundColor3 = Theme.Blue
		end
	end)

	Remotes.get("OpenPanel").OnClientEvent:Connect(function(name)
		if type(name) == "string" and panels[name] then
			Panels.openPanel(name)
		end
	end)
	return { nav = nav, buttons = buttons, panels = panels }
end

return Panels
