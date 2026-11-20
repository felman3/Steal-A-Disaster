--[[
	State — the latest server snapshot for the local player.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

local State = {
	snapshot = nil,
	Changed = Signal.new(),
}

function State.set(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	State.snapshot = snapshot
	State.Changed:Fire(snapshot)
end

function State.get()
	return State.snapshot
end

return State
