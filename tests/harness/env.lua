-- Assembles a mock Roblox DataModel with a virtual-time scheduler and maps the
-- Rojo source tree into ModuleScripts/Scripts so `require(script.Parent.X)`
-- works exactly like in Studio.
--
-- Usage (from the JS runner, per test file):
--   local Env = dofile_harness("env.lua")
--   local env = Env.new({ mode = "server" | "client" })
--   env.require("ReplicatedStorage.Shared.Logic.SpeedLogic")

local HOST = ... -- { readFile, listDir, isDir, root }

local Env = {}

local function loadHarness(name)
	local src = HOST.readFile(HOST.root .. "/tests/harness/" .. name)
	local chunk, err = load(src, "@tests/harness/" .. name, "t", _ENV)
	if not chunk then
		error(err)
	end
	return chunk
end

local datatypesChunk = loadHarness("datatypes.lua")
local instancesChunk = loadHarness("instances.lua")

local function deepcopyJson(v, seen)
	local t = type(v)
	if t == "table" then
		if getmetatable(v) ~= nil then
			error("DataStore value contains non-serializable table (has metatable)")
		end
		seen = seen or {}
		if seen[v] then
			error("DataStore value contains a cycle")
		end
		seen[v] = true
		local out = {}
		for k, x in pairs(v) do
			if type(k) ~= "string" and type(k) ~= "number" then
				error("DataStore key type " .. type(k) .. " not serializable")
			end
			out[k] = deepcopyJson(x, seen)
		end
		seen[v] = nil
		return out
	elseif t == "function" or t == "userdata" or t == "thread" then
		error("DataStore value of type " .. t .. " not serializable")
	elseif t == "number" and (v ~= v or v == math.huge or v == -math.huge) then
		error("DataStore value contains NaN/inf")
	end
	return v
end

