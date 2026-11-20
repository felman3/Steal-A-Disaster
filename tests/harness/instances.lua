-- Roblox Instance mock with per-class property schemas (Lua 5.4).
-- Unknown properties/members raise errors just like Roblox, and property
-- writes are type-checked against the schema default, so typos and wrong
-- datatypes in game code fail loudly in tests.

local D = ...
local Vector3, Vector2, CFrame, Color3, UDim, UDim2, Enum = D.Vector3, D.Vector2, D.CFrame, D.Color3, D.UDim, D.UDim2, D.Enum
local typeof = D.typeof

local M = {}
M.errors = {}
M.scheduler = nil -- set by env

local NIL = setmetatable({}, { __tostring = function()
	return "NIL"
end })
M.NIL = NIL
local ANY = setmetatable({}, { __tostring = function()
	return "ANY"
end })

---------------------------------------------------------------------------
-- Signals
---------------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
Signal.__type = "RBXScriptSignal"
function Signal.new(name)
	return setmetatable({ name = name, handlers = {}, waiting = {} }, Signal)
end
function Signal:Connect(fn)
	if type(fn) ~= "function" then
		error("Attempt to connect failed: Passed value is not a function", 2)
	end
	local conn
	conn = setmetatable({ Connected = true, fn = fn }, {
		__type = "RBXScriptConnection",
		__index = {
			Disconnect = function(c)
				c.Connected = false
			end,
		},
	})
	table.insert(self.handlers, conn)
	return conn
end
function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end
function Signal:Wait()
	local co = coroutine.running()
	table.insert(self.waiting, co)
	return coroutine.yield("signal")
end
function Signal:Fire(...)
	local list = self.handlers
	local alive = {}
	for _, c in ipairs(list) do
		if c.Connected then
			table.insert(alive, c)
		end
	end
	self.handlers = alive
	for _, c in ipairs(alive) do
		if c.Connected then
			M.scheduler.spawn(c.fn, ...)
		end
	end
	local waiting = self.waiting
	self.waiting = {}
	for _, co in ipairs(waiting) do
		M.scheduler.resume(co, ...)
	end
end
function Signal:DisconnectAll()
	for _, c in ipairs(self.handlers) do
		c.Connected = false
	end
	self.handlers = {}
end
M.Signal = Signal

---------------------------------------------------------------------------
-- Class schemas
---------------------------------------------------------------------------
local Classes = {}
M.Classes = Classes

local function class(name, super, props, events, methods, opts)
	Classes[name] = {
		name = name,
		super = super,
		props = props or {},
		events = events or {},
		methods = methods or {},
		opts = opts or {},
	}
end

local function E(t, item)
	return Enum[t][item]
end

class("Instance", nil, { Archivable = true }, {
	"ChildAdded",
	"ChildRemoved",
	"DescendantAdded",
	"DescendantRemoving",
	"AncestryChanged",
	"Changed",
	"Destroying",
	"AttributeChanged",
})
class("Folder", "Instance")
class("Configuration", "Instance")
class("PVInstance", "Instance")
class("Model", "PVInstance", {
	PrimaryPart = NIL,
	WorldPivot = CFrame.identity,
	LevelOfDetail = E("ModelLevelOfDetail", "Automatic"),
	ModelStreamingMode = E("ModelStreamingMode", "Default"),
})
class("Actor", "Model")
class("WorldRoot", "Model")
class("Workspace", "WorldRoot", {
	Gravity = 196.2,
	CurrentCamera = NIL,
	FallenPartsDestroyHeight = -500,
	StreamingEnabled = false,
	Terrain = NIL,
	DistributedGameTime = 0,
})

local basePartProps = {
	Anchored = false,
	CanCollide = true,
	CanTouch = true,
	CanQuery = true,
	CastShadow = true,
	Transparency = 0,
	Reflectance = 0,
	Color = Color3.fromRGB(163, 162, 165),
	BrickColor = ANY,
	Material = E("Material", "Plastic"),
	MaterialVariant = "",
	Size = Vector3.new(4, 1, 2),
	CFrame = CFrame.identity,
	Massless = false,
	Locked = false,
	TopSurface = E("SurfaceType", "Smooth"),
	BottomSurface = E("SurfaceType", "Smooth"),
	FrontSurface = E("SurfaceType", "Smooth"),
	BackSurface = E("SurfaceType", "Smooth"),
	LeftSurface = E("SurfaceType", "Smooth"),
	RightSurface = E("SurfaceType", "Smooth"),
	AssemblyLinearVelocity = Vector3.zero,
	AssemblyAngularVelocity = Vector3.zero,
	CollisionGroup = "Default",
	CustomPhysicalProperties = NIL,
	RootPriority = 0,
	LocalTransparencyModifier = 0,
	EnableFluidForces = true,
	PivotOffset = CFrame.identity,
	AudioCanCollide = true,
}
class("BasePart", "PVInstance", basePartProps, { "Touched", "TouchEnded" })
class("Part", "BasePart", { Shape = E("PartType", "Block") })
class("FormFactorPart", "BasePart")
class("WedgePart", "BasePart")
class("CornerWedgePart", "BasePart")
class("TrussPart", "BasePart", { Style = E("Style", "AlternatingSupports") })
class("SpawnLocation", "Part", {
	Neutral = true,
	Duration = 0,
	Enabled = true,
	AllowTeamChangeOnTouch = false,
	TeamColor = ANY,
})
class("MeshPart", "BasePart", { MeshId = "", TextureID = "", DoubleSided = false, RenderFidelity = E("RenderFidelity", "Automatic") })
class("Terrain", "BasePart", {
	WaterColor = Color3.new(0, 0.3, 0.5),
	WaterReflectance = 1,
	WaterTransparency = 0.3,
	WaterWaveSize = 0.15,
	WaterWaveSpeed = 10,
	Decoration = false,
}, nil, nil)

class("Humanoid", "Instance", {
	WalkSpeed = 16,
	JumpPower = 50,
	JumpHeight = 7.2,
	UseJumpPower = false,
	Health = 100,
	MaxHealth = 100,
	MoveDirection = Vector3.zero,
	AutoRotate = true,
	PlatformStand = false,
	Sit = false,
	Jump = false,
	HipHeight = 2,
	DisplayName = "",
	DisplayDistanceType = E("HumanoidDisplayDistanceType", "Viewer"),
	HealthDisplayType = E("HumanoidHealthDisplayType", "DisplayWhenDamaged"),
	NameDisplayDistance = 100,
	HealthDisplayDistance = 100,
	RigType = E("HumanoidRigType", "R15"),
	RootPart = NIL,
	FloorMaterial = E("Material", "Air"),
	BreakJointsOnDeath = true,
	RequiresNeck = true,
	AutoJumpEnabled = true,
	EvaluateStateMachine = true,
	WalkToPoint = Vector3.zero,
	CameraOffset = Vector3.zero,
}, { "Died", "Running", "StateChanged", "MoveToFinished", "HealthChanged", "Jumping", "Touched", "FreeFalling" })
class("HumanoidDescription", "Instance")
class("Animator", "Instance")
class("Animation", "Instance", { AnimationId = "" })

