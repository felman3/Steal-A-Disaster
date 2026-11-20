--[[
	GuardianService — one guardian per zone protecting its nest.

	State machine (server-side, anchored models moved by PivotTo):
	  Sleep  → snoozes on the nest (💤). Wakes on its timer, or shortly after a
	           core is stolen ("alert").
	  Patrol → circles the nest; looks for players CARRYING a core within its
	           aggro radius and inside its leash.
	  Chase  → runs at 0.78 x the zone's gate WalkSpeed. Touching the carrier
	           knocks them back and returns their cores to the source.
	  Return → walks back to the nest after a tag or when the target escapes.
	Guardians ignore players who are only exploring.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local SpeedLogic = require(Shared.Logic.SpeedLogic)
local Kit = require(Shared.Models.Kit)

local okModels, GuardianModels = pcall(function()
	return require(Shared.Models.GuardianModels)
end)
if not okModels then
	GuardianModels = nil
end

local GuardianService = { Name = "GuardianService" }

local G = Config.Guardian
local S
local guardians = {} -- [zoneIndex] = g

function GuardianService:Init(registry)
	S = registry
end

local function fallbackModel(zoneIndex)
	local m = Instance.new("Model")
	m.Name = "Guardian"
	local root = Kit.part(m, { name = "Root", size = Vector3.new(1, 1, 1), transparency = 1, collide = false })
	m.PrimaryPart = root
	Kit.part(m, { name = "Body", size = Vector3.new(8, 8, 10), cf = CFrame.new(0, 6, 0), color = { 90, 90, 100 }, material = Enum.Material.Slate, collide = false })
	Kit.part(m, { name = "Head", size = Vector3.new(5, 5, 5), cf = CFrame.new(0, 12, -4), color = { 110, 110, 120 }, material = Enum.Material.Slate, collide = false })
	for _, x in ipairs({ -1.2, 1.2 }) do
		Kit.ball(m, { name = "Eye", diameter = 1, cf = CFrame.new(x, 12.6, -6.6), color = { 255, 60, 60 }, material = Enum.Material.Neon, collide = false })
	end
	return m
end

local function build(zoneIndex)
	local zone = Config.Zones[zoneIndex]
	local m
	if GuardianModels then
		local ok, res = pcall(GuardianModels.build, zone.guardian.kind, zoneIndex)
		if ok and res then
			m = res
		else
			warn("[Guardian] build failed for " .. zone.guardian.kind .. ": " .. tostring(res))
		end
	end
	m = m or fallbackModel(zoneIndex)
	m.Name = zone.guardian.name
	Kit.setCollide(m, false)
	Kit.setAnchored(m, true)
	local head = m:FindFirstChild("Head", true) or m.PrimaryPart
	local bb = Kit.billboard(head, { name = "GuardianLabel", size = UDim2.new(0, 220, 0, 60), offset = Vector3.new(0, 5, 0), maxDistance = 160 })
	local nameLabel = Kit.text(bb, { name = "Name", text = zone.guardian.name, size = UDim2.new(1, 0, 0.55, 0), color = { 255, 120, 90 }, font = Enum.Font.LuckiestGuy })
	local stateLabel = Kit.text(bb, { name = "State", text = "", size = UDim2.new(1, 0, 0.45, 0), position = UDim2.new(0, 0, 0.55, 0), color = { 255, 255, 255 } })
	return m, stateLabel
end

local STATE_TEXT = {
	Sleep = "💤 sleeping...",
	Patrol = "👀 on patrol",
	Chase = "❗ CHASING ❗",
	Return = "returning to nest",
}

function GuardianService:_setState(g, st)
	if g.state == st then
		return
	end
	g.state = st
	g.stateTime = 0
	g.label.Text = STATE_TEXT[st] or ""
	g.model:SetAttribute("State", st)
	if st == "Sleep" then
		g.timer = G.SleepTime
	elseif st == "Patrol" then
		g.timer = G.AwakeTime
	end
end

function GuardianService:alert(zoneIndex, player)
	local g = guardians[zoneIndex]
	if not g then
		return
	end
	if g.state == "Sleep" then
		g.timer = math.min(g.timer, 1.2)
	end
	g.lastThief = player
end

function GuardianService:get(zoneIndex)
	return guardians[zoneIndex]
end

-- Admin/test switch: a disabled guardian sleeps on its nest and never chases.
function GuardianService:setEnabled(zoneIndex, enabled)
	local g = guardians[zoneIndex]
	if not g then
		return
	end
	g.disabled = not enabled
	if g.disabled then
		self:_setState(g, "Sleep")
	end
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

function GuardianService:_findTarget(g)
	local best, bestDist
	for _, p in ipairs(Players:GetPlayers()) do
		if S.CarryService:isCarrying(p) then
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d = (flat(hrp.Position) - flat(g.pos)).Magnitude
				local fromNest = (flat(hrp.Position) - flat(g.nest)).Magnitude
				if d <= G.AggroRadius and fromNest <= G.LeashRadius and (not bestDist or d < bestDist) then
					best, bestDist = p, d
				end
			end
		end
	end
	return best
end

function GuardianService:_moveToward(g, target, speed, dt)
	local delta = flat(target) - flat(g.pos)
	local dist = delta.Magnitude
	if dist < 0.05 then
		return 0
	end
	local stepLen = math.min(dist, speed * dt)
	local dir = delta / dist
	g.pos = g.pos + dir * stepLen
	g.facing = dir
	return dist - stepLen
end

function GuardianService:_tag(g, player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	S.CarryService:dropAll(player, "guardian")
	if hrp then
		local away = flat(hrp.Position) - flat(g.pos)
		if away.Magnitude < 0.1 then
			away = Vector3.new(0, 0, -1)
		end
		hrp.AssemblyLinearVelocity = away.Unit * G.KnockbackForce + Vector3.new(0, 45, 0)
	end
	g.tagCooldown = G.TagCooldown
	self:_setState(g, "Return")
end

function GuardianService:_step(g, dt)
	if g.disabled then
		return
	end
	g.stateTime = g.stateTime + dt
	if g.tagCooldown > 0 then
		g.tagCooldown = g.tagCooldown - dt
	end
	if g.state == "Sleep" then
		g.timer = g.timer - dt
		if g.timer <= 0 then
			self:_setState(g, "Patrol")
		end
	elseif g.state == "Patrol" then
		g.angle = g.angle + dt * (G.PatrolSpeed / 18)
		local target = g.nest + Vector3.new(math.cos(g.angle) * 18, 0, math.sin(g.angle) * 18)
		self:_moveToward(g, target, G.PatrolSpeed, dt)
		g.timer = g.timer - dt
		local victim = g.tagCooldown <= 0 and self:_findTarget(g) or nil
		if victim then
			g.target = victim
			self:_setState(g, "Chase")
		elseif g.timer <= 0 then
			self:_setState(g, "Sleep")
		end
	elseif g.state == "Chase" then
		local p = g.target
		local hrp = p and p.Parent == Players and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if not hrp or not S.CarryService:isCarrying(p) then
			self:_setState(g, "Return")
		else
			local fromNest = (flat(hrp.Position) - flat(g.nest)).Magnitude
			if fromNest > G.LeashRadius + 6 then
				self:_setState(g, "Return")
			else
				local remaining = self:_moveToward(g, hrp.Position, g.chaseSpeed, dt)
				if remaining <= G.TagRange then
					self:_tag(g, p)
				end
			end
		end
	elseif g.state == "Return" then
		local remaining = self:_moveToward(g, g.nest + Vector3.new(18, 0, 0), G.PatrolSpeed * 1.6, dt)
		local victim = g.tagCooldown <= 0 and self:_findTarget(g) or nil
		if victim then
			g.target = victim
			self:_setState(g, "Chase")
		elseif remaining < 1 then
			g.angle = 0
			self:_setState(g, "Patrol")
		end
	end
	local look = g.facing or Vector3.new(0, 0, -1)
	g.model:PivotTo(CFrame.lookAt(g.pos, g.pos + look))
end

function GuardianService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Guardians"
	folder.Parent = workspace:WaitForChild("World")
	for i, zone in ipairs(Config.Zones) do
		local refs = S.ZoneService:zoneRefs(i)
		local model, label = build(i)
		local nest = Vector3.new(refs.nestCenter.X, 0.6, refs.nestCenter.Z)
		local g = {
			zoneIndex = i,
			model = model,
			label = label,
			nest = nest,
			pos = nest + Vector3.new(18, 0, 0),
			angle = 0,
			facing = Vector3.new(0, 0, -1),
			state = "",
			stateTime = 0,
			timer = 0,
			tagCooldown = 0,
			chaseSpeed = math.max(14, zone.guardian.speedFactor * SpeedLogic.walkSpeedFor(zone.speedReq)),
		}
		model:SetAttribute("ZoneIndex", i)
		model:SetAttribute("ChaseSpeed", g.chaseSpeed)
		model:PivotTo(CFrame.new(g.pos))
		model.Parent = folder
		guardians[i] = g
		-- stagger sleep cycles so zones feel different
		self:_setState(g, (i % 2 == 0) and "Sleep" or "Patrol")
		g.timer = g.timer * (0.4 + (i % 3) * 0.3)
	end
	RunService.Heartbeat:Connect(function(dt)
		for _, g in pairs(guardians) do
			self:_step(g, math.min(dt, 0.1))
		end
	end)
end

return GuardianService
