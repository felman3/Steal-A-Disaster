--[[
	Announcer — big center banners (zone entry, run home, delivered, hatches,
	events, breaches) and small toasts for notifications.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Announcer = {}

local queue = {}
local showing = false
local banner, title, subtitle
local toastHolder

local PRIORITY = { alarm = 3, frenzy = 3, warning = 2, hatch = 2, unlock = 2, delivered = 2, carry = 1, zone = 0, info = 0 }

local function showNext()
	if showing or #queue == 0 then
		return
	end
	showing = true
	local item = table.remove(queue, 1)
	title.Text = item.title or ""
	subtitle.Text = item.subtitle or ""
	local col = item.color and Theme.rgb(item.color) or Theme.White
	title.TextColor3 = col
	banner.Visible = true
	title.TextTransparency = 0
	subtitle.TextTransparency = 0
	Theme.pop(banner, 0.5)
	local hold = item.hold or 2.4
	task.delay(hold, function()
		local t1 = TweenService:Create(title, TweenInfo.new(0.3), { TextTransparency = 1 })
		local t2 = TweenService:Create(subtitle, TweenInfo.new(0.3), { TextTransparency = 1 })
		t1:Play()
		t2:Play()
		task.wait(0.32)
		banner.Visible = false
		showing = false
		showNext()
	end)
end

function Announcer.announce(item)
	if type(item) ~= "table" then
		return
	end
	local p = PRIORITY[item.kind or "info"] or 0
	-- high-priority banners jump the queue; zone banners don't pile up
	if item.kind == "zone" then
		for i = #queue, 1, -1 do
			if queue[i].kind == "zone" then
				table.remove(queue, i)
			end
		end
	end
	if p >= 2 then
		table.insert(queue, 1, item)
	else
		table.insert(queue, item)
	end
	while #queue > 4 do
		table.remove(queue)
	end
	showNext()
end

local TOAST_COLORS = {
	error = Color3.fromRGB(230, 60, 70),
	success = Color3.fromRGB(60, 190, 90),
	info = Color3.fromRGB(70, 110, 220),
}

function Announcer.toast(text, kind)
	if type(text) ~= "string" or text == "" then
		return
	end
	local t = Theme.frame(toastHolder, { name = "Toast", size = UDim2.new(1, 0, 0, 40), color = TOAST_COLORS[kind] or TOAST_COLORS.info, corner = 10, z = 20 })
	Theme.label(t, { name = "Text", text = text, size = UDim2.new(1, -16, 1, -8), position = UDim2.new(0, 8, 0, 4), z = 21, strokeThickness = 2 })
	Theme.pop(t, 0.8)
	local items = toastHolder:GetChildren()
	local count = 0
	for _, c in ipairs(items) do
		if c:IsA("Frame") then
			count = count + 1
		end
	end
	if count > 3 then
		for _, c in ipairs(items) do
			if c:IsA("Frame") and c ~= t then
				c:Destroy()
				break
			end
		end
	end
	task.delay(3.2, function()
		if t.Parent then
			t:Destroy()
		end
	end)
end

function Announcer.mount(screen)
	banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.BackgroundTransparency = 1
	banner.Size = UDim2.new(0.9, 0, 0, 130)
	banner.Position = UDim2.new(0.5, 0, 0.2, 0)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Visible = false
	banner.Parent = screen
	local maxW = Instance.new("UISizeConstraint")
	maxW.MaxSize = Vector2.new(820, 130)
	maxW.Parent = banner
	title = Theme.label(banner, { name = "Title", text = "", size = UDim2.new(1, 0, 0.62, 0), font = Theme.FontDisplay, strokeThickness = 4.5, z = 30 })
	subtitle = Theme.label(banner, { name = "Subtitle", text = "", size = UDim2.new(1, 0, 0.32, 0), position = UDim2.new(0, 0, 0.64, 0), strokeThickness = 2.5, z = 30 })

	toastHolder = Instance.new("Frame")
	toastHolder.Name = "Toasts"
	toastHolder.BackgroundTransparency = 1
	toastHolder.Size = UDim2.new(0, 420, 0, 180)
	toastHolder.Position = UDim2.new(0.5, 0, 1, -190)
	toastHolder.AnchorPoint = Vector2.new(0.5, 1)
	toastHolder.Parent = screen
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = toastHolder

	Remotes.get("Announce").OnClientEvent:Connect(function(payload)
		Announcer.announce(payload)
	end)
	Remotes.get("Notify").OnClientEvent:Connect(function(text, kind)
		Announcer.toast(text, kind)
	end)

	-- zone entry banners
	local player = Players.LocalPlayer
	local lastZone = 0
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		local z = player:GetAttribute("Zone") or 0
		if z == lastZone then
			return
		end
		local prev = lastZone
		lastZone = z
		if z >= 1 then
			local zone = Config.Zones[z]
			local snap = State.get()
			local speed = snap and snap.speed or 0
			local sub = zone.tagline
			if zone.speedReq > speed then
				sub = "🔒 Need ⚡" .. Util.formatNumber(zone.speedReq) .. " Speed to steal here"
			elseif zone.speedReq > 0 then
				sub = zone.tagline .. "  •  ✅ You can steal here"
			end
			Announcer.announce({ kind = "zone", title = string.upper(zone.name), subtitle = sub, color = { 255, 255, 255 }, hold = 2 })
		elseif z == 0 and prev >= 1 then
			Announcer.announce({ kind = "zone", title = "SAFE ZONE", subtitle = "Home sweet storm shelter", color = { 140, 230, 255 }, hold = 1.6 })
		end
	end)
	return { banner = banner, toasts = toastHolder }
end

return Announcer
