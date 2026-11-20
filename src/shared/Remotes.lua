--[[
	Remotes — the complete list of network endpoints. The server creates them,
	clients wait for them. Clients only ever send *intents*; every effect is
	validated on the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Events = {
	-- server -> client
	"Sync", -- (snapshot) local player's state for the HUD
	"Notify", -- (text, kind) small toast
	"Announce", -- (payload) big centered banner: zone entry, events, catches
	"OpenPanel", -- (panelName) world kiosk opened a UI panel
	-- client -> server
	"RequestUpgrade", -- (upgradeId)
	"RequestShield", -- ()
}

local folder

local function getFolder()
	if folder then
		return folder
	end
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild("Remotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		end
		for _, name in ipairs(Remotes.Events) do
			if not folder:FindFirstChild(name) then
				local ev = Instance.new("RemoteEvent")
				ev.Name = name
				ev.Parent = folder
			end
		end
	else
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end
	return folder
end

function Remotes.get(name)
	local f = getFolder()
	if RunService:IsServer() then
		return f:FindFirstChild(name)
	end
	return f:WaitForChild(name)
end

return Remotes
