--[[
	Hud — minimal always-on HUD.

	top-center    money + income/s
	top-right     event pill (time to Chaos Frenzy / frenzy countdown)
	bottom-center speed + progress to the next zone, or the RUN HOME objective
	              with distance while carrying
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local Util = require(Shared.Util)
local WorldLayout = require(Shared.Logic.WorldLayout)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Hud = {}

function Hud.mount(screen)
	local player = Players.LocalPlayer

	-- money ----------------------------------------------------------------
	local moneyBox = Instance.new("Frame")
	moneyBox.Name = "Money"
	moneyBox.BackgroundTransparency = 1
	moneyBox.Size = UDim2.new(0, 360, 0, 86)
	moneyBox.Position = UDim2.new(0.5, 0, 0, 6)
	moneyBox.AnchorPoint = Vector2.new(0.5, 0)
	moneyBox.Parent = screen
	local money = Theme.label(moneyBox, { name = "Amount", text = "$0", size = UDim2.new(1, 0, 0.66, 0), color = Theme.Money, font = Theme.FontDisplay, strokeThickness = 3.5 })
	local income = Theme.label(moneyBox, { name = "Income", text = "+$0/s", size = UDim2.new(1, 0, 0.32, 0), position = UDim2.new(0, 0, 0.66, 0), color = Theme.White, strokeThickness = 2.5 })

	-- event pill -------------------------------------------------------------
	local pill = Theme.frame(screen, { name = "EventPill", size = UDim2.new(0, 230, 0, 46), position = UDim2.new(1, -12, 0, 10), anchor = Vector2.new(1, 0), color = Color3.fromRGB(60, 40, 90), corner = 12 })
	local pillText = Theme.label(pill, { name = "Text", text = "🌪 FRENZY IN 5:00", size = UDim2.new(1, -16, 1, -10), position = UDim2.new(0, 8, 0, 5) })

	-- speed bar ------------------------------------------------------------------
	local speedBox = Instance.new("Frame")
	speedBox.Name = "SpeedBox"
	speedBox.BackgroundTransparency = 1
	speedBox.Size = UDim2.new(0, 380, 0, 74)
	speedBox.Position = UDim2.new(0.5, 0, 1, -10)
	speedBox.AnchorPoint = Vector2.new(0.5, 1)
	speedBox.Parent = screen
	local speedText = Theme.label(speedBox, { name = "Speed", text = "⚡ 0 SPEED", size = UDim2.new(1, 0, 0.5, 0), color = Theme.Speed, font = Theme.FontDisplay, strokeThickness = 3 })
	local barBg = Theme.frame(speedBox, { name = "BarBg", size = UDim2.new(1, 0, 0, 22), position = UDim2.new(0, 0, 0.56, 0), color = Color3.fromRGB(40, 36, 56), corner = 11 })
	local bar = Theme.frame(barBg, { name = "Bar", size = UDim2.new(0, 0, 1, 0), color = Theme.Speed, corner = 11, outline = false })
	local barText = Theme.label(barBg, { name = "Next", text = "", size = UDim2.new(1, -10, 1, -4), position = UDim2.new(0, 5, 0, 2), z = 4, strokeThickness = 2 })

	-- carry objective (replaces the speed bar while carrying) ---------------------
	local carry = Theme.frame(screen, { name = "CarryBanner", size = UDim2.new(0, 420, 0, 80), position = UDim2.new(0.5, 0, 1, -94), anchor = Vector2.new(0.5, 1), color = Theme.Orange, corner = 14, visible = false })
	local carryTitle = Theme.label(carry, { name = "Title", text = "🏠 RUN HOME!", size = UDim2.new(1, -16, 0.58, 0), position = UDim2.new(0, 8, 0.04, 0), font = Theme.FontDisplay, strokeThickness = 3 })
	local carrySub = Theme.label(carry, { name = "Sub", text = "", size = UDim2.new(1, -16, 0.34, 0), position = UDim2.new(0, 8, 0.6, 0), strokeThickness = 2 })

	local function refresh(snap)
		money.Text = Util.formatMoney(snap.money)
		income.Text = "+" .. Util.formatMoney(snap.income) .. "/s"
		speedText.Text = "⚡ " .. Util.formatNumber(snap.speed) .. " SPEED"
		if snap.nextZone ~= "" then
			local zone = Config.ZoneById[snap.nextZone]
			local prevReq = 0
			if zone.index > 1 then
				prevReq = Config.Zones[zone.index - 1].speedReq
			end
			local frac = math.clamp((snap.speed - prevReq) / math.max(1, zone.speedReq - prevReq), 0, 1)
			bar.Size = UDim2.new(frac, 0, 1, 0)
			barText.Text = "NEXT: " .. string.upper(zone.name) .. "  " .. Util.formatNumber(snap.speed) .. " / " .. Util.formatNumber(zone.speedReq)
		else
			bar.Size = UDim2.new(1, 0, 1, 0)
			barText.Text = "ALL ZONES UNLOCKED!"
		end
		local carrying = #snap.carried > 0
		carry.Visible = carrying
		if carrying then
			local names = {}
			for _, c in ipairs(snap.carried) do
				local def = Config.Cores[c.c]
				table.insert(names, def and def.name or "Core")
			end
			carryTitle.Text = "🏠 RUN HOME!"
			carrySub.Text = table.concat(names, " + ")
			Theme.pop(carry, 0.85)
		end
	end
	State.Changed:Connect(refresh)
	if State.get() then
		refresh(State.get())
	end

	-- timers & distance -------------------------------------------------------------
	local acc = 0
	local flash = 0
	RunService.RenderStepped:Connect(function(dt)
		acc = acc + dt
		flash = flash + dt
		if acc < 0.15 then
			return
		end
		acc = 0
		local phase = ReplicatedStorage:GetAttribute("EventPhase") or "Normal"
		local now = workspace:GetServerTimeNow()
		if phase == "Frenzy" then
			local left = math.max(0, (ReplicatedStorage:GetAttribute("FrenzyEndsAt") or now) - now)
			pillText.Text = "⚡ CHAOS FRENZY " .. Util.formatTime(left)
			pill.BackgroundColor3 = (math.floor(flash * 4) % 2 == 0) and Theme.Frenzy or Color3.fromRGB(150, 30, 140)
		else
			local left = math.max(0, (ReplicatedStorage:GetAttribute("NextRefreshAt") or now) - now)
			pillText.Text = "🌪 FRENZY IN " .. Util.formatTime(left)
			pill.BackgroundColor3 = (phase == "Warning") and Color3.fromRGB(200, 40, 160) or Color3.fromRGB(60, 40, 90)
		end
		local snap = State.get()
		if snap and #snap.carried > 0 and snap.baseSlot > 0 then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local s = Config.Bases.Slots[snap.baseSlot]
				local d = (Vector3.new(s.x, 0, s.z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude
				carryTitle.Text = "🏠 RUN HOME!  " .. math.floor(d) .. "m"
				carry.BackgroundColor3 = (math.floor(flash * 3) % 2 == 0) and Theme.Orange or Color3.fromRGB(255, 110, 40)
			end
		end
	end)
	return { money = money, income = income, pill = pillText, speed = speedText, carry = carry }
end

return Hud