function Env.new(opts)
	opts = opts or {}
	local env = {}
	local D = datatypesChunk()
	local M = instancesChunk(D)
	env.D, env.M = D, M
	local Instance_new = M.new
	local errors = M.errors
	env.errors = errors
	env.logs = {}
	env.warnings = {}

	-------------------------------------------------------------------------
	-- Scheduler (virtual time)
	-------------------------------------------------------------------------
	local now = 0
	local sleeping = {} -- { co, wake, args }
	local deferred = {}
	local tweens = {}
	local S = {}
	M.scheduler = S
	env.scheduler = S

	local function report(co, ok, err)
		if not ok then
			local msg = tostring(err) .. "\n" .. debug.traceback(co)
			table.insert(errors, msg)
		end
	end

	function S.now()
		return now
	end
	function S.resume(co, ...)
		if coroutine.status(co) ~= "suspended" then
			return
		end
		local ok, res = coroutine.resume(co, ...)
		report(co, ok, res)
		return ok, res
	end
	function S.spawn(fn, ...)
		local co = type(fn) == "thread" and fn or coroutine.create(fn)
		S.resume(co, ...)
		return co
	end
	function S.defer(fn, ...)
		local co = type(fn) == "thread" and fn or coroutine.create(fn)
		table.insert(deferred, { co = co, args = table.pack(...) })
		return co
	end
	function S.delay(t, fn, ...)
		local co = type(fn) == "thread" and fn or coroutine.create(fn)
		table.insert(sleeping, { co = co, wake = now + (t or 0), args = table.pack(...), fresh = true })
		return co
	end
	function S.wait(t)
		local co, main = coroutine.running()
		if main or not coroutine.isyieldable() then
			error("attempt to yield across main thread (task.wait outside coroutine)", 2)
		end
		local start = now
		table.insert(sleeping, { co = co, wake = now + math.max(t or 0, 1 / 60) })
		coroutine.yield("sleep")
		return now - start
	end
	function S.cancel(co)
		for i = #sleeping, 1, -1 do
			if sleeping[i].co == co then
				table.remove(sleeping, i)
			end
		end
		for i = #deferred, 1, -1 do
			if deferred[i].co == co then
				table.remove(deferred, i)
			end
		end
	end
	function S.playTween(tween)
		local st = M.state[tween]
		st.cancelled = false
		table.insert(tweens, { tween = tween, done = now + (st.info.Time or 0) + (st.info.DelayTime or 0) })
		-- apply goal immediately (no interpolation in tests)
		for k, v in pairs(st.goal) do
			st.target[k] = v
		end
	end

	local heartbeat, stepped, renderStepped

	local function runDeferred()
		local guard = 0
		while #deferred > 0 and guard < 1000 do
			guard = guard + 1
			local d = table.remove(deferred, 1)
			S.resume(d.co, table.unpack(d.args, 1, d.args.n))
		end
	end

	-- advance virtual time by dt (one "frame")
	function S.step(dt)
		dt = dt or 1 / 60
		now = now + dt
		if stepped then
			stepped:Fire(now, dt)
		end
		if heartbeat then
			heartbeat:Fire(dt)
		end
		if renderStepped and opts.mode == "client" then
			renderStepped:Fire(dt)
		end
		local due = {}
		local keep = {}
		for _, s in ipairs(sleeping) do
			if s.wake <= now + 1e-9 then
				table.insert(due, s)
			else
				table.insert(keep, s)
			end
		end
		sleeping = keep
		table.sort(due, function(a, b)
			return a.wake < b.wake
		end)
		for _, s in ipairs(due) do
			if s.fresh then
				S.resume(s.co, table.unpack(s.args, 1, s.args.n))
			else
				S.resume(s.co)
			end
		end
		runDeferred()
		local keepT = {}
		for _, t in ipairs(tweens) do
			if t.done <= now then
				local st = M.state[t.tween]
				if not st.cancelled then
					t.tween.Completed:Fire(D.Enum.PlaybackState.Completed)
				end
			else
				table.insert(keepT, t)
			end
		end
		tweens = keepT
	end

	-- advance by `seconds` in frames of `frame`
	function S.advance(seconds, frame)
		frame = frame or 1 / 30
		local target = now + seconds
		while now < target - 1e-9 do
			S.step(math.min(frame, target - now))
		end
	end
	env.advance = S.advance
	env.step = S.step
	function env.now()
		return now
	end

	-------------------------------------------------------------------------
	-- Globals for game code
	-------------------------------------------------------------------------
	local G = {}
	for k, v in pairs(_G) do
		G[k] = v
	end
	G._G = G
	G.Vector3, G.Vector2, G.CFrame, G.Color3 = D.Vector3, D.Vector2, D.CFrame, D.Color3
	G.UDim, G.UDim2, G.Enum, G.NumberRange = D.UDim, D.UDim2, D.Enum, D.NumberRange
	G.NumberSequence, G.NumberSequenceKeypoint = D.NumberSequence, D.NumberSequenceKeypoint
	G.ColorSequence, G.ColorSequenceKeypoint = D.ColorSequence, D.ColorSequenceKeypoint
	G.TweenInfo, G.PhysicalProperties, G.Rect, G.Ray = D.TweenInfo, D.PhysicalProperties, D.Rect, D.Ray
	G.RaycastParams, G.OverlapParams, G.BrickColor, G.Font, G.Random = D.RaycastParams, D.OverlapParams, D.BrickColor, D.Font, D.Random
	G.typeof = D.typeof
	G.unpack = table.unpack
	G.tick = function()
		return 1700000000 + now
	end
	G.time = function()
		return now
	end
	G.elapsedTime = G.time
	G.wait = function(t)
		return S.wait(t)
	end
	G.spawn = function(f)
		S.defer(f)
	end
	G.delay = function(t, f)
		S.delay(t, f)
	end
	G.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		table.insert(env.logs, table.concat(parts, " "))
		if opts.verbose then
			print("[game]", table.concat(parts, " "))
		end
	end
	G.warn = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		local msg = table.concat(parts, " ")
		table.insert(env.warnings, msg)
		if opts.verbose then
			print("[warn]", msg)
		end
	end

	-- Luau stdlib polyfills
	local mathx = {}
	for k, v in pairs(math) do
		mathx[k] = v
	end
	mathx.clamp = function(x, lo, hi)
		if lo > hi then
			error("max must be greater than or equal to min", 2)
		end
		return math.max(lo, math.min(hi, x))
	end
	mathx.sign = function(x)
		return x > 0 and 1 or (x < 0 and -1 or 0)
	end
	mathx.round = function(x)
		return math.floor(x + 0.5)
	end
	mathx.noise = function(x, y, z)
		return math.sin((x or 0) * 12.9898 + (y or 0) * 78.233 + (z or 0) * 37.719) * 0.5
	end
	mathx.log = function(x, base)
		if base then
			return math.log(x) / math.log(base)
		end
		return math.log(x)
	end
	G.math = mathx
	local tablex = {}
	for k, v in pairs(table) do
		tablex[k] = v
	end
	tablex.find = function(t, v, init)
		for i = init or 1, #t do
			if t[i] == v then
				return i
			end
		end
		return nil
	end
	tablex.clear = function(t)
		for k in pairs(t) do
			t[k] = nil
		end
	end
	tablex.freeze = function(t)
		return t
	end
	tablex.isfrozen = function()
		return false
	end
	tablex.clone = function(t)
		local o = {}
		for k, v in pairs(t) do
			o[k] = v
		end
		return o
	end
	tablex.create = function(n, v)
		local o = {}
		for i = 1, n do
			o[i] = v
		end
		return o
	end
	tablex.getn = function(t)
		return #t
	end
	G.table = tablex
	local stringx = {}
	for k, v in pairs(string) do
		stringx[k] = v
	end
	stringx.split = function(s, sep)
		sep = sep or ","
		local out = {}
		local start = 1
		while true do
			local i, j = string.find(s, sep, start, true)
			if not i then
				table.insert(out, string.sub(s, start))
				break
			end
			table.insert(out, string.sub(s, start, i - 1))
			start = j + 1
		end
		return out
	end
	G.string = stringx
	local osx = {
		time = function()
			return 1700000000 + math.floor(now)
		end,
		clock = function()
			return now
		end,
		date = os.date,
	}
	G.os = osx
	G.task = {
		spawn = S.spawn,
		defer = S.defer,
		delay = S.delay,
		wait = S.wait,
		cancel = S.cancel,
		synchronize = function() end,
		desynchronize = function() end,
	}
	G.debug = debug
	G.utf8 = utf8

	-------------------------------------------------------------------------
	-- DataModel + services
	-------------------------------------------------------------------------
	local game = M.newInternal("Instance", "Game")
	M.state[game].className = "DataModel"
	env.game = game
	local services = {}
	local function service(name, props, events, methods)
		local s = M.defineService(name, props, events, methods)
		M.state[s].parent = nil
		M.state[s].props.Name = name
		-- parent under game without firing signals
		M.state[s].parent = game
		table.insert(M.state[game].children, s)
		services[name] = s
		return s
	end

	local workspace = M.newInternal("Workspace", "Workspace")
	M.state[workspace].parent = game
	table.insert(M.state[game].children, workspace)
	services.Workspace = workspace
	local terrain = M.newInternal("Terrain", "Terrain")
	M.state[terrain].parent = workspace
	table.insert(M.state[workspace].children, terrain)
	M.state[workspace].props.Terrain = terrain
	local camera = M.new("Camera")
	camera.Name = "Camera"
	camera.Parent = workspace
	M.state[workspace].props.CurrentCamera = camera
	M.state[workspace].overrides = {
		Raycast = function()
			return nil
		end,
		GetPartBoundsInBox = function()
			return {}
		end,
		GetPartBoundsInRadius = function()
			return {}
		end,
		GetPartsInPart = function()
			return {}
		end,
		GetServerTimeNow = function()
			return 1700000000 + now
		end,
		FindPartOnRay = function()
			return nil
		end,
	}
	M.state[terrain].overrides = {
		FillBlock = function(self, cf, size, mat)
			if D.typeof(cf) ~= "CFrame" or D.typeof(size) ~= "Vector3" or D.typeof(mat) ~= "EnumItem" then
				error("Terrain:FillBlock(CFrame, Vector3, Material) bad args", 2)
			end
		end,
		FillBall = function(self, pos, r, mat)
			if D.typeof(pos) ~= "Vector3" or type(r) ~= "number" or D.typeof(mat) ~= "EnumItem" then
				error("Terrain:FillBall(Vector3, number, Material) bad args", 2)
			end
		end,
		FillCylinder = function(self, cf, h, r, mat)
			if D.typeof(cf) ~= "CFrame" or type(h) ~= "number" or type(r) ~= "number" or D.typeof(mat) ~= "EnumItem" then
				error("Terrain:FillCylinder(CFrame, number, number, Material) bad args", 2)
			end
		end,
		FillWedge = function() end,
		Clear = function() end,
		SetMaterialColor = function(self, mat, color)
			if D.typeof(mat) ~= "EnumItem" or D.typeof(color) ~= "Color3" then
				error("Terrain:SetMaterialColor bad args", 2)
			end
		end,
	}

	local function svcMethods(name, methods)
		M.state[services[name]].overrides = methods
	end

	service("ReplicatedStorage")
	service("ReplicatedFirst")
	service("ServerScriptService")
	service("ServerStorage")
	service("StarterPack")
	service("StarterGui", {}, {}, {})
	svcMethods("StarterGui", {
		SetCoreGuiEnabled = function() end,
		SetCore = function() end,
		GetCoreGuiEnabled = function()
			return true
		end,
	})
	local starterPlayer = service("StarterPlayer", {
		CharacterWalkSpeed = 16,
		CharacterJumpPower = 50,
		CharacterJumpHeight = 7.2,
		CharacterUseJumpPower = false,
		CameraMaxZoomDistance = 128,
		AutoJumpEnabled = true,
	})
	local sps = M.newInternal("Instance", "StarterPlayerScripts")
	M.state[sps].className = "StarterPlayerScripts"
	M.state[sps].parent = starterPlayer
	table.insert(M.state[starterPlayer].children, sps)
	local scs = M.newInternal("Instance", "StarterCharacterScripts")
	M.state[scs].className = "StarterCharacterScripts"
	M.state[scs].parent = starterPlayer
	table.insert(M.state[starterPlayer].children, scs)

	service("Lighting", {
		Ambient = D.Color3.new(0.5, 0.5, 0.5),
		OutdoorAmbient = D.Color3.new(0.5, 0.5, 0.5),
		Brightness = 2,
		ClockTime = 14,
		FogColor = D.Color3.new(0.75, 0.75, 0.75),
		FogEnd = 100000,
		FogStart = 0,
		GlobalShadows = true,
		EnvironmentDiffuseScale = 0,
		EnvironmentSpecularScale = 0,
		ExposureCompensation = 0,
		GeographicLatitude = 41.7,
		ShadowSoftness = 0.2,
		ColorShift_Top = D.Color3.new(0, 0, 0),
		ColorShift_Bottom = D.Color3.new(0, 0, 0),
		TimeOfDay = "14:00:00",
	})
	svcMethods("Lighting", {
		GetMinutesAfterMidnight = function()
			return 14 * 60
		end,
		SetMinutesAfterMidnight = function() end,
	})
	service("SoundService", { AmbientReverb = D.Enum.ReverbType.NoReverb, RespectFilteringEnabled = true })
	service("Teams")
	service("Chat")
	service("TextChatService")
	service("Debris")
	svcMethods("Debris", {
		AddItem = function(self, inst, t)
			S.delay(t or 10, function()
				inst:Destroy()
			end)
		end,
	})

	-- RunService
	local runService = service("RunService")
	heartbeat = M.Signal.new("Heartbeat")
	stepped = M.Signal.new("Stepped")
	renderStepped = M.Signal.new("RenderStepped")
	local preSim = M.Signal.new("PreSimulation")
	local postSim = M.Signal.new("PostSimulation")
	svcMethods("RunService", {
		Heartbeat = heartbeat,
		Stepped = stepped,
		RenderStepped = renderStepped,
		PreSimulation = preSim,
		PostSimulation = postSim,
		PreRender = renderStepped,
		IsServer = function()
			return opts.mode ~= "client"
		end,
		IsClient = function()
			return opts.mode == "client"
		end,
		IsStudio = function()
			return true
		end,
		IsRunning = function()
			return true
		end,
		BindToRenderStep = function(self, name, prio, fn)
			renderStepped:Connect(fn)
		end,
		UnbindFromRenderStep = function() end,
	})

	-- TweenService
	service("TweenService")
	svcMethods("TweenService", {
		Create = function(self, inst, info, goal)
			if not M.isInstance(inst) then
				error("TweenService:Create expects an Instance", 2)
			end
			if D.typeof(info) ~= "TweenInfo" then
				error("TweenService:Create expects TweenInfo", 2)
			end
			-- validate goal properties by reading them
			for k, v in pairs(goal) do
				local cur = inst[k]
				if cur ~= nil and D.typeof(cur) ~= D.typeof(v) then
					error("TweenService:Create property " .. k .. " type mismatch", 2)
				end
			end
			local tw = M.newInternal("Tween", "Tween")
			local st = M.state[tw]
			st.info = info
			st.goal = goal
			st.target = setmetatable({}, {
				__newindex = function(_, k, v)
					inst[k] = v
				end,
			})
			return tw
		end,
		GetValue = function(self, alpha)
			return alpha
		end,
	})

	-- CollectionService
	local tagged = {}
	local tagAddedSignals = {}
	service("CollectionService")
	M.onTagAdded = function(inst, tag)
		tagged[tag] = tagged[tag] or setmetatable({}, { __mode = "k" })
		tagged[tag][inst] = true
		if tagAddedSignals[tag] then
			tagAddedSignals[tag]:Fire(inst)
		end
	end
	svcMethods("CollectionService", {
		AddTag = function(self, inst, tag)
			inst:AddTag(tag)
		end,
		RemoveTag = function(self, inst, tag)
			inst:RemoveTag(tag)
		end,
		HasTag = function(self, inst, tag)
			return inst:HasTag(tag)
		end,
		GetTagged = function(self, tag)
			local out = {}
			for inst in pairs(tagged[tag] or {}) do
				if inst:HasTag(tag) and not M.state[inst].destroyed then
					table.insert(out, inst)
				end
			end
			return out
		end,
		GetInstanceAddedSignal = function(self, tag)
			tagAddedSignals[tag] = tagAddedSignals[tag] or M.Signal.new("TagAdded")
			return tagAddedSignals[tag]
		end,
		GetInstanceRemovedSignal = function(self, tag)
			return M.Signal.new("TagRemoved")
		end,
	})

	-- HttpService (JSON)
	service("HttpService")
	local function jsonEncode(v)
		local t = type(v)
		if t == "nil" then
			return "null"
		elseif t == "boolean" then
			return tostring(v)
		elseif t == "number" then
			if v ~= v or v == math.huge or v == -math.huge then
				return "null"
			end
			if math.type and math.type(v) == "integer" then
				return tostring(v)
			end
			return string.format("%.14g", v)
		elseif t == "string" then
			return '"' .. v:gsub('[%c"\\]', function(c)
				return string.format("\\u%04x", c:byte())
			end) .. '"'
		elseif t == "table" then
			if #v > 0 or next(v) == nil then
				local parts = {}
				for i, x in ipairs(v) do
					parts[i] = jsonEncode(x)
				end
				return "[" .. table.concat(parts, ",") .. "]"
			end
			local parts = {}
			for k, x in pairs(v) do
				table.insert(parts, jsonEncode(tostring(k)) .. ":" .. jsonEncode(x))
			end
			table.sort(parts)
			return "{" .. table.concat(parts, ",") .. "}"
		end
		error("cannot JSON encode " .. t)
	end
	local guid = 0
	svcMethods("HttpService", {
		JSONEncode = function(self, v)
			return jsonEncode(v)
		end,
		JSONDecode = function()
			error("JSONDecode not supported in harness")
		end,
		GenerateGUID = function(self, braces)
			guid = guid + 1
			local s = string.format("00000000-0000-0000-0000-%012d", guid)
			if braces == false then
				return s
			end
			return "{" .. s .. "}"
		end,
	})

	-- DataStoreService
	local stores = {}
	env.datastore = { stores = stores, failNext = 0, calls = 0 }
	service("DataStoreService")
	local function makeStore(name)
		local data = {}
		local store = {}
		local function maybeFail()
			env.datastore.calls = env.datastore.calls + 1
			if env.datastore.failNext > 0 then
				env.datastore.failNext = env.datastore.failNext - 1
				error("502: API Services rejected request (simulated)")
			end
		end
		function store:GetAsync(key)
			maybeFail()
			return deepcopyJson(data[key])
		end
		function store:SetAsync(key, value)
			maybeFail()
			data[key] = deepcopyJson(value)
		end
		function store:UpdateAsync(key, fn)
			maybeFail()
			local new = fn(deepcopyJson(data[key]))
			if new ~= nil then
				data[key] = deepcopyJson(new)
			end
			return deepcopyJson(data[key])
		end
		function store:RemoveAsync(key)
			maybeFail()
			local old = data[key]
			data[key] = nil
			return old
		end
		store._data = data
		return store
	end
	svcMethods("DataStoreService", {
		GetDataStore = function(self, name, scope)
			local key = name .. "/" .. tostring(scope or "global")
			stores[key] = stores[key] or makeStore(key)
			return stores[key]
		end,
		GetOrderedDataStore = function(self, name)
			local key = "ordered:" .. name
			stores[key] = stores[key] or makeStore(key)
			return stores[key]
		end,
		GetRequestBudgetForRequestType = function()
			return 100
		end,
	})

	-- UserInputService / GuiService / ContextActionService (client)
	service("UserInputService", {
		TouchEnabled = opts.touch or false,
		KeyboardEnabled = not opts.touch,
		MouseEnabled = not opts.touch,
		GamepadEnabled = false,
		MouseBehavior = D.Enum.MouseBehavior.Default,
		MouseIconEnabled = true,
	}, { "InputBegan", "InputEnded", "InputChanged", "LastInputTypeChanged", "TouchTap", "JumpRequest" })
	svcMethods("UserInputService", {
		GetLastInputType = function()
			return opts.touch and D.Enum.UserInputType.Touch or D.Enum.UserInputType.MouseButton1
		end,
		IsKeyDown = function()
			return false
		end,
		GetMouseLocation = function()
			return D.Vector2.new(0, 0)
		end,
	})
	service("GuiService", { AutoSelectGuiEnabled = true, SelectedObject = M.NIL })
	svcMethods("GuiService", {
		GetGuiInset = function()
			return D.Vector2.new(0, 36), D.Vector2.zero
		end,
	})
	service("ContextActionService")
	svcMethods("ContextActionService", {
		BindAction = function() end,
		UnbindAction = function() end,
		SetTitle = function() end,
	})
	service("MarketplaceService")
	service("TextService")
	svcMethods("TextService", {
		GetTextSize = function(self, text, size)
			return D.Vector2.new(#text * size * 0.5, size)
		end,
	})
	service("PhysicsService")
	svcMethods("PhysicsService", {
		RegisterCollisionGroup = function() end,
		CollisionGroupSetCollidable = function() end,
		IsCollisionGroupRegistered = function()
			return true
		end,
	})
	service("ProximityPromptService", { Enabled = true, MaxPromptsVisible = 16 }, { "PromptTriggered", "PromptShown" })
	service("MessagingService")
	service("BadgeService")

	-- Players
	local players = service("Players", { MaxPlayers = 8, RespawnTime = 5, CharacterAutoLoads = true, LocalPlayer = M.NIL }, { "PlayerAdded", "PlayerRemoving" })
	local localPlayer = nil
	local playerList = {}
	svcMethods("Players", {
		GetPlayers = function()
			local out = {}
			for _, p in ipairs(playerList) do
				table.insert(out, p)
			end
			return out
		end,
		GetPlayerFromCharacter = function(self, char)
			for _, p in ipairs(playerList) do
				if p.Character == char then
					return p
				end
			end
			return nil
		end,
		GetPlayerByUserId = function(self, id)
			for _, p in ipairs(playerList) do
				if p.UserId == id then
					return p
				end
			end
			return nil
		end,
		GetUserThumbnailAsync = function()
			return "rbxthumb://", true
		end,
		GetNameFromUserIdAsync = function()
			return "Player"
		end,
	})
	M.state[players].writableOverrides = {}

	local function buildCharacter(player)
		local char = M.new("Model")
		char.Name = player.Name
		local hrp = M.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Size = D.Vector3.new(2, 2, 1)
		hrp.Transparency = 1
		hrp.Parent = char
		local head = M.new("Part")
		head.Name = "Head"
		head.Size = D.Vector3.new(2, 1, 1)
		head.Parent = char
		local hum = M.new("Humanoid")
		hum.Parent = char
		M.state[hum].props.RootPart = hrp
		char.PrimaryPart = hrp
		return char, hrp, hum
	end

	local userIds = 1000
	function env.addPlayer(name, userId)
		userIds = userIds + 1
		local p = M.newInternal("Player", name)
		local pst = M.state[p]
		pst.props.DisplayName = name
		pst.props.UserId = userId or userIds
		pst.kicked = nil
		pst.overrides = {
			Kick = function(self, msg)
				pst.kicked = msg or true
				env.removePlayer(p)
			end,
			LoadCharacter = function(self)
				env.loadCharacter(p)
			end,
			GetMouse = function()
				return { Hit = D.CFrame.identity, Target = nil }
			end,
			IsInGroup = function()
				return false
			end,
			GetRankInGroup = function()
				return 0
			end,
			ClearCharacterAppearance = function() end,
			HasAppearanceLoaded = function()
				return true
			end,
			GetNetworkPing = function()
				return 0.05
			end,
		}
		local pg = M.newInternal("PlayerGui", "PlayerGui")
		local bp = M.newInternal("Backpack", "Backpack")
		local ps = M.newInternal("PlayerScripts", "PlayerScripts")
		for _, c in ipairs({ pg, bp, ps }) do
			M.state[c].parent = p
			table.insert(pst.children, c)
		end
		M.state[p].parent = players
		table.insert(M.state[players].children, p)
		table.insert(playerList, p)
		if opts.mode == "client" and not localPlayer then
			localPlayer = p
			M.state[players].overrides.LocalPlayer = p
		end
		players.PlayerAdded:Fire(p)
		if opts.autoCharacter ~= false then
			env.loadCharacter(p)
		end
		return p
	end

	function env.loadCharacter(p)
		local old = p.Character
		if old then
			p.CharacterRemoving:Fire(old)
			old:Destroy()
		end
		local char, hrp, hum = buildCharacter(p)
		M.state[p].props.Character = char
		char.Parent = workspace
		p.CharacterAdded:Fire(char)
		return char
	end

	function env.removePlayer(p)
		for i, x in ipairs(playerList) do
			if x == p then
				table.remove(playerList, i)
				break
			end
		end
		players.PlayerRemoving:Fire(p)
		if p.Character then
			p.Character:Destroy()
		end
		M.state[p].parent = nil
		local pc = M.state[players].children
		for i, c in ipairs(pc) do
			if c == p then
				table.remove(pc, i)
				break
			end
		end
	end

	-- move a player's character (teleport-style; tests interpolate when needed)
	function env.moveTo(p, pos)
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		hrp.CFrame = D.CFrame.new(pos)
	end
	-- walk in straight line at `speed` studs/s, stepping the scheduler
	function env.walkTo(p, pos, speed, frame)
		frame = frame or 1 / 20
		local hrp = p.Character:FindFirstChild("HumanoidRootPart")
		local hum = p.Character:FindFirstChildOfClass("Humanoid")
		speed = speed or hum.WalkSpeed
		local guard = 0
		while guard < 200000 do
			guard = guard + 1
			local cur = hrp.Position
			local delta = D.Vector3.new(pos.X - cur.X, 0, pos.Z - cur.Z)
			local dist = delta.Magnitude
			if dist < 0.01 then
				break
			end
			local stepLen = math.min(dist, speed * frame)
			local dir = delta.Unit
			M.state[hum].props.MoveDirection = dir
			hrp.CFrame = D.CFrame.new(D.Vector3.new(cur.X, pos.Y, cur.Z) + dir * stepLen)
			S.step(frame)
			if not p.Character or p.Character:FindFirstChild("HumanoidRootPart") ~= hrp then
				return false
			end
			speed = math.min(speed, hum.WalkSpeed) -- respect server slowdowns
		end
		M.state[hum].props.MoveDirection = D.Vector3.zero
		return true
	end

	G.game = setmetatable({}, {
		__index = function(_, k)
			if k == "GetService" then
				return function(self, name)
					local s = services[name]
					if not s then
						error("'" .. tostring(name) .. "' is not a valid Service name", 2)
					end
					return s
				end
			elseif k == "FindService" then
				return function(self, name)
					return services[name]
				end
			elseif k == "BindToClose" then
				return function(self, fn)
					env.closeHandlers = env.closeHandlers or {}
					table.insert(env.closeHandlers, fn)
				end
			elseif k == "PlaceId" then
				return 0
			elseif k == "JobId" then
				return ""
			elseif k == "CreatorId" then
				return 0
			elseif k == "Workspace" then
				return workspace
			end
			return game[k]
		end,
	})
	G.workspace = workspace
	G.Workspace = workspace
	G.Instance = {
		new = function(cn, parent)
			return Instance_new(cn, parent)
		end,
	}
	G.shared = {}
	env.G = G
	env.services = services

	-------------------------------------------------------------------------
	-- Source tree mapping (Rojo-style)
	-------------------------------------------------------------------------
	local moduleCache = {}
	local function scriptClassFor(fname)
		if fname:match("%.server%.lua$") then
			return "Script", fname:gsub("%.server%.lua$", "")
		elseif fname:match("%.client%.lua$") then
			return "LocalScript", fname:gsub("%.client%.lua$", "")
		elseif fname:match("%.lua$") then
			return "ModuleScript", fname:gsub("%.lua$", "")
		end
		return nil
	end

	local function mount(dirPath, parent)
		for _, fname in ipairs(HOST.listDir(dirPath)) do
			local full = dirPath .. "/" .. fname
			if HOST.isDir(full) then
				local folder = Instance_new("Folder")
				folder.Name = fname
				folder.Parent = parent
				mount(full, folder)
			else
				local cn, name = scriptClassFor(fname)
				if cn then
					local inst = Instance_new(cn)
					inst.Name = name
					M.state[inst].path = full
					inst.Parent = parent
				end
			end
		end
	end

	local function makeFolder(name, parent)
		local f = Instance_new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end

	mount(HOST.root .. "/src/shared", makeFolder("Shared", services.ReplicatedStorage))
	mount(HOST.root .. "/src/server", makeFolder("Server", services.ServerScriptService))
	mount(HOST.root .. "/src/client", makeFolder("Client", sps))

	local function loadScript(inst)
		local st = M.state[inst]
		local path = st.path
		if not path then
			error("Cannot require " .. inst:GetFullName() .. ": no source", 3)
		end
		local src = HOST.readFile(path)
		local rel = path:sub(#HOST.root + 2)
		local senv = setmetatable({ script = inst }, { __index = G, __newindex = G })
		local chunk, err = load(src, "@" .. rel, "t", senv)
		if not chunk then
			error("Syntax error: " .. tostring(err), 0)
		end
		return chunk
	end

	G.require = function(target)
		if not M.isInstance(target) then
			error("Attempted to call require with invalid argument(s).", 2)
		end
		if target.ClassName ~= "ModuleScript" then
			error("require expects a ModuleScript, got " .. target.ClassName, 2)
		end
		local key = M.state[target].path or target
		local cached = moduleCache[key]
		if cached then
			if cached.loading then
				error("Recursive require detected: " .. target:GetFullName(), 2)
			end
			return cached.value
		end
		cached = { loading = true }
		moduleCache[key] = cached
		local chunk = loadScript(target)
		local ok, res = pcall(chunk)
		if not ok then
			moduleCache[key] = nil
			error(res, 0)
		end
		cached.loading = false
		cached.value = res
		return res
	end

	-- resolve "ReplicatedStorage.Shared.Logic.SpeedLogic" to an instance
	function env.find(path)
		local parts = {}
		for p in path:gmatch("[^%.]+") do
			table.insert(parts, p)
		end
		local cur = services[parts[1]]
		if parts[1] == "StarterPlayerScripts" then
			cur = sps
		end
		for i = 2, #parts do
			cur = cur and cur:FindFirstChild(parts[i])
		end
		if not cur then
			error("env.find: " .. path .. " not found")
		end
		return cur
	end

	function env.require(path)
		return G.require(env.find(path))
	end

	-- run a Script/LocalScript (as Roblox would) inside a coroutine
	function env.runScript(path)
		local inst = env.find(path)
		local chunk = loadScript(inst)
		S.spawn(chunk)
	end

	-- run `fn` inside a scheduler coroutine (so it may yield)
	function env.run(fn, ...)
		return S.spawn(fn, ...)
	end

	function env.close()
		for _, fn in ipairs(env.closeHandlers or {}) do
			S.spawn(fn)
		end
		S.advance(5)
	end

	return env
end

return Env