class("Attachment", "Instance", {
	CFrame = CFrame.identity,
	Visible = false,
	Axis = Vector3.new(1, 0, 0),
	SecondaryAxis = Vector3.new(0, 1, 0),
})
class("Bone", "Attachment")
local constraintProps = { Enabled = true, Visible = false, Attachment0 = NIL, Attachment1 = NIL, Color = ANY }
class("Constraint", "Instance", constraintProps)
class("AlignPosition", "Constraint", {
	Mode = E("PositionAlignmentMode", "TwoAttachment"),
	Position = Vector3.zero,
	MaxForce = 10000,
	MaxVelocity = math.huge,
	Responsiveness = 10,
	RigidityEnabled = false,
	ApplyAtCenterOfMass = false,
	ReactionForceEnabled = false,
})
class("AlignOrientation", "Constraint", {
	Mode = E("OrientationAlignmentMode", "TwoAttachment"),
	CFrame = CFrame.identity,
	MaxTorque = 10000,
	MaxAngularVelocity = math.huge,
	Responsiveness = 10,
	RigidityEnabled = false,
})
class("LinearVelocity", "Constraint", {
	VectorVelocity = Vector3.zero,
	MaxForce = 1000,
	RelativeTo = E("ActuatorRelativeTo", "World"),
	VelocityConstraintMode = E("VelocityConstraintMode", "Vector"),
})
class("RopeConstraint", "Constraint", { Length = 5, Thickness = 0.1 })
class("JointInstance", "Instance", { Part0 = NIL, Part1 = NIL, C0 = CFrame.identity, C1 = CFrame.identity, Enabled = true })
class("Weld", "JointInstance")
class("Motor6D", "JointInstance", { Transform = CFrame.identity, MaxVelocity = 0.1, DesiredAngle = 0, CurrentAngle = 0 })
class("WeldConstraint", "Instance", { Part0 = NIL, Part1 = NIL, Enabled = true, Active = true })
class("NoCollisionConstraint", "Instance", { Part0 = NIL, Part1 = NIL, Enabled = true })

class("Beam", "Instance", {
	Attachment0 = NIL,
	Attachment1 = NIL,
	Color = ANY,
	Transparency = ANY,
	Width0 = 1,
	Width1 = 1,
	FaceCamera = false,
	LightEmission = 0,
	LightInfluence = 1,
	Texture = "",
	TextureSpeed = 1,
	TextureLength = 1,
	TextureMode = E("TextureMode", "Stretch"),
	Segments = 10,
	CurveSize0 = 0,
	CurveSize1 = 0,
	Enabled = true,
	Brightness = 1,
	ZOffset = 0,
})
class("Trail", "Instance", {
	Attachment0 = NIL,
	Attachment1 = NIL,
	Color = ANY,
	Transparency = ANY,
	Lifetime = 2,
	MinLength = 0.1,
	MaxLength = 0,
	WidthScale = ANY,
	FaceCamera = false,
	LightEmission = 0,
	LightInfluence = 1,
	Texture = "",
	TextureLength = 1,
	TextureMode = E("TextureMode", "Stretch"),
	Enabled = true,
	Brightness = 1,
})
class("ParticleEmitter", "Instance", {
	Color = ANY,
	Transparency = ANY,
	Size = ANY,
	Texture = "rbxasset://textures/particles/sparkles_main.dds",
	Lifetime = D.NumberRange.new(5, 10),
	Rate = 20,
	Speed = D.NumberRange.new(5),
	SpreadAngle = Vector2.zero,
	Rotation = D.NumberRange.new(0),
	RotSpeed = D.NumberRange.new(0),
	LightEmission = 0,
	LightInfluence = 0,
	Enabled = true,
	EmissionDirection = E("NormalId", "Top"),
	Acceleration = Vector3.zero,
	Drag = 0,
	LockedToPart = false,
	VelocityInheritance = 0,
	ZOffset = 0,
	Shape = E("ParticleEmitterShape", "Box"),
	ShapeInOut = E("ParticleEmitterShapeInOut", "Outward"),
	ShapeStyle = E("ParticleEmitterShapeStyle", "Volume"),
	Orientation = E("ParticleOrientation", "FacingCamera"),
	Squash = ANY,
	Brightness = 1,
	TimeScale = 1,
	FlipbookLayout = E("ParticleFlipbookLayout", "None"),
}, nil, {
	Emit = function() end,
	Clear = function() end,
})
class("Fire", "Instance", { Color = ANY, SecondaryColor = ANY, Heat = 9, Size = 5, Enabled = true, TimeScale = 1 })
class("Smoke", "Instance", { Color = ANY, Opacity = 0.5, RiseVelocity = 1, Size = 1, Enabled = true, TimeScale = 1 })
class("Sparkles", "Instance", { SparkleColor = ANY, Enabled = true, TimeScale = 1 })
class("Light", "Instance", { Brightness = 1, Color = Color3.new(1, 1, 1), Enabled = true, Shadows = false })
class("PointLight", "Light", { Range = 8 })
class("SpotLight", "Light", { Range = 16, Angle = 90, Face = E("NormalId", "Front") })
class("SurfaceLight", "Light", { Range = 16, Angle = 90, Face = E("NormalId", "Front") })
class("Highlight", "Instance", {
	Adornee = NIL,
	FillColor = Color3.new(1, 0, 0),
	FillTransparency = 0.5,
	OutlineColor = Color3.new(1, 1, 1),
	OutlineTransparency = 0,
	DepthMode = E("HighlightDepthMode", "AlwaysOnTop"),
	Enabled = true,
})
class("SelectionBox", "Instance", {
	Adornee = NIL,
	Color3 = Color3.new(0, 0, 1),
	LineThickness = 0.15,
	SurfaceColor3 = Color3.new(0, 0, 1),
	SurfaceTransparency = 1,
	Transparency = 0,
	Visible = true,
})
class("Decal", "Instance", { Texture = "", Face = E("NormalId", "Front"), Transparency = 0, Color3 = Color3.new(1, 1, 1), ZIndex = 1 })
class("Texture", "Decal", { StudsPerTileU = 2, StudsPerTileV = 2, OffsetStudsU = 0, OffsetStudsV = 0 })
class("SpecialMesh", "Instance", { MeshType = E("MeshType", "Head"), MeshId = "", TextureId = "", Scale = Vector3.one, Offset = Vector3.zero, VertexColor = Vector3.one })
class("BlockMesh", "Instance", { Scale = Vector3.one, Offset = Vector3.zero })

class("Sound", "Instance", {
	SoundId = "",
	Volume = 0.5,
	Looped = false,
	Playing = false,
	PlaybackSpeed = 1,
	RollOffMaxDistance = 10000,
	RollOffMinDistance = 10,
	RollOffMode = E("RollOffMode", "InverseTapered"),
	TimePosition = 0,
	SoundGroup = NIL,
	PlayOnRemove = false,
}, { "Ended", "Loaded", "Played" }, {
	Play = function(self)
		self.Playing = true
	end,
	Stop = function(self)
		self.Playing = false
	end,
	Pause = function(self)
		self.Playing = false
	end,
	Resume = function(self)
		self.Playing = true
	end,
})
class("SoundGroup", "Instance", { Volume = 0.5 })

