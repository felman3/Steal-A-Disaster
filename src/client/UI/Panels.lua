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

local okModels, DisasterModels = pcall(function()
	return require(Shared.Models.DisasterModels)
end)

-- 3D preview of a disaster inside an index cell (built lazily)
local function makePreview(cell, disasterId)
	if not okModels then
		return nil
	end
	local ok, model = pcall(DisasterModels.build, disasterId, nil)
	if not ok or not model then
		return nil
	end
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Preview"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.new(1, -8, 0.56, 0)
	vp.Position = UDim2.new(0, 4, 0.02, 0)
	vp.Ambient = Color3.fromRGB(190, 190, 200)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-1, -1.5, 1)
	vp.ZIndex = 13
	vp.Parent = cell
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	local dist = math.max(size.X, size.Y, size.Z) * 1.7 + 2
	local center = cf.Position
	-- disasters face -Z, so look at them from the -Z side
	cam.CFrame = CFrame.lookAt(center + Vector3.new(dist * 0.35, size.Y * 0.2, -dist), center)
	cam.Parent = vp
	vp.CurrentCamera = cam
	return vp
end

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

-- shop layout: category headers and the row order inside them
local SHOP_HEADERS = {
	{ name = "SpeedHeader", text = "⚡ SPEED", color = Theme.Orange, order = 10 },
	{ name = "BaseHeader", text = "🏠 BASE & CARRY", color = Theme.Blue, order = 20 },
	{ name = "IncubatorHeader", text = "🥚 INCUBATOR", color = Theme.Purple, order = 30 },
}
local SHOP_ORDER = { Treadmill = 11, Carry = 21, Pedestals = 22, Shield = 23, Pods = 31 }

local function buildShop(screen)
	local p, body = makePanel(screen, "ShopPanel", "🛒 SHOP", Theme.Green)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	-- categories: headers sit just before their rows (LayoutOrder)
	for _, h in ipairs(SHOP_HEADERS) do
		Theme.label(body, { name = h.name, text = h.text, size = UDim2.new(1, -12, 0, 32), font = Theme.FontDisplay, color = h.color, order = h.order, z = 12, strokeThickness = 2, xAlign = Enum.TextXAlignment.Left })
	end
	local rows = {}
	for i, id in ipairs(Config.UpgradeOrder) do
		local def = Config.Upgrades[id]
		local row = Theme.frame(body, { name = id, size = UDim2.new(1, -12, 0, 76), color = Theme.White, corner = 10, order = SHOP_ORDER[id] or i, z = 12 })
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
	Panels._buildBoosts(body)
	return p
end

