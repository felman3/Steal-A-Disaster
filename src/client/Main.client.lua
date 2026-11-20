--[[
	Client bootstrap: HUD, panels, announcer, world presentation.
	The client only renders state and sends intents; all logic is on the server.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Client = script.Parent
local State = require(Client:WaitForChild("State"))
local Hud = require(Client:WaitForChild("UI"):WaitForChild("Hud"))
local Panels = require(Client.UI:WaitForChild("Panels"))
local Announcer = require(Client.UI:WaitForChild("Announcer"))
local WorldFx = require(Client:WaitForChild("World"):WaitForChild("WorldFx"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local screen = Instance.new("ScreenGui")
screen.Name = "StealADisasterHud"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

-- scale the whole HUD for small (mobile) and large screens
local uiScale = Instance.new("UIScale")
uiScale.Parent = screen
local function rescale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local s = math.clamp(math.min(vp.X / 1280, vp.Y / 760), 0.55, 1.2)
	if UserInputService.TouchEnabled and vp.Y < 500 then
		s = math.max(0.55, s * 0.9)
	end
	uiScale.Scale = s
end
rescale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end

Remotes.get("Sync").OnClientEvent:Connect(function(snapshot)
	State.set(snapshot)
end)

Hud.mount(screen)
Panels.mount(screen)
Announcer.mount(screen)
WorldFx.mount()

-- hub kiosks open panels locally (ProximityPrompt.Triggered also fires on the client)
local function hookKiosk(prompt)
	local panel = prompt:GetAttribute("Panel")
	if panel then
		prompt.Triggered:Connect(function()
			Panels.openPanel(panel)
		end)
	end
end
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("ProximityPrompt") then
		hookKiosk(d)
	end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		task.defer(hookKiosk, d)
	end
end)

-- keyboard shortcuts
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q then
		Panels.toggle("Shop")
	elseif input.KeyCode == Enum.KeyCode.B then
		Panels.toggle("Index")
	end
end)

_G.StealADisasterClient = { State = State, Panels = Panels, Screen = screen }