class("ValueBase", "Instance", {}, { "Changed" })
class("StringValue", "ValueBase", { Value = "" })
class("IntValue", "ValueBase", { Value = 0 })
class("NumberValue", "ValueBase", { Value = 0 })
class("BoolValue", "ValueBase", { Value = false })
class("ObjectValue", "ValueBase", { Value = NIL })
class("Vector3Value", "ValueBase", { Value = Vector3.zero })
class("CFrameValue", "ValueBase", { Value = CFrame.identity })
class("Color3Value", "ValueBase", { Value = Color3.new() })

class("LuaSourceContainer", "Instance", { Source = "" })
class("ModuleScript", "LuaSourceContainer")
class("BaseScript", "LuaSourceContainer", { Disabled = false, Enabled = true, RunContext = E("RunContext", "Legacy") })
class("Script", "BaseScript")
class("LocalScript", "Script")

M.remoteLog = {}
local function logRemote(self, kind, target, ...)
	table.insert(M.remoteLog, { remote = M.state[self].props.Name, kind = kind, target = target, args = table.pack(...) })
end
class("RemoteEvent", "Instance", {}, { "OnServerEvent", "OnClientEvent" }, {
	FireClient = function(self, player, ...)
		if not M.isInstance(player) or M.state[player].className ~= "Player" then
			error("FireClient: player argument must be a Player", 2)
		end
		logRemote(self, "client", player, ...)
		if M.onFireClient then
			M.onFireClient(self, player, ...)
		end
	end,
	FireAllClients = function(self, ...)
		logRemote(self, "all", nil, ...)
		if M.onFireAllClients then
			M.onFireAllClients(self, ...)
		end
	end,
	FireServer = function(self, ...)
		logRemote(self, "server", nil, ...)
		if M.onFireServer then
			M.onFireServer(self, ...)
		end
	end,
})
class("UnreliableRemoteEvent", "RemoteEvent")
class("RemoteFunction", "Instance", { OnServerInvoke = NIL, OnClientInvoke = NIL })
class("BindableEvent", "Instance", {}, { "Event" }, {
	Fire = function(self, ...)
		self.Event:Fire(...)
	end,
})
class("BindableFunction", "Instance", { OnInvoke = NIL })

class("ProximityPrompt", "Instance", {
	ActionText = "Interact",
	ObjectText = "",
	HoldDuration = 0,
	MaxActivationDistance = 10,
	KeyboardKeyCode = E("KeyCode", "E"),
	GamepadKeyCode = E("KeyCode", "ButtonX"),
	RequiresLineOfSight = true,
	Enabled = true,
	ClickablePrompt = true,
	Exclusivity = E("ProximityPromptExclusivity", "OnePerButton"),
	Style = E("ProximityPromptStyle", "Default"),
	UIOffset = Vector2.zero,
	AutoLocalize = true,
}, { "Triggered", "TriggerEnded", "PromptButtonHoldBegan", "PromptButtonHoldEnded", "PromptShown", "PromptHidden" }, {
	InputHoldBegin = function() end,
	InputHoldEnd = function() end,
})
class("ClickDetector", "Instance", { MaxActivationDistance = 32, CursorIcon = "" }, { "MouseClick", "MouseHoverEnter", "MouseHoverLeave" })

class("Camera", "PVInstance", {
	CFrame = CFrame.identity,
	Focus = CFrame.identity,
	FieldOfView = 70,
	CameraType = E("CameraType", "Custom"),
	CameraSubject = NIL,
	ViewportSize = Vector2.new(1280, 720),
}, nil, {
	WorldToViewportPoint = function(self, v)
		return Vector3.new(0, 0, 1), true
	end,
	WorldToScreenPoint = function(self, v)
		return Vector3.new(0, 0, 1), true
	end,
	ViewportPointToRay = function(self, x, y)
		return D.Ray.new(Vector3.zero, Vector3.new(0, 0, -1))
	end,
})

-- Lighting & post effects
class("Sky", "Instance", {
	SkyboxBk = "",
	SkyboxDn = "",
	SkyboxFt = "",
	SkyboxLf = "",
	SkyboxRt = "",
	SkyboxUp = "",
	SunAngularSize = 21,
	MoonAngularSize = 11,
	StarCount = 3000,
	CelestialBodiesShown = true,
	SunTextureId = "",
	MoonTextureId = "",
	SkyboxOrientation = Vector3.zero,
})
class("Atmosphere", "Instance", {
	Density = 0.395,
	Offset = 0,
	Color = Color3.fromRGB(199, 199, 199),
	Decay = Color3.fromRGB(106, 112, 125),
	Glare = 0,
	Haze = 0,
})
class("Clouds", "Instance", { Cover = 0.5, Density = 0.7, Color = Color3.new(1, 1, 1), Enabled = true })
class("PostEffect", "Instance", { Enabled = true })
class("ColorCorrectionEffect", "PostEffect", { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) })
class("BloomEffect", "PostEffect", { Intensity = 1, Size = 24, Threshold = 2 })
class("SunRaysEffect", "PostEffect", { Intensity = 0.25, Spread = 1 })
class("BlurEffect", "PostEffect", { Size = 24 })
class("DepthOfFieldEffect", "PostEffect", { FarIntensity = 0.75, FocusDistance = 0.05, InFocusRadius = 10, NearIntensity = 0.75 })

-- GUI
local guiBase = {
	Size = UDim2.new(0, 100, 0, 100),
	Position = UDim2.new(0, 0, 0, 0),
	AnchorPoint = Vector2.zero,
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0,
	BorderSizePixel = 1,
	BorderColor3 = Color3.fromRGB(27, 42, 53),
	BorderMode = E("BorderMode", "Outline"),
	Visible = true,
	ZIndex = 1,
	LayoutOrder = 0,
	Rotation = 0,
	ClipsDescendants = false,
	Active = false,
	AutomaticSize = E("AutomaticSize", "None"),
	SizeConstraint = E("SizeConstraint", "RelativeXY"),
	Selectable = false,
	Interactable = true,
	AutoLocalize = true,
}
class("GuiBase2d", "Instance")
class("GuiObject", "GuiBase2d", guiBase, { "MouseEnter", "MouseLeave", "InputBegan", "InputEnded", "InputChanged", "MouseMoved" }, nil, {
	readonly = { AbsoluteSize = Vector2.new(100, 100), AbsolutePosition = Vector2.zero, AbsoluteRotation = 0 },
})
class("Frame", "GuiObject", { Style = E("FrameStyle", "Custom") })
class("CanvasGroup", "GuiObject", { GroupTransparency = 0, GroupColor3 = Color3.new(1, 1, 1) })
local textProps = {
	Text = "Label",
	TextColor3 = Color3.fromRGB(27, 42, 53),
	TextSize = 14,
	Font = E("Font", "Legacy"),
	FontFace = ANY,
	TextScaled = false,
	TextWrapped = false,
	TextXAlignment = E("TextXAlignment", "Center"),
	TextYAlignment = E("TextYAlignment", "Center"),
	TextStrokeTransparency = 1,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextTransparency = 0,
	RichText = false,
	LineHeight = 1,
	MaxVisibleGraphemes = -1,
	TextTruncate = E("TextTruncate", "None"),
	TextDirection = E("TextDirection", "Auto"),
}
local function merge(a, b)
	local out = {}
	for k, v in pairs(a) do
		out[k] = v
	end
	for k, v in pairs(b or {}) do
		out[k] = v
	end
	return out