-- Boosts (Robux) ------------------------------------------------------------------
-- Rows below the upgrades. Prices come from Roblox (GetProductInfo); the configured
-- intendedPrice is shown only for Studio mock items. Buttons only ask the server to
-- open Roblox's purchase prompt.
function Panels._buildBoosts(body)
	local MConfig = require(Shared.Config.MonetizationConfig)
	local MarketplaceService = game:GetService("MarketplaceService")
	local RunService = game:GetService("RunService")
	Theme.label(body, { name = "BoostsHeader", text = "💎 GAME PASSES — permanent", size = UDim2.new(1, -12, 0, 32), font = Theme.FontDisplay, color = Theme.Orange, order = 100, z = 12, strokeThickness = 2, xAlign = Enum.TextXAlignment.Left })
	Theme.label(body, { name = "ProductsHeader", text = "🎁 BOOSTS — one-time", size = UDim2.new(1, -12, 0, 32), font = Theme.FontDisplay, color = Theme.Frenzy, order = 110, z = 12, strokeThickness = 2, xAlign = Enum.TextXAlignment.Left })
	local rows = {}
	for j, key in ipairs(MConfig.BoostsOrder) do
		local item = MConfig.Items[key]
		local order = (item.type == "GamePass") and (100 + j) or (110 + j)
		local row = Theme.frame(body, { name = "Boost_" .. key, size = UDim2.new(1, -12, 0, 76), color = Theme.White, corner = 10, order = order, z = 12 })
		Theme.label(row, { name = "Icon", text = item.icon, size = UDim2.new(0, 56, 0, 56), position = UDim2.new(0, 10, 0.5, 0), anchor = Vector2.new(0, 0.5), stroke = false, z = 13 })
		Theme.label(row, { name = "BoostName", text = item.name, size = UDim2.new(0.5, 0, 0.44, 0), position = UDim2.new(0, 76, 0.08, 0), xAlign = Enum.TextXAlignment.Left, color = Theme.Ink, stroke = false, z = 13 })
		local effect = Theme.label(row, { name = "Effect", text = item.benefit, size = UDim2.new(0.55, 0, 0.34, 0), position = UDim2.new(0, 76, 0.56, 0), xAlign = Enum.TextXAlignment.Left, color = Color3.fromRGB(90, 90, 110), stroke = false, z = 13 })
		local buy = Theme.button(row, {
			name = "Buy",
			text = "…",
			color = Theme.Orange,
			size = UDim2.new(0, 130, 0, 52),
			position = UDim2.new(1, -10, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			z = 14,
			onClick = function()
				Remotes.get("RequestPurchase"):FireServer(key)
			end,
		})
		rows[key] = { row = row, buy = buy, effect = effect, price = "…" }
	end
	local function refresh(snap)
		for key, r in pairs(rows) do
			local item = MConfig.Items[key]
			local owned = snap and snap.passes and snap.passes[key]
			if owned then
				Theme.setButtonText(r.buy, "OWNED ✓")
				r.buy.BackgroundColor3 = Theme.Gray
				r.buy.Active = false
			else
				Theme.setButtonText(r.buy, r.price)
				r.buy.BackgroundColor3 = Theme.Orange
				r.buy.Active = true
			end
			if key == "CashPack" and snap and snap.cashPack then
				r.effect.Text = "+" .. Util.formatMoney(snap.cashPack) .. " now (≈10 min of income)"
			elseif key == "SpeedBoost" and snap and (snap.boostSpeed or 0) > 0 then
				r.effect.Text = "Active: x" .. (snap.speedMult or 2) .. " • " .. Util.formatTime(snap.boostSpeed) .. " left (buy to add 15 min)"
			elseif key == "InstantHatch" and snap and (snap.hatchCredits or 0) > 0 then
				r.effect.Text = snap.hatchCredits .. " free hatch(es) saved — use on a pod"
			elseif item.type == "GamePass" and snap and owned then
				r.effect.Text = item.benefit .. " — active"
			end
		end
	end
	State.Changed:Connect(refresh)
	task.spawn(function()
		for key, r in pairs(rows) do
			local item = MConfig.Items[key]
			if item.id > 0 then
				local ok, info = pcall(function()
					local infoType = (item.type == "GamePass") and Enum.InfoType.GamePass or Enum.InfoType.Product
					return MarketplaceService:GetProductInfo(item.id, infoType)
				end)
				if ok and type(info) == "table" and info.PriceInRobux then
					r.price = "R$ " .. tostring(info.PriceInRobux)
				else
					r.price = "BUY" -- Roblox's own dialog shows the real price
				end
			elseif MConfig.MockInStudio and RunService:IsStudio() then
				r.price = "R$ " .. item.intendedPrice .. " (test)"
			else
				r.row.Visible = false -- not created on Roblox yet: never sell it
			end
		end
		refresh(State.get())
	end)
	refresh(State.get())
end

-- Index ----------------------------------------------------------------------------
local function buildIndex(screen)
	local p, body = makePanel(screen, "IndexPanel", "📖 DISASTER INDEX", Theme.Purple)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	local progress = Theme.label(body, { name = "Progress", text = "", size = UDim2.new(1, -12, 0, 26), color = Theme.Ink, stroke = false, order = -3, z = 12 })
	local barBg = Theme.frame(body, { name = "ProgressBar", size = UDim2.new(1, -12, 0, 12), color = Color3.fromRGB(60, 56, 80), corner = 6, order = -2, z = 12 })
	local bar = Theme.frame(barBg, { name = "Fill", size = UDim2.new(0, 0, 1, 0), color = Theme.Purple, corner = 6, z = 13 })
	-- toolbar: search, rarity chips, owned-only toggle, sort
	local tools = Instance.new("Frame")
	tools.Name = "Toolbar"
	tools.BackgroundTransparency = 1
	tools.Size = UDim2.new(1, -12, 0, 84)
	tools.LayoutOrder = -1
	tools.Parent = body
	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.PlaceholderText = "🔍 Search discovered disasters"
	search.Text = ""
	search.ClearTextOnFocus = false
	search.Font = Theme.FontBold
	search.TextScaled = true
	search.TextColor3 = Theme.Ink
	search.PlaceholderColor3 = Color3.fromRGB(130, 128, 150)
	search.BackgroundColor3 = Theme.White
	search.Size = UDim2.new(1, -250, 0, 36)
	search.ZIndex = 13
	search.Parent = tools
	Theme.corner(search, 8)
	Theme.outline(search, 2)
	local filter = { rarity = nil, owned = false, sort = 1, text = "" }
	local SORTS = { "ZONE", "RARITY", "INCOME" }
	local applyFilters
	local ownedBtn = Theme.button(tools, { name = "OwnedOnly", text = "SHOW: ALL", color = Theme.Blue, size = UDim2.new(0, 116, 0, 36), position = UDim2.new(1, -124, 0, 0), z = 13, onClick = function(b)
		filter.owned = not filter.owned
		Theme.setButtonText(b, filter.owned and "SHOW: OWNED" or "SHOW: ALL")
		applyFilters()
	end })
	local sortBtn = Theme.button(tools, { name = "Sort", text = "SORT: ZONE", color = Theme.Orange, size = UDim2.new(0, 116, 0, 36), position = UDim2.new(1, -244, 0, 0), z = 13, onClick = function(b)
		filter.sort = filter.sort % #SORTS + 1
		Theme.setButtonText(b, "SORT: " .. SORTS[filter.sort])
		applyFilters()
	end })
	local chips = {}
	local CHIP_LIST = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Chaos" }
	for ci, r in ipairs(CHIP_LIST) do
		local col = (r == "All") and Theme.Ink or Theme.rgb(Config.Rarities[r].color)
		chips[r] = Theme.button(tools, { name = "Chip_" .. r, text = (r == "All") and "ALL" or string.upper(string.sub(r, 1, 4)), color = col, size = UDim2.new(1 / #CHIP_LIST, -6, 0, 34), position = UDim2.new((ci - 1) / #CHIP_LIST, 3, 0, 46), z = 13, onClick = function()
			filter.rarity = (r ~= "All") and r or nil
			for name, b in pairs(chips) do
				b.BackgroundTransparency = ((filter.rarity or "All") == name) and 0 or 0.55
			end
			applyFilters()
		end })
		chips[r].BackgroundTransparency = (r == "All") and 0 or 0.55
	end
	search:GetPropertyChangedSignal("Text"):Connect(function()
		filter.text = string.lower(search.Text)
		applyFilters()
	end)
	local groups = {}
	local cells = {}
	local order = 1
	local zones = {}
	for _, z in ipairs(Config.Zones) do
		table.insert(zones, z)
	end
	for _, zone in ipairs(zones) do
		local header = Theme.label(body, { name = zone.id .. "Header", text = string.upper(zone.name) .. "  •  ⚡ " .. Util.formatNumber(zone.speedReq), size = UDim2.new(1, -12, 0, 28), color = Theme.White, order = order, z = 12, xAlign = Enum.TextXAlignment.Left })
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
		local group = { header = header, grid = grid, ids = {} }
		table.insert(groups, group)
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
			cells[core.disaster] = { cell = cell, icon = icon, name = nm, info = info, def = d, base = ci }
			table.insert(group.ids, core.disaster)
		end
	end
	-- the event-only Chaos Storm
	do
		local header = Theme.label(body, { name = "ChaosHeader", text = "CHAOS FRENZY EXCLUSIVE", size = UDim2.new(1, -12, 0, 28), color = Theme.Frenzy, order = order, z = 12, xAlign = Enum.TextXAlignment.Left })
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
		cells.ChaosStorm = { cell = cell, icon = icon, name = nm, info = info, def = d, base = 1 }
		table.insert(groups, { header = header, grid = grid, ids = { "ChaosStorm" } })
	end
	-- owned-count badge on every cell (from the server snapshot)
	for _, c in pairs(cells) do
		c.badge = Theme.label(c.cell, { name = "Owned", text = "", size = UDim2.new(0.5, 0, 0.18, 0), position = UDim2.new(0.5, -4, 0, 4), xAlign = Enum.TextXAlignment.Right, color = Theme.Money, z = 14, strokeThickness = 1.5 })
	end
	local lastSnap = nil
	applyFilters = function()
		local snap = lastSnap
		if not snap then
			return
		end
		local owned = {}
		for _, e in ipairs(snap.disasters or {}) do
			owned[e.d] = (owned[e.d] or 0) + 1
		end
		for _, g in ipairs(groups) do
			local any = false
			for _, id in ipairs(g.ids) do
				local c = cells[id]
				local known = snap.index[id] == true
				local show = true
				if filter.rarity and c.def.rarity ~= filter.rarity then
					show = false
				end
				if filter.owned and not owned[id] then
					show = false
				end
				-- search only matches discovered names, so it never reveals secrets
				if filter.text ~= "" and (not known or not string.find(string.lower(c.def.name), filter.text, 1, true)) then
					show = false
				end
				c.cell.Visible = show
				any = any or show
				c.badge.Text = owned[id] and ("×" .. owned[id]) or ""
				if filter.sort == 2 then
					c.cell.LayoutOrder = Config.Rarities[c.def.rarity].rank * 10 + c.base
				elseif filter.sort == 3 then
					c.cell.LayoutOrder = -math.floor(EconomyLogic.incomeFor({ d = id, z = 1 }) * 10)
				else
					c.cell.LayoutOrder = c.base
				end
			end
			g.header.Visible = any
			g.grid.Visible = any
		end
	end
	local total = 0
	for _ in pairs(cells) do
		total = total + 1
	end
	local function refresh(snap)
		local found = 0
		for id, c in pairs(cells) do
			if p.Visible and not c.preview then
				c.preview = makePreview(c.cell, id) or false
			end
			if c.preview then
				local known = snap.index[id] == true
				c.preview.ImageColor3 = known and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
				c.preview.ImageTransparency = known and 0 or 0.25
				c.icon.Visible = false
			end
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
		progress.Text = "Discovered " .. found .. " / " .. total .. "  (" .. math.floor(found / total * 100 + 0.5) .. "%)"
		bar.Size = UDim2.new(found / total, 0, 1, 0)
		lastSnap = snap
		applyFilters()
	end
	State.Changed:Connect(refresh)
	if State.get() then
		refresh(State.get())
	end
	-- previews are built the first time the panel is opened
	p:GetPropertyChangedSignal("Visible"):Connect(function()
		if p.Visible and State.get() then
			refresh(State.get())
		end
	end)
	return p
end

-- Zones --------------------------------------------------------------------------
-- One row per zone, built from GameConfig. Travel buttons only ask the server;
-- TravelService re-checks the Speed requirement.
local RARITY_SHORT = { Common = "C", Uncommon = "U", Rare = "R", Epic = "E", Legendary = "L", Mythic = "M" }

local function rarityText(zone)
	local parts = {}
	for _, r in ipairs(Config.RarityOrder) do
		if zone.rarityWeights[r] and zone.rarityWeights[r] > 0 then
			table.insert(parts, r)
		end
	end
	-- e.g. "Common → Epic" keeps the row short
	if #parts > 2 then
		return parts[1] .. " → " .. parts[#parts] .. " cores"
	end
	return table.concat(parts, ", ") .. " cores"
end

local function buildZones(screen)
	local p, body = makePanel(screen, "ZonesPanel", "🗺 ZONES", Theme.Purple)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	local rows = {}
	for i, zone in ipairs(Config.Zones) do
		local row = Theme.frame(body, { name = "Zone" .. i, size = UDim2.new(1, -12, 0, 78), color = Theme.White, corner = 10, order = i, z = 12 })
		local swatch = Theme.frame(row, { name = "Swatch", size = UDim2.new(0, 58, 0, 58), position = UDim2.new(0, 10, 0.5, 0), anchor = Vector2.new(0, 0.5), color = Theme.rgb(zone.sky.fog), corner = 10, z = 13 })
		Theme.label(swatch, { name = "Num", text = tostring(i), size = UDim2.new(1, 0, 1, 0), font = Theme.FontDisplay, z = 14, strokeThickness = 2.5 })
		local name = Theme.label(row, { name = "ZoneName", text = zone.name, size = UDim2.new(1, -214, 0.4, 0), position = UDim2.new(0, 78, 0.06, 0), xAlign = Enum.TextXAlignment.Left, color = Theme.Ink, stroke = false, font = Theme.FontDisplay, z = 13 })
		local req = zone.speedReq > 0 and ("⚡ " .. Util.formatNumber(zone.speedReq) .. " Speed") or "⚡ No Speed needed"
		local info = Theme.label(row, { name = "Info", text = req .. "  •  " .. rarityText(zone), size = UDim2.new(1, -214, 0.28, 0), position = UDim2.new(0, 78, 0.46, 0), xAlign = Enum.TextXAlignment.Left, color = Color3.fromRGB(90, 90, 110), stroke = false, z = 13 })
		local status = Theme.label(row, { name = "Status", text = "", size = UDim2.new(1, -214, 0.24, 0), position = UDim2.new(0, 78, 0.72, 0), xAlign = Enum.TextXAlignment.Left, color = Theme.Green, stroke = false, z = 13 })
		local travel = Theme.button(row, {
			name = "Travel",
			text = "TRAVEL",
			color = Theme.Purple,
			size = UDim2.new(0, 116, 0, 50),
			position = UDim2.new(1, -10, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			z = 14,
			onClick = function(b)
				if b.Active then
					Remotes.get("RequestTravel"):FireServer("Zone", i)
					Panels.close()
				end
			end,
		})
		rows[i] = { row = row, name = name, info = info, status = status, travel = travel, swatch = swatch }
	end
	local function refresh(snap)
		local speed = snap and snap.speed or 0
		local highest = SpeedLogic.highestUnlockedZone(speed)
		local carrying = snap and snap.carried and #snap.carried > 0
		for i, r in ipairs(rows) do
			local zone = Config.Zones[i]
			local unlocked = speed >= zone.speedReq
			r.row.BackgroundColor3 = unlocked and Theme.White or Color3.fromRGB(225, 222, 230)
			r.swatch.BackgroundTransparency = unlocked and 0 or 0.55
			if i == highest then
				r.status.Text = "★ YOUR BEST ZONE"
				r.status.TextColor3 = Theme.Orange
			elseif unlocked then
				r.status.Text = "✓ Unlocked"
				r.status.TextColor3 = Theme.Green
			else
				r.status.Text = "🔒 Need " .. Util.formatNumber(zone.speedReq - speed) .. " more Speed — train!"
				r.status.TextColor3 = Theme.Danger
			end
			local canGo = unlocked and not carrying
			r.travel.Active = canGo
			r.travel.AutoButtonColor = false
			r.travel.BackgroundColor3 = canGo and Theme.Purple or Theme.Gray
			Theme.setButtonText(r.travel, unlocked and (carrying and "CARRYING" or "TRAVEL") or "LOCKED")
		end
	end
	State.Changed:Connect(refresh)
	refresh(State.get())
	return p
end

-- Stats ------------------------------------------------------------------------------
-- Everything comes from the server snapshot; nothing here is computed from client state.
local function buildStats(screen)
	local p, body = makePanel(screen, "StatsPanel", "📊 STATS", Theme.Blue)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	local order = 0
	local values = {}
	local function section(text, color)
		order = order + 1
		Theme.label(body, { name = "S" .. order, text = text, size = UDim2.new(1, -12, 0, 30), font = Theme.FontDisplay, color = color, order = order, z = 12, strokeThickness = 2, xAlign = Enum.TextXAlignment.Left })
	end
	local function row(key, title)
		order = order + 1
		local r = Theme.frame(body, { name = key, size = UDim2.new(1, -12, 0, 34), color = Theme.White, corner = 8, order = order, z = 12 })
		Theme.label(r, { name = "Title", text = title, size = UDim2.new(0.5, -10, 1, -8), position = UDim2.new(0, 10, 0, 4), xAlign = Enum.TextXAlignment.Left, color = Color3.fromRGB(90, 90, 110), stroke = false, z = 13 })
		values[key] = Theme.label(r, { name = "Value", text = "—", size = UDim2.new(0.5, -10, 1, -8), position = UDim2.new(0.5, 0, 0, 4), xAlign = Enum.TextXAlignment.Right, color = Theme.Ink, stroke = false, z = 13 })
	end
	section("⚡ PROGRESS", Theme.Orange)
	row("Speed", "Speed")
	row("Walk", "Walk speed")
	row("Zone", "Best zone")
	row("Next", "Next zone")
	section("💰 INCOME", Theme.Green)
	row("Money", "Money")
	row("Income", "Income")
	section("🏠 BASE", Theme.Blue)
	row("Disasters", "Disasters on display")
	row("Collection", "Collection")
	row("Pods", "Incubating")
	row("Upgrades", "Upgrade levels")
	section("🎁 BOOSTS", Theme.Frenzy)
	row("Passes", "Game Passes")
	row("Boost", "Speed Boost")
	row("Hatches", "Saved Instant Hatches")
	section("🏆 CAREER", Theme.Purple)
	row("Hatched", "Disasters hatched")
	row("Stolen", "Cores stolen")
	row("Robbed", "Stolen from players")

	local totalDisasters = 0
	for _ in pairs(Config.Disasters) do
		totalDisasters = totalDisasters + 1
	end
	local function refresh(snap)
		if not snap then
			return
		end
		local zi = SpeedLogic.highestUnlockedZone(snap.speed or 0)
		values.Speed.Text = "⚡ " .. Util.formatNumber(snap.speed or 0) .. ((snap.speedMult or 1) > 1 and ("  (x" .. snap.speedMult .. " training)") or "")
		values.Walk.Text = string.format("%.1f", snap.walk or 16)
		values.Zone.Text = zi .. ". " .. Config.Zones[zi].name
		if snap.nextZone ~= "" and Config.ZoneById[snap.nextZone] then
			local left = (snap.nextZoneReq or 0) - (snap.speed or 0)
			values.Next.Text = Config.ZoneById[snap.nextZone].name .. " — " .. Util.formatNumber(math.max(0, left)) .. " more"
		else
			values.Next.Text = "All zones unlocked!"
		end
		values.Money.Text = Util.formatMoney(snap.money or 0)
		values.Income.Text = Util.formatMoney(snap.income or 0) .. "/s" .. ((snap.incomeMult or 1) > 1 and ("  (x" .. snap.incomeMult .. ")") or "")
		values.Disasters.Text = #(snap.disasters or {}) .. " / " .. ((snap.upgrades and snap.upgrades.Pedestals) or 0)
		local found = 0
		for _ in pairs(snap.index or {}) do
			found = found + 1
		end
		values.Collection.Text = found .. " / " .. totalDisasters .. "  (" .. math.floor(found / totalDisasters * 100 + 0.5) .. "%)"
		values.Pods.Text = (snap.podsUsed or 0) .. " / " .. ((snap.upgrades and snap.upgrades.Pods) or 0) .. ((snap.storage or 0) > 0 and ("  (+" .. snap.storage .. " waiting)") or "")
		local u = snap.upgrades or {}
		values.Upgrades.Text = "Tread " .. (u.Treadmill or 1) .. " • Pack " .. (u.Carry or 1) .. " • Shield " .. (u.Shield or 1)
		local passes = {}
		for key, owned in pairs(snap.passes or {}) do
			if owned then
				table.insert(passes, key == "TurboTreadmill" and "Turbo" or (key == "DoubleCash" and "2x Cash" or key))
			end
		end
		table.sort(passes)
		values.Passes.Text = (#passes > 0) and table.concat(passes, ", ") or "None"
		values.Boost.Text = ((snap.boostSpeed or 0) > 0) and (Util.formatTime(snap.boostSpeed) .. " left") or "Off"
		values.Hatches.Text = tostring(snap.hatchCredits or 0)
		local st = snap.stats or {}
		values.Hatched.Text = tostring(st.hatched or 0)
		values.Stolen.Text = tostring(st.stolen or 0)
		values.Robbed.Text = tostring(st.robbed or 0)
	end
	State.Changed:Connect(refresh)
	refresh(State.get())
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
	panels.Zones = buildZones(screen)
	panels.Stats = buildStats(screen)

	-- compact left nav
	local nav = Instance.new("Frame")
	nav.Name = "LeftNav"
	nav.BackgroundTransparency = 1
	nav.Size = UDim2.new(0, 84, 0, 4 * 88)
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
	buttons.Stats = Theme.button(nav, { name = "StatsButton", icon = "📊", text = "STATS", color = Theme.Orange, size = UDim2.new(0, 78, 0, 78), order = 4, onClick = function()
		Panels.toggle("Stats")
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
