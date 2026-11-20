--[[
	QuickTravel — the right-hand shortcut column: HOME, STEAL, SHOP, TRAIN, ZONES.

	HOME / STEAL / TRAIN send a RequestTravel intent; the server validates the
	destination, cooldown and carrying state (see TravelService). SHOP and ZONES
	open panels. Travel buttons grey out while you carry a core and count down
	during the cooldown. On small touch screens the column starts collapsed behind
	a TRAVEL toggle so it never covers the jump button.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local SpeedLogic = require(Shared.Logic.SpeedLogic)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local QuickTravel = {}

local BUTTONS = {
	{ key = "Home", icon = "🏠", text = "HOME", color = Theme.Blue, travel = true },
	{ key = "Steal", icon = "🎯", text = "STEAL", color = Theme.Danger, travel = true },
	{ key = "Shop", icon = "🛒", text = "SHOP", color = Theme.Green },
	{ key = "Train", icon = "🏃", text = "TRAIN", color = Theme.Orange, travel = true },
	{ key = "Zones", icon = "🗺", text = "ZONES", color = Theme.Purple },
}
local SIZE = 66
local GAP = 8

function QuickTravel.mount(screen, Panels)
	local player = Players.LocalPlayer
	local col = Instance.new("Frame")
	col.Name = "QuickTravel"
	col.BackgroundTransparency = 1
	col.Size = UDim2.new(0, SIZE + 6, 0, 30 + GAP + #BUTTONS * (SIZE + GAP))
	col.Position = UDim2.new(1, -10, 0.5, 0)
	col.AnchorPoint = Vector2.new(1, 0.5)
	col.Parent = screen
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, GAP)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.Parent = col

	local buttons = {}
	local expanded = true
	local function setExpanded(on)
		expanded = on
		for _, b in pairs(buttons) do
			b.Visible = on
		end
	end
	local toggle = Theme.button(col, {
		name = "Toggle",
		text = "✈ TRAVEL",
		color = Theme.Ink,
		size = UDim2.new(0, SIZE + 6, 0, 30),
		order = 0,
		onClick = function()
			setExpanded(not expanded)
		end,
	})

	for i, def in ipairs(BUTTONS) do
		buttons[def.key] = Theme.button(col, {
			name = def.key .. "Button",
			icon = def.icon,
			text = def.text,
			color = def.color,
			size = UDim2.new(0, SIZE, 0, SIZE),
			order = i,
			onClick = function(b)
				if def.travel then
					if b.Active then
						Remotes.get("RequestTravel"):FireServer(def.key)
					end
				else
					Panels.toggle(def.key)
				end
			end,
		})
	end

	-- start collapsed on small touch screens (phones)
	local cam = workspace.CurrentCamera
	if UserInputService.TouchEnabled and cam and cam.ViewportSize.Y < 500 then
		setExpanded(false)
	end

	-- after a trip, put the camera behind the character so you arrive facing forward
	player:GetAttributeChangedSignal("TravelReadyAt"):Connect(function()
		task.wait()
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		if hrp and camera then
			local eye = (hrp.CFrame * CFrame.new(0, 6, 14)).Position
			camera.CFrame = CFrame.lookAt(eye, hrp.Position + Vector3.new(0, 2, 0))
		end
	end)

	-- live state: carrying, cooldown, steal target
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc = acc + dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local carrying = (player:GetAttribute("Carrying") or 0) > 0
		local left = (player:GetAttribute("TravelReadyAt") or 0) - workspace:GetServerTimeNow()
		local snap = State.get()
		for _, def in ipairs(BUTTONS) do
			if def.travel then
				local b = buttons[def.key]
				local ok = not carrying and left <= 0
				b.Active = ok
				b.BackgroundColor3 = ok and def.color or Theme.Gray
				if carrying then
					Theme.setButtonText(b, "CARRY")
				elseif left > 0 then
					Theme.setButtonText(b, math.ceil(left) .. "s")
				elseif def.key == "Steal" and snap then
					-- show which zone STEAL goes to, e.g. "Z3"
					Theme.setButtonText(b, "STEAL " .. SpeedLogic.highestUnlockedZone(snap.speed or 0))
				else
					Theme.setButtonText(b, def.text)
				end
			end
		end
	end)

	return { frame = col, buttons = buttons, toggle = toggle, setExpanded = setExpanded, zones = #Config.Zones }
end

return QuickTravel