end
local buttonProps = { AutoButtonColor = true, Modal = false, Selected = false, Style = E("ButtonStyle", "Custom") }
local buttonEvents = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click" }
class("TextLabel", "GuiObject", textProps, nil, nil, { readonly = { TextBounds = Vector2.new(50, 14), TextFits = true } })
class("TextButton", "GuiObject", merge(textProps, buttonProps), buttonEvents, nil, { readonly = { TextBounds = Vector2.new(50, 14) } })
class("TextBox", "GuiObject", merge(textProps, { PlaceholderText = "", PlaceholderColor3 = Color3.new(0.7, 0.7, 0.7), ClearTextOnFocus = true, MultiLine = false, TextEditable = true }), { "FocusLost", "Focused" }, {
	CaptureFocus = function() end,
	ReleaseFocus = function() end,
	IsFocused = function()
		return false
	end,
})
local imageProps = {
	Image = "",
	ImageColor3 = Color3.new(1, 1, 1),
	ImageTransparency = 0,
	ScaleType = E("ScaleType", "Stretch"),
	SliceCenter = D.Rect.new(0, 0, 0, 0),
	SliceScale = 1,
	ImageRectOffset = Vector2.zero,
	ImageRectSize = Vector2.zero,
	TileSize = UDim2.new(1, 0, 1, 0),
	ResampleMode = E("ResamplerMode", "Default"),
}
class("ImageLabel", "GuiObject", imageProps)
class("ImageButton", "GuiObject", merge(merge(imageProps, buttonProps), { HoverImage = "", PressedImage = "" }), buttonEvents)
class("ScrollingFrame", "GuiObject", {
	CanvasSize = UDim2.new(0, 0, 2, 0),
	CanvasPosition = Vector2.zero,
	ScrollBarThickness = 12,
	ScrollBarImageColor3 = Color3.new(1, 1, 1),
	ScrollBarImageTransparency = 0,
	AutomaticCanvasSize = E("AutomaticSize", "None"),
	ScrollingDirection = E("ScrollingDirection", "XY"),
	ScrollingEnabled = true,
	ElasticBehavior = E("ElasticBehavior", "WhenScrollable"),
	VerticalScrollBarInset = E("ScrollBarInset", "None"),
	HorizontalScrollBarInset = E("ScrollBarInset", "None"),
	TopImage = "",
	MidImage = "",
	BottomImage = "",
}, nil, nil, { readonly = { AbsoluteCanvasSize = Vector2.new(100, 200), AbsoluteWindowSize = Vector2.new(100, 100) } })
class("ViewportFrame", "GuiObject", {
	CurrentCamera = NIL,
	Ambient = Color3.fromRGB(200, 200, 200),
	LightColor = Color3.fromRGB(140, 140, 140),
	LightDirection = Vector3.new(-1, -1, -1),
	ImageColor3 = Color3.new(1, 1, 1),
	ImageTransparency = 0,
})

local layerProps = { Enabled = true, ResetOnSpawn = true, ZIndexBehavior = E("ZIndexBehavior", "Global") }
class("LayerCollector", "GuiBase2d", layerProps)
class("ScreenGui", "LayerCollector", {
	DisplayOrder = 0,
	IgnoreGuiInset = false,
	ScreenInsets = E("ScreenInsets", "CoreUISafeInsets"),
	SafeAreaCompatibility = E("SafeAreaCompatibility", "FullscreenExtension"),
	ClipToDeviceSafeArea = true,
}, nil, nil, { readonly = { AbsoluteSize = Vector2.new(1280, 720) } })
class("BillboardGui", "LayerCollector", {
	Adornee = NIL,
	Size = UDim2.new(0, 100, 0, 50),
	SizeOffset = Vector2.zero,
	StudsOffset = Vector3.zero,
	StudsOffsetWorldSpace = Vector3.zero,
	ExtentsOffset = Vector3.zero,
	ExtentsOffsetWorldSpace = Vector3.zero,
	AlwaysOnTop = false,
	MaxDistance = math.huge,
	LightInfluence = 0,
	Brightness = 1,
	ClipsDescendants = false,
	Active = false,
	DistanceLowerLimit = 0,
	DistanceUpperLimit = -1,
	DistanceStep = 0,
	PlayerToHideFrom = NIL,
})
class("SurfaceGui", "LayerCollector", {
	Adornee = NIL,
	Face = E("NormalId", "Front"),
	SizingMode = E("SurfaceGuiSizingMode", "FixedSize"),
	PixelsPerStud = 50,
	CanvasSize = Vector2.new(800, 600),
	LightInfluence = 1,
	Brightness = 1,
	AlwaysOnTop = false,
	ZOffset = 0,
	ClipsDescendants = true,
	Active = true,
	MaxDistance = 1000,
})
class("UIBase", "Instance")
class("UIComponent", "UIBase")
class("UICorner", "UIComponent", { CornerRadius = UDim.new(0, 8) })
class("UIStroke", "UIComponent", {
	Color = Color3.new(0, 0, 0),
	Thickness = 1,
	Transparency = 0,
	Enabled = true,
	ApplyStrokeMode = E("ApplyStrokeMode", "Contextual"),
	LineJoinMode = E("LineJoinMode", "Round"),
})
class("UIGradient", "UIComponent", { Color = ANY, Transparency = ANY, Rotation = 0, Offset = Vector2.zero, Enabled = true })
class("UIPadding", "UIComponent", {
	PaddingTop = UDim.new(0, 0),
	PaddingBottom = UDim.new(0, 0),
	PaddingLeft = UDim.new(0, 0),
	PaddingRight = UDim.new(0, 0),
})
class("UIScale", "UIComponent", { Scale = 1 })
class("UIConstraint", "UIComponent")
class("UIAspectRatioConstraint", "UIConstraint", {
	AspectRatio = 1,
	AspectType = E("AspectType", "FitWithinMaxSize"),
	DominantAxis = E("DominantAxis", "Width"),
})
class("UISizeConstraint", "UIConstraint", { MinSize = Vector2.zero, MaxSize = Vector2.new(math.huge, math.huge) })
class("UITextSizeConstraint", "UIConstraint", { MaxTextSize = 100, MinTextSize = 1 })
class("UIFlexItem", "UIComponent", { FlexMode = E("UIFlexMode", "None"), GrowRatio = 0, ShrinkRatio = 0 })
local layoutBase = {
	FillDirection = E("FillDirection", "Vertical"),
	HorizontalAlignment = E("HorizontalAlignment", "Left"),
	VerticalAlignment = E("VerticalAlignment", "Top"),
	SortOrder = E("SortOrder", "Name"),
}
class("UILayout", "UIComponent")
class("UIGridStyleLayout", "UILayout", layoutBase, nil, nil, { readonly = { AbsoluteContentSize = Vector2.new(100, 100) } })
class("UIListLayout", "UIGridStyleLayout", {
	Padding = UDim.new(0, 0),
	Wraps = false,
	HorizontalFlex = E("UIFlexAlignment", "None"),
	VerticalFlex = E("UIFlexAlignment", "None"),
	ItemLineAlignment = E("ItemLineAlignment", "Automatic"),
})
class("UIGridLayout", "UIGridStyleLayout", {
	CellSize = UDim2.new(0, 100, 0, 100),
	CellPadding = UDim2.new(0, 5, 0, 5),
	FillDirectionMaxCells = 0,
	StartCorner = E("StartCorner", "TopLeft"),
})
class("UIPageLayout", "UIGridStyleLayout")

