--[[
	Server bootstrap. Builds the world, then initializes and starts every
	service in dependency order. Services get the registry `S` in Init so they
	can call each other (S.CarryService:drop(...), etc.).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local ServicesFolder = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")

local ORDER = {
	"PlayerDataService",
	"ZoneService", -- builds the map
	"BaseService",
	"EconomyService",
	"SpeedService",
	"EventService",
	"CoreSpawnService",
	"CarryService",
	"StealService",
	"IncubatorService",
	"DisasterCollectionService",
	"GuardianService",
	"UpgradeService",
}

local S = {}
for _, name in ipairs(ORDER) do
	S[name] = require(ServicesFolder:WaitForChild(name))
end

for _, name in ipairs(ORDER) do
	local svc = S[name]
	if svc.Init then
		local ok, err = xpcall(svc.Init, debug.traceback, svc, S)
		if not ok then
			warn("[Main] " .. name .. ".Init failed: " .. tostring(err))
		end
	end
end

for _, name in ipairs(ORDER) do
	local svc = S[name]
	if svc.Start then
		local ok, err = xpcall(svc.Start, debug.traceback, svc)
		if not ok then
			warn("[Main] " .. name .. ".Start failed: " .. tostring(err))
		end
	end
end

-- expose for the headless integration tests / Studio command bar debugging
_G.StealADisaster = S
print("[Steal a Disaster] server ready")