-- player-side containers
class("Player", "Instance", {
	DisplayName = "",
	UserId = 0,
	Character = NIL,
	Team = NIL,
	Neutral = true,
	AccountAge = 30,
	RespawnLocation = NIL,
	CameraMaxZoomDistance = 128,
	CameraMinZoomDistance = 0.5,
	MembershipType = E("MembershipType", "None"),
	ReplicationFocus = NIL,
	AutoJumpEnabled = true,
	HealthDisplayDistance = 100,
	NameDisplayDistance = 100,
}, { "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "Chatted", "Idled" })
class("PlayerGui", "Instance", { SelectionImageObject = NIL, ScreenOrientation = E("ScreenOrientation", "LandscapeSensor") })
class("Backpack", "Instance")
class("PlayerScripts", "Instance")
class("StarterGear", "Instance")
class("Tool", "Model", { RequiresHandle = true, CanBeDropped = true, ToolTip = "", Enabled = true, TextureId = "" }, { "Activated", "Equipped", "Unequipped" })
class("Tween", "Instance", { PlaybackState = E("PlaybackState", "Begin") }, { "Completed" })

---------------------------------------------------------------------------
-- Instance implementation
---------------------------------------------------------------------------
local state = setmetatable({}, { __mode = "k" })
M.state = state
local InstMt = { __type = "Instance" }
M.InstMt = InstMt

local function isInstance(v)
	return getmetatable(v) == InstMt
end
M.isInstance = isInstance

local function classChain(className)
	local chain = {}
	local c = Classes[className]
	while c do
		table.insert(chain, c)
		c = c.super and Classes[c.super]
	end
	return chain
end

local function lookupProp(st, key)
	for _, c in ipairs(st.chain) do
		local v = c.props[key]
		if v ~= nil then
			return true, v
		end
	end
	return false, nil
end

local function lookupReadonly(st, key)
	for _, c in ipairs(st.chain) do
		if c.opts.readonly and c.opts.readonly[key] ~= nil then
			return true, c.opts.readonly[key]
		end
	end
	return false, nil
end

local function hasEvent(st, key)
	for _, c in ipairs(st.chain) do
		for _, e in ipairs(c.events) do
			if e == key then
				return true
			end
		end
	end
	return false
end

local function classMethod(st, key)
	for _, c in ipairs(st.chain) do
		local m = c.methods[key]
		if m then
			return m
		end
	end
	return nil
end

local function fullName(inst)
	local parts = {}
	local cur = inst
	while cur do
		local st = state[cur]
		table.insert(parts, 1, st.props.Name)
		cur = st.parent
	end
	return table.concat(parts, ".")
end
M.fullName = fullName

local function signal(st, name)
	local s = st.signals[name]
	if not s then
		s = Signal.new(name)
		st.signals[name] = s
	end
	return s
end

local function propChanged(inst, st, key)
	local s = st.propSignals[key]
	if s then
		s:Fire()
	end
	local c = st.signals.Changed
	if c then
		c:Fire(key)
	end
end

local function descendantsOf(inst, out)
	for _, ch in ipairs(state[inst].children) do
		table.insert(out, ch)
		descendantsOf(ch, out)
	end
	return out
end

local function ancestorsOf(inst)
	local out = {}
	local p = state[inst].parent
	while p do
		table.insert(out, p)
		p = state[p].parent
	end
	return out
end

local function setParent(inst, newParent)
	local st = state[inst]
	if st.destroyed then
		error("The Parent property of " .. st.props.Name .. " is locked, current parent: NULL, new parent " .. tostring(newParent and state[newParent].props.Name), 3)
	end
	if newParent ~= nil and not isInstance(newParent) then
		error("Parent must be an Instance", 3)
	end
	if newParent == st.parent then
		return
	end
	if newParent then
		-- prevent cycles
		local p = newParent
		while p do
			if p == inst then
				error("Attempt to set parent of " .. st.props.Name .. " to a descendant", 3)
			end
			p = state[p].parent
		end
	end
	local old = st.parent
	if old then
		local ost = state[old]
		for i, ch in ipairs(ost.children) do
			if ch == inst then
				table.remove(ost.children, i)
				break
			end
		end
		if ost.signals.ChildRemoved then
			ost.signals.ChildRemoved:Fire(inst)
		end
		local anc = { old }
		for _, a in ipairs(ancestorsOf(old)) do
			table.insert(anc, a)
		end
		for _, a in ipairs(anc) do
			local s = state[a].signals.DescendantRemoving
			if s then
				s:Fire(inst)
			end
		end
	end
	st.parent = newParent
	if newParent then
		table.insert(state[newParent].children, inst)
		local nst = state[newParent]
		if nst.signals.ChildAdded then
			nst.signals.ChildAdded:Fire(inst)
		end
		local anc = { newParent }
		for _, a in ipairs(ancestorsOf(newParent)) do
			table.insert(anc, a)
		end
		local added = { inst }
		descendantsOf(inst, added)
		for _, a in ipairs(anc) do
			local s = state[a].signals.DescendantAdded
			if s then
				for _, d in ipairs(added) do
					s:Fire(d)
				end
			end
		end
		if M.onDescendantAdded then
			for _, d in ipairs(added) do
				M.onDescendantAdded(d)
			end
		end
	end
	if st.signals.AncestryChanged then
		st.signals.AncestryChanged:Fire(inst, newParent)
	end
	propChanged(inst, st, "Parent")
end

local typeCheckSkip = { [ANY] = true }

local function checkType(st, key, default, value)
	if typeCheckSkip[default] then
		return
	end
	if default == NIL then
		if value ~= nil and not isInstance(value) and typeof(value) ~= "function" then
			-- NIL-default props hold Instances (Adornee, Part0, ...) or callbacks
			if key ~= "CustomPhysicalProperties" then
				error(string.format("Unable to assign property %s. Instance expected, got %s", key, typeof(value)), 4)
			end
		end
		return
	end
	if value == nil then
		error(string.format("Unable to assign property %s. %s expected, got nil", key, typeof(default)), 4)
	end
	local dt, vt = typeof(default), typeof(value)
	if dt == "number" and vt == "number" then
		if value ~= value then
			error("Unable to assign property " .. key .. ". NaN", 4)
		end
		return
	end
	if dt ~= vt then
		-- Roblox coerces numbers <-> booleans? No. Strings for numbers? also no.
		error(string.format("Unable to assign property %s. %s expected, got %s", key, dt, vt), 4)
	end
	if dt == "EnumItem" and default.EnumType ~= value.EnumType then
		error(string.format("Unable to assign property %s. Enum.%s expected, got Enum.%s", key, default.EnumType, value.EnumType), 4)
	end
end

local Methods = {}
M.Methods = Methods

function Methods.GetChildren(self)
	local out = {}
	for i, c in ipairs(state[self].children) do
		out[i] = c
	end
	return out
end
function Methods.GetDescendants(self)
	return descendantsOf(self, {})
end
function Methods.FindFirstChild(self, name, recursive)
	for _, c in ipairs(state[self].children) do
		if state[c].props.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in ipairs(state[self].children) do
			local f = Methods.FindFirstChild(c, name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function Methods.FindFirstChildOfClass(self, cn)
	for _, c in ipairs(state[self].children) do
		if state[c].className == cn then
			return c
		end
	end
	return nil
end
function Methods.FindFirstChildWhichIsA(self, cn, recursive)
	for _, c in ipairs(state[self].children) do
		if Methods.IsA(c, cn) then
			return c
		end
	end
	if recursive then
		for _, c in ipairs(state[self].children) do
			local f = Methods.FindFirstChildWhichIsA(c, cn, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function Methods.FindFirstAncestor(self, name)
	for _, a in ipairs(ancestorsOf(self)) do
		if state[a].props.Name == name then
			return a
		end
	end
	return nil
end
function Methods.FindFirstAncestorOfClass(self, cn)
	for _, a in ipairs(ancestorsOf(self)) do
		if state[a].className == cn then
			return a
		end
	end
	return nil
end
function Methods.FindFirstAncestorWhichIsA(self, cn)
	for _, a in ipairs(ancestorsOf(self)) do
		if Methods.IsA(a, cn) then
			return a
		end
	end
	return nil
end
function Methods.FindFirstDescendant(self, name)
	for _, d in ipairs(descendantsOf(self, {})) do
		if state[d].props.Name == name then
			return d
		end
	end
	return nil
end
function Methods.WaitForChild(self, name, timeout)
	local c = Methods.FindFirstChild(self, name)
	if c then
		return c
	end
	-- yield until it appears (or timeout)
	local deadline = timeout and (M.scheduler.now() + timeout)
	while true do
		c = Methods.FindFirstChild(self, name)
		if c then
			return c
		end
		if deadline and M.scheduler.now() >= deadline then
			return nil
		end
		if not coroutine.isyieldable() then
			error("WaitForChild(" .. tostring(name) .. ") on " .. fullName(self) .. " would yield forever", 2)
		end
		M.scheduler.wait(0.03)
		if M.scheduler.now() > 120 and not deadline then
			-- infinite yield guard
			table.insert(M.errors, "Infinite yield possible on WaitForChild(" .. tostring(name) .. ") on " .. fullName(self))
			deadline = M.scheduler.now() + 0
		end
	end
end
function Methods.IsA(self, cn)
	for _, c in ipairs(state[self].chain) do
		if c.name == cn then
			return true
		end
	end
	return false
end
function Methods.IsDescendantOf(self, other)
	for _, a in ipairs(ancestorsOf(self)) do
		if a == other then
			return true
		end
	end
	return false
end
function Methods.IsAncestorOf(self, other)
	return Methods.IsDescendantOf(other, self)
end
function Methods.GetFullName(self)
	return fullName(self)
end
function Methods.Destroy(self)
	local st = state[self]
	if st.destroyed then
		return
	end
	if st.signals.Destroying then
		st.signals.Destroying:Fire()
	end
	for _, c in ipairs(Methods.GetChildren(self)) do
		Methods.Destroy(c)
	end
	if st.parent then
		setParent(self, nil)
	end
	st.destroyed = true
	for _, s in pairs(st.signals) do
		s:DisconnectAll()
	end
end
Methods.Remove = Methods.Destroy
function Methods.ClearAllChildren(self)
	for _, c in ipairs(Methods.GetChildren(self)) do
		Methods.Destroy(c)
	end
end
function Methods.Clone(self)
	local st = state[self]
	if not st.props.Archivable then
		return nil
	end
	local copy = M.new(st.className)
	local cst = state[copy]
	for k, v in pairs(st.props) do
		cst.props[k] = v
	end
	for k, v in pairs(st.attrs) do
		cst.attrs[k] = v
	end
	for k in pairs(st.tags) do
		cst.tags[k] = true
	end
	cst.source = st.source
	cst.path = st.path
	for _, c in ipairs(st.children) do
		local cc = Methods.Clone(c)
		if cc then
			setParent(cc, copy)
		end
	end
	return copy
end
local validAttrTypes = {
	string = true,
	number = true,
	boolean = true,
	Vector3 = true,
	Vector2 = true,
	Color3 = true,
	UDim = true,
	UDim2 = true,
	CFrame = true,
	NumberRange = true,
	NumberSequence = true,
	ColorSequence = true,
	EnumItem = true,
	BrickColor = true,
	Rect = true,
	Font = true,
}
function Methods.SetAttribute(self, name, value)
	if type(name) ~= "string" then
		error("Attribute name must be a string", 2)
	end
	if value ~= nil and not validAttrTypes[typeof(value)] then
		error("Attribute type " .. typeof(value) .. " not supported (" .. name .. ")", 2)
	end
	if type(value) == "number" and value ~= value then
		error("Attribute " .. name .. " is NaN", 2)
	end
	local st = state[self]
	local old = st.attrs[name]
	st.attrs[name] = value
	if old ~= value then
		local s = st.attrSignals[name]
		if s then
			s:Fire()
		end
		if st.signals.AttributeChanged then
			st.signals.AttributeChanged:Fire(name)
		end
	end
end
function Methods.GetAttribute(self, name)
	return state[self].attrs[name]
end
function Methods.GetAttributes(self)
	local out = {}
	for k, v in pairs(state[self].attrs) do
		out[k] = v
	end
	return out
end
function Methods.GetAttributeChangedSignal(self, name)
	local st = state[self]
	local s = st.attrSignals[name]
	if not s then
		s = Signal.new("AttributeChanged:" .. name)
		st.attrSignals[name] = s
	end
	return s
end
function Methods.GetPropertyChangedSignal(self, prop)
	local st = state[self]
	local known = prop == "Name" or prop == "Parent" or lookupProp(st, prop) or lookupReadonly(st, prop)
	if not known then
		error(prop .. " is not a valid property name.", 2)
	end
	local s = st.propSignals[prop]
	if not s then
		s = Signal.new("PropertyChanged:" .. prop)
		st.propSignals[prop] = s
	end
	return s
end
function Methods.AddTag(self, tag)
	state[self].tags[tag] = true
	if M.onTagAdded then
		M.onTagAdded(self, tag)
	end
end
function Methods.RemoveTag(self, tag)
	state[self].tags[tag] = nil
end
function Methods.HasTag(self, tag)
	return state[self].tags[tag] == true
end
function Methods.GetTags(self)
	local out = {}
	for t in pairs(state[self].tags) do
		table.insert(out, t)
	end
	return out
end
function Methods.GetActor()
	return nil
end

-- PVInstance / BasePart / Model geometry --------------------------------------
local function partsOf(inst)
	local out = {}
	if Methods.IsA(inst, "BasePart") then
		table.insert(out, inst)
	end
	for _, d in ipairs(descendantsOf(inst, {})) do
		if Methods.IsA(d, "BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function boundingBox(inst)
	local parts = partsOf(inst)
	if #parts == 0 then
		return CFrame.identity, Vector3.zero
	end
	local minV, maxV
	for _, p in ipairs(parts) do
		local pst = state[p]
		local pos = pst.props.CFrame.Position
		local half = pst.props.Size / 2
		local lo, hi = pos - half, pos + half
		minV = minV and minV:Min(lo) or lo
		maxV = maxV and maxV:Max(hi) or hi
	end
	return CFrame.new((minV + maxV) / 2), maxV - minV
end

function Methods.GetPivot(self)
	local st = state[self]
	if Methods.IsA(self, "BasePart") then
		return st.props.CFrame * st.props.PivotOffset
	end
	if st.className == "Camera" then
		return st.props.CFrame
	end
	local pp = st.props.PrimaryPart
	if pp ~= NIL and pp ~= nil then
		return state[pp].props.CFrame
	end
	if st.pivotSet then
		return st.props.WorldPivot
	end
	local cf = boundingBox(self)
	return cf
end
function Methods.PivotTo(self, target)
	if D.typeof(target) ~= "CFrame" then
		error("PivotTo expects a CFrame", 2)
	end
	local st = state[self]
	if Methods.IsA(self, "BasePart") then
		M.setProp(self, "CFrame", target * st.props.PivotOffset:Inverse())
		return
	end
	local current = Methods.GetPivot(self)
	local delta = target * current:Inverse()
	for _, p in ipairs(partsOf(self)) do
		M.setProp(p, "CFrame", delta * state[p].props.CFrame)
	end
	st.props.WorldPivot = target
	st.pivotSet = true
end
function Methods.SetPrimaryPartCFrame(self, cf)
	Methods.PivotTo(self, cf)
end
function Methods.GetPrimaryPartCFrame(self)
	return Methods.GetPivot(self)
end
function Methods.GetBoundingBox(self)
	return boundingBox(self)
end
function Methods.GetExtentsSize(self)
	local _, size = boundingBox(self)
	return size
end
function Methods.MoveTo(self, pos)
	if Methods.IsA(self, "Humanoid") then
		state[self].props.WalkToPoint = pos
		return
	end
	local cur = Methods.GetPivot(self)
	Methods.PivotTo(self, cur.Rotation + pos)
end
function Methods.TranslateBy(self, v)
	Methods.PivotTo(self, Methods.GetPivot(self) + v)
end
function Methods.ScaleTo(self, s)
	if type(s) ~= "number" or s <= 0 then
		error("ScaleTo expects a positive number", 2)
	end
	local st = state[self]
	local factor = s / (st.scale or 1)
	st.scale = s
	if factor == 1 then
		return
	end
	local pivot = Methods.GetPivot(self)
	for _, p in ipairs(partsOf(self)) do
		local pst = state[p]
		local rel = pivot:ToObjectSpace(pst.props.CFrame)
		local relPos = rel.Position * factor
		M.setProp(p, "CFrame", pivot * (rel.Rotation + relPos))
		M.setProp(p, "Size", pst.props.Size * factor)
	end
end
function Methods.GetScale(self)
	return state[self].scale or 1
end
function Methods.GetMass(self)
	local s = state[self].props.Size
	return s.X * s.Y * s.Z * 0.7
end
function Methods.GetTouchingParts()
	return {}
end
function Methods.ApplyImpulse(self, v)
	local st = state[self]
	st.props.AssemblyLinearVelocity = st.props.AssemblyLinearVelocity + v / math.max(1, Methods.GetMass(self))
end
function Methods.ApplyAngularImpulse() end
function Methods.SetNetworkOwner(self, owner)
	state[self].networkOwner = owner
end
function Methods.GetNetworkOwner(self)
	return state[self].networkOwner
end
function Methods.SetNetworkOwnershipAuto() end
function Methods.CanSetNetworkOwnership()
	return true
end
function Methods.BreakJoints() end
function Methods.GetConnectedParts(self)
	return { self }
end
function Methods.GetRootPart(self)
	return self
end

-- Humanoid
function Methods.TakeDamage(self, amount)
	local st = state[self]
	M.setProp(self, "Health", math.max(0, st.props.Health - amount))
end
function Methods.ChangeState(self, s)
	local st = state[self]
	st.humState = s
	if s == Enum.HumanoidStateType.Dead then
		M.setProp(self, "Health", 0)
	end
end
function Methods.GetState(self)
	return state[self].humState or Enum.HumanoidStateType.Running
end
function Methods.SetStateEnabled() end
function Methods.GetStateEnabled()
	return true
end
function Methods.Move() end
function Methods.UnequipTools() end
function Methods.GetPlayingAnimationTracks()
	return {}
end
function Methods.LoadAnimation()
	return { Play = function() end, Stop = function() end, AdjustSpeed = function() end, Looped = false }
end
function Methods.GetAppliedDescription()
	return M.new("HumanoidDescription")
end

-- Tween
function Methods.Play(self)
	local st = state[self]
	if st.className == "Tween" then
		M.scheduler.playTween(self)
	elseif st.className == "Sound" then
		M.setProp(self, "Playing", true)
	end
end
function Methods.Cancel(self)
	state[self].cancelled = true
end
function Methods.Pause(self)
	if state[self].className == "Sound" then
		M.setProp(self, "Playing", false)
	end
end

local methodNames = {}
for k in pairs(Methods) do
	methodNames[k] = true
end

-- instance-specific: only expose geometry/humanoid methods on the right classes
local restricted = {
	GetPivot = "PVInstance",
	PivotTo = "PVInstance",
	SetPrimaryPartCFrame = "Model",
	GetPrimaryPartCFrame = "Model",
	GetBoundingBox = "Model",
	GetExtentsSize = "Model",
	TranslateBy = "Model",
	ScaleTo = "Model",
	GetScale = "Model",
	GetMass = "BasePart",
	GetTouchingParts = "BasePart",
	ApplyImpulse = "BasePart",
	ApplyAngularImpulse = "BasePart",
	SetNetworkOwner = "BasePart",
	GetNetworkOwner = "BasePart",
	SetNetworkOwnershipAuto = "BasePart",
	CanSetNetworkOwnership = "BasePart",
	BreakJoints = "PVInstance",
	GetConnectedParts = "BasePart",
	GetRootPart = "BasePart",
	TakeDamage = "Humanoid",
	ChangeState = "Humanoid",
	GetState = "Humanoid",
	SetStateEnabled = "Humanoid",
	GetStateEnabled = "Humanoid",
	Move = "Humanoid",
	UnequipTools = "Humanoid",
	GetPlayingAnimationTracks = "Humanoid",
	LoadAnimation = "Humanoid",
	GetAppliedDescription = "Humanoid",
	Play = "Instance",
	Cancel = "Tween",
	Pause = "Instance",
}

-- property get/set with derived properties -----------------------------------
local derivedGet = {}
local derivedSet = {}

derivedGet.Position = function(inst, st)
	if Methods.IsA(inst, "BasePart") or st.className == "Attachment" then
		return st.props.CFrame.Position
	end
	return nil
end
derivedSet.Position = function(inst, st, v)
	if Methods.IsA(inst, "BasePart") or st.className == "Attachment" then
		if typeof(v) ~= "Vector3" then
			error("Unable to assign property Position. Vector3 expected, got " .. typeof(v), 4)
		end
		local c = st.props.CFrame
		M.setProp(inst, "CFrame", c.Rotation + v)
		return true
	end
	return false
end
local function orientationOf(c)
	local x, y, z = c:ToEulerAnglesYXZ()
	return Vector3.new(math.deg(x), math.deg(y), math.deg(z))
end
derivedGet.Orientation = function(inst, st)
	if Methods.IsA(inst, "BasePart") or st.className == "Attachment" then
		return orientationOf(st.props.CFrame)
	end
	return nil
end
derivedSet.Orientation = function(inst, st, v)
	if Methods.IsA(inst, "BasePart") or st.className == "Attachment" then
		if typeof(v) ~= "Vector3" then
			error("Unable to assign property Orientation. Vector3 expected, got " .. typeof(v), 4)
		end
		local pos = st.props.CFrame.Position
		M.setProp(inst, "CFrame", CFrame.new(pos) * CFrame.fromOrientation(math.rad(v.X), math.rad(v.Y), math.rad(v.Z)))
		return true
	end
	return false
end
derivedGet.Rotation = function(inst, st)
	if Methods.IsA(inst, "BasePart") then
		local x, y, z = st.props.CFrame:ToEulerAnglesXYZ()
		return Vector3.new(math.deg(x), math.deg(y), math.deg(z))
	end
	return nil
end
derivedGet.WorldPosition = function(inst, st)
	if st.className == "Attachment" then
		local p = st.parent
		if p and Methods.IsA(p, "BasePart") then
			return (state[p].props.CFrame * st.props.CFrame).Position
		end
		return st.props.CFrame.Position
	end
	return nil
end
derivedGet.WorldCFrame = function(inst, st)
	if st.className == "Attachment" then
		local p = st.parent
		if p and Methods.IsA(p, "BasePart") then
			return state[p].props.CFrame * st.props.CFrame
		end
		return st.props.CFrame
	end
	return nil
end
derivedGet.AssemblyMass = function(inst, st)
	if Methods.IsA(inst, "BasePart") then
		return Methods.GetMass(inst)
	end
	return nil
end
derivedGet.Mass = derivedGet.AssemblyMass
derivedGet.ClassName = function(inst, st)
	return st.className
end
derivedGet.Name = function(inst, st)
	return st.props.Name
end
derivedGet.Parent = function(inst, st)
	return st.parent
end
-- Players: LocalPlayer handled by service

function M.setProp(inst, key, value)
	local st = state[inst]
	st.props[key] = value
	propChanged(inst, st, key)
end

InstMt.__index = function(inst, key)
	local st = state[inst]
	if st == nil then
		error("bad instance", 2)
	end
	-- explicit per-instance overrides (services)
	local ov = st.overrides and st.overrides[key]
	if ov ~= nil then
		return ov
	end
	if key == "Name" then
		return st.props.Name
	elseif key == "Parent" then
		return st.parent
	elseif key == "ClassName" then
		return st.className
	end
	local cm = classMethod(st, key)
	if cm then
		return cm
	end
	if methodNames[key] then
		local need = restricted[key]
		if not need or Methods.IsA(inst, need) then
			return Methods[key]
		end
	end
	if derivedGet[key] then
		local v = derivedGet[key](inst, st)
		if v ~= nil then
			return v
		end
	end
	local found, default = lookupProp(st, key)
	if found then
		local v = st.props[key]
		if v == NIL then
			return nil
		end
		if v == ANY then
			return nil
		end
		return v
	end
	local ro, rv = lookupReadonly(st, key)
	if ro then
		return rv
	end
	if hasEvent(st, key) then
		return signal(st, key)
	end
	local child = Methods.FindFirstChild(inst, key)
	if child then
		return child
	end
	error(tostring(key) .. " is not a valid member of " .. st.className .. ' "' .. fullName(inst) .. '"', 2)
end

InstMt.__newindex = function(inst, key, value)
	local st = state[inst]
	if st.locked and st.locked[key] then
		error("Cannot set " .. key .. " on " .. st.className, 2)
	end
	if key == "Parent" then
		setParent(inst, value)
		return
	end
	if key == "Name" then
		if type(value) ~= "string" then
			error("Name must be a string", 2)
		end
		st.props.Name = value
		propChanged(inst, st, "Name")
		return
	end
	if st.overrides and st.overrides[key] ~= nil and st.writableOverrides and st.writableOverrides[key] then
		st.overrides[key] = value
		return
	end
	if derivedSet[key] and derivedSet[key](inst, st, value) then
		return
	end
	local found, default = lookupProp(st, key)
	if not found then
		local ro = lookupReadonly(st, key)
		if ro then
			error("Unable to assign property " .. key .. ". Property is read only", 2)
		end
		error(tostring(key) .. " is not a valid member of " .. st.className .. ' "' .. fullName(inst) .. '"', 2)
	end
	checkType(st, key, default, value)
	if key == "PrimaryPart" and value ~= nil and not Methods.IsDescendantOf(value, inst) then
		-- Roblox silently ignores invalid PrimaryPart, but it's always a bug.
		error("PrimaryPart must be a descendant of the model", 2)
	end
	if key == "WorldPivot" then
		st.pivotSet = true
	end
	st.props[key] = (value == nil) and NIL or value
	propChanged(inst, st, key)
	-- Real engine coupling (verified in Studio): TextScaled = true forces TextWrapped = true,
	-- and TextWrapped = false forces TextScaled = false.
	if key == "TextScaled" and value == true then
		st.props.TextWrapped = true
	elseif key == "TextWrapped" and value == false then
		st.props.TextScaled = false
	end
	if key == "Health" and st.className == "Humanoid" and value <= 0 and not st.died then
		st.died = true
		signal(st, "Died"):Fire()
	end
end

InstMt.__tostring = function(inst)
	return state[inst].props.Name
end
InstMt.__eq = rawequal

function M.new(className, parent)
	local c = Classes[className]
	if not c or c.opts.abstract then
		error('Unable to create an Instance of type "' .. tostring(className) .. '"', 2)
	end
	local inst = setmetatable({}, InstMt)
	local st = {
		className = className,
		chain = classChain(className),
		props = { Name = className },
		children = {},
		parent = nil,
		attrs = {},
		attrSignals = {},
		propSignals = {},
		signals = {},
		tags = {},
		destroyed = false,
	}
	for _, cl in ipairs(st.chain) do
		for k, v in pairs(cl.props) do
			if st.props[k] == nil then
				st.props[k] = v
			end
		end
	end
	state[inst] = st
	if M.onCreated then
		M.onCreated(inst)
	end
	if parent then
		setParent(inst, parent)
	end
	return inst
end

local abstract = {
	"Instance",
	"PVInstance",
	"BasePart",
	"FormFactorPart",
	"GuiBase2d",
	"GuiObject",
	"LayerCollector",
	"UIBase",
	"UIComponent",
	"UIConstraint",
	"UILayout",
	"UIGridStyleLayout",
	"Light",
	"PostEffect",
	"ValueBase",
	"LuaSourceContainer",
	"BaseScript",
	"Constraint",
	"JointInstance",
	"WorldRoot",
	"Workspace",
	"Terrain",
	"Player",
	"PlayerGui",
	"Backpack",
	"PlayerScripts",
}
for _, n in ipairs(abstract) do
	Classes[n].opts.abstract = true
end

-- internal constructor that bypasses abstract checks (for services)
function M.newInternal(className, name)
	local was = Classes[className].opts.abstract
	Classes[className].opts.abstract = false
	local inst = M.new(className)
	Classes[className].opts.abstract = was
	if name then
		state[inst].props.Name = name
	end
	return inst
end

function M.defineService(name, props, events, methods, super)
	if not Classes[name] then
		class(name, super or "Instance", props, events, methods)
	end
	return M.newInternal(name, name)
end

return M
