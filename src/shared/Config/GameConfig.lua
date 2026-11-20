--[[
	GameConfig — single source of truth for content and balance.

	Pure data (no Roblox types) so it can be loaded by the headless test runner.
	Colors are {r, g, b} 0-255 arrays; use Util.rgb() to convert on the Roblox side.

	NOTE: all project Lua is written in the common subset of Luau and Lua 5.4
	(no compound assignment, no `continue`, no type annotations, no backtick strings)
	so every file can be parsed and unit-tested headlessly.
]]

local GameConfig = {}

GameConfig.Version = "0.2.0"
GameConfig.MaxPlayers = 8

---------------------------------------------------------------------------
-- Rarities
---------------------------------------------------------------------------
GameConfig.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Chaos" }

GameConfig.Rarities = {
	Common = { rank = 1, color = { 196, 202, 208 }, incomeMult = 1, weight = 1.0, incubate = 15 },
	Uncommon = { rank = 2, color = { 92, 214, 92 }, incomeMult = 1.6, weight = 1.2, incubate = 30 },
	Rare = { rank = 3, color = { 60, 150, 255 }, incomeMult = 2.6, weight = 1.5, incubate = 60 },
	Epic = { rank = 4, color = { 176, 80, 255 }, incomeMult = 4.5, weight = 2.0, incubate = 120 },
	Legendary = { rank = 5, color = { 255, 176, 32 }, incomeMult = 8, weight = 2.5, incubate = 240 },
	Mythic = { rank = 6, color = { 255, 60, 110 }, incomeMult = 15, weight = 3.0, incubate = 480 },
	Chaos = { rank = 7, color = { 255, 40, 220 }, incomeMult = 30, weight = 3.5, incubate = 600 },
}

---------------------------------------------------------------------------
-- Mutations (rolled when a world core spawns, and again at hatch if none)
---------------------------------------------------------------------------
GameConfig.MutationOrder = { "Charged", "Frozen", "Molten", "Golden", "Corrupted" }

GameConfig.Mutations = {
	Charged = { mult = 1.5, chance = 0.06, color = { 255, 240, 80 } },
	Frozen = { mult = 2.0, chance = 0.035, color = { 150, 230, 255 } },
	Molten = { mult = 2.5, chance = 0.02, color = { 255, 110, 30 } },
	Golden = { mult = 3.0, chance = 0.01, color = { 255, 205, 40 } },
	Corrupted = { mult = 5.0, chance = 0.0035, color = { 130, 40, 200 } },
}

---------------------------------------------------------------------------
-- Speed
---------------------------------------------------------------------------
GameConfig.Speed = {
	BaseWalkSpeed = 16,
	WalkPerDoubling = 5, -- WalkSpeed = 16 + 5*log2(1 + S/250)
	WalkScale = 250,
	MaxWalkSpeed = 90,
	StepsPerSecond = 4, -- max server-counted treadmill steps per second
	BaseGainPerStep = 5,
	GainGrowth = 1.55, -- per treadmill level
	BeltSpeed = 14, -- conveyor push (studs/s) so the player runs in place
}

---------------------------------------------------------------------------
-- Carrying
---------------------------------------------------------------------------
GameConfig.Carry = {
	PenaltyPerWeight = 0.12,
	MinWalkMult = 0.45,
	TeleportSlack = 6, -- studs of slack per sample
	TeleportFactor = 1.6,
	PickupRange = 14,
	TagRange = 6, -- owner tagging a thief
	DeliveryGrace = 0.25,
}

---------------------------------------------------------------------------
-- World layout
---------------------------------------------------------------------------
GameConfig.World = {
	HubCenter = { 0, 0, -15 },
	HubSize = { 330, 390 }, -- x, z
	RouteStartZ = 200,
	ZoneLength = 260,
	ZoneWidth = 150,
	PathWidth = 26,
	GroundY = 0,
}

GameConfig.Bases = {
	Size = 72,
	-- base centers: left column faces +X, right column faces -X
	Slots = {
		{ x = -118, z = -150, face = 1 },
		{ x = -118, z = -60, face = 1 },
		{ x = -118, z = 30, face = 1 },
		{ x = -118, z = 120, face = 1 },
		{ x = 118, z = -150, face = -1 },
		{ x = 118, z = -60, face = -1 },
		{ x = 118, z = 30, face = -1 },
		{ x = 118, z = 120, face = -1 },
	},
	MaxPods = 8,
	MaxPedestals = 16,
	StartPods = 2,
	StartPedestals = 4,
	ShieldCooldown = 90,
	StealHoldTime = 1.6,
}

---------------------------------------------------------------------------
-- Zones (in route order)
---------------------------------------------------------------------------
GameConfig.Zones = {
	{
		id = "Suburb",
		name = "Suburb",
		speedReq = 0,
		baseIncome = 2,
		tagline = "Quiet streets. Loud skies.",
		guardian = { name = "Hedge Hound", kind = "Hound", speedFactor = 0.78 },
		rarityWeights = { Common = 62, Uncommon = 27, Rare = 9, Epic = 2 },
		cores = { "GustCore", "HailCore", "TornadoCore", "ThunderCore" },
		sky = { ambient = { 150, 150, 160 }, fog = { 190, 220, 255 }, fogEnd = 900, tint = { 255, 255, 255 }, clock = 14 },
	},
	{
		id = "Overgrowth",
		name = "Overgrowth",
		speedReq = 600,
		baseIncome = 6,
		tagline = "Nature fights back.",
		guardian = { name = "Vine Stalker", kind = "Stalker", speedFactor = 0.78 },
		rarityWeights = { Common = 60, Uncommon = 28, Rare = 10, Epic = 2 },
		cores = { "SporeCore", "ThornCore", "VineCore", "WildfireCore" },
		sky = { ambient = { 110, 150, 100 }, fog = { 140, 190, 120 }, fogEnd = 520, tint = { 235, 255, 225 }, clock = 13 },
	},
	{
		id = "Droughtlands",
		name = "Droughtlands",
		speedReq = 3000,
		baseIncome = 18,
		tagline = "Nothing grows. Everything cracks.",
		guardian = { name = "Dune Scorpion", kind = "Scorpion", speedFactor = 0.78 },
		rarityWeights = { Common = 58, Uncommon = 29, Rare = 10.5, Epic = 2.5 },
		cores = { "DustCore", "HeatwaveCore", "SinkholeCore", "EarthquakeCore" },
		sky = { ambient = { 190, 150, 110 }, fog = { 240, 200, 150 }, fogEnd = 700, tint = { 255, 235, 205 }, clock = 15.5 },
	},
	{
		id = "Frostfall",
		name = "Frostfall",
		speedReq = 12000,
		baseIncome = 50,
		tagline = "The cold bites back.",
		guardian = { name = "Frost Yeti", kind = "Yeti", speedFactor = 0.78 },
		rarityWeights = { Uncommon = 60, Rare = 28, Epic = 10, Legendary = 2 },
		cores = { "FrostCore", "AvalancheCore", "BlizzardCore", "GlacierCore" },
		sky = { ambient = { 150, 170, 200 }, fog = { 220, 235, 255 }, fogEnd = 380, tint = { 225, 240, 255 }, clock = 10 },
	},
	{
		id = "MagmaBasin",
		name = "Magma Basin",
		speedReq = 40000,
		baseIncome = 140,
		tagline = "The ground is the disaster.",
		guardian = { name = "Magma Wyrm", kind = "Wyrm", speedFactor = 0.78 },
		rarityWeights = { Uncommon = 58, Rare = 29, Epic = 10.5, Legendary = 2.5 },
		cores = { "AshCore", "EruptionCore", "MeteorCore", "InfernoCore" },
		sky = { ambient = { 150, 70, 50 }, fog = { 90, 40, 30 }, fogEnd = 420, tint = { 255, 215, 195 }, clock = 18.2 },
	},
	{
		id = "DeepAbyss",
		name = "Deep Abyss",
		speedReq = 120000,
		baseIncome = 400,
		tagline = "Pressure. Darkness. Waves.",
		guardian = { name = "Abyss Angler", kind = "Angler", speedFactor = 0.78 },
		rarityWeights = { Uncommon = 56, Rare = 30, Epic = 11, Legendary = 3 },
		cores = { "RiptideCore", "WhirlpoolCore", "TsunamiCore", "UndertowCore" },
		sky = { ambient = { 40, 90, 140 }, fog = { 10, 40, 80 }, fogEnd = 260, tint = { 190, 225, 255 }, clock = 20 },
	},
	{
		id = "Prehistoric",
		name = "Prehistoric",
		speedReq = 350000,
		baseIncome = 1100,
		tagline = "Extinction is on the menu.",
		guardian = { name = "Rex Warden", kind = "Rex", speedFactor = 0.78 },
		rarityWeights = { Rare = 60, Epic = 28, Legendary = 10, Mythic = 2 },
		cores = { "TarCore", "IceAgeCore", "AsteroidCore", "SupervolcanoCore" },
		sky = { ambient = { 140, 130, 90 }, fog = { 170, 160, 110 }, fogEnd = 480, tint = { 255, 245, 215 }, clock = 16.8 },
	},
	{
		id = "Skylands",
		name = "Skylands",
		speedReq = 1000000,
		baseIncome = 3000,
		tagline = "Storms are born up here.",
		guardian = { name = "Storm Roc", kind = "Roc", speedFactor = 0.78 },
		rarityWeights = { Rare = 58, Epic = 29, Legendary = 10.5, Mythic = 2.5 },
		cores = { "LightningCore", "JetstreamCore", "SupercellCore", "SolarCore" },
		sky = { ambient = { 170, 180, 220 }, fog = { 200, 215, 255 }, fogEnd = 1100, tint = { 240, 245, 255 }, clock = 7.2 },
	},
	{
		id = "VoidRealm",
		name = "Void Realm",
		speedReq = 3000000,
		baseIncome = 9000,
		tagline = "Where disasters go to die.",
		guardian = { name = "Void Warden", kind = "Warden", speedFactor = 0.78 },
		rarityWeights = { Rare = 56, Epic = 30, Legendary = 11, Mythic = 3 },
		cores = { "RiftCore", "VoidCore", "BlackHoleCore", "SingularityCore" },
		sky = { ambient = { 70, 30, 110 }, fog = { 20, 5, 40 }, fogEnd = 330, tint = { 230, 205, 255 }, clock = 0 },
	},
}

---------------------------------------------------------------------------
-- Cores: id -> data. `rarity` determines incubation, weight and income mult.
-- `shape` picks the core model style, `colors` = {primary, secondary, glow}.
---------------------------------------------------------------------------
local function core(name, zone, rarity, disaster, shape, c1, c2, glow)
	return { name = name, zone = zone, rarity = rarity, disaster = disaster, shape = shape, colors = { c1, c2, glow } }
end

GameConfig.Cores = {
	-- Suburb
	GustCore = core("Gust Core", "Suburb", "Common", "DustDevil", "Swirl", { 214, 196, 160 }, { 150, 130, 100 }, { 255, 240, 200 }),
	HailCore = core("Hail Core", "Suburb", "Uncommon", "HailSprite", "Crystal", { 220, 240, 255 }, { 120, 150, 190 }, { 200, 240, 255 }),
	TornadoCore = core("Tornado Core", "Suburb", "Rare", "MiniTornado", "Swirl", { 120, 130, 150 }, { 70, 75, 90 }, { 170, 210, 255 }),
	ThunderCore = core("Thunder Core", "Suburb", "Epic", "Thunderhead", "Charged", { 80, 80, 110 }, { 40, 40, 60 }, { 255, 240, 90 }),
	-- Overgrowth
	SporeCore = core("Spore Core", "Overgrowth", "Common", "SporeCloud", "Pod", { 170, 120, 200 }, { 90, 150, 70 }, { 220, 180, 255 }),
	ThornCore = core("Thorn Core", "Overgrowth", "Uncommon", "BrambleQuake", "Spiked", { 90, 120, 50 }, { 60, 40, 30 }, { 170, 255, 110 }),
	VineCore = core("Vine Core", "Overgrowth", "Rare", "VineSerpent", "Pod", { 60, 160, 70 }, { 30, 80, 40 }, { 120, 255, 140 }),
	WildfireCore = core("Wildfire Core", "Overgrowth", "Epic", "WildfireFox", "Flame", { 255, 120, 30 }, { 120, 40, 20 }, { 255, 200, 60 }),
	-- Droughtlands
	DustCore = core("Dust Core", "Droughtlands", "Common", "Sandstorm", "Swirl", { 230, 190, 120 }, { 170, 120, 70 }, { 255, 220, 150 }),
	HeatwaveCore = core("Heatwave Core", "Droughtlands", "Uncommon", "MirageWisp", "Flame", { 255, 160, 60 }, { 200, 90, 40 }, { 255, 230, 120 }),
	SinkholeCore = core("Sinkhole Core", "Droughtlands", "Rare", "SinkholeMaw", "Cracked", { 140, 100, 70 }, { 60, 40, 30 }, { 255, 170, 90 }),
	EarthquakeCore = core("Earthquake Core", "Droughtlands", "Epic", "QuakeTitan", "Cracked", { 120, 90, 70 }, { 50, 35, 25 }, { 255, 120, 50 }),
	-- Frostfall
	FrostCore = core("Frost Core", "Frostfall", "Uncommon", "FrostWisp", "Crystal", { 200, 235, 255 }, { 120, 170, 220 }, { 220, 250, 255 }),
	AvalancheCore = core("Avalanche Core", "Frostfall", "Rare", "AvalancheGolem", "Cracked", { 235, 245, 255 }, { 150, 170, 190 }, { 180, 230, 255 }),
	BlizzardCore = core("Blizzard Core", "Frostfall", "Epic", "BlizzardBeast", "Swirl", { 210, 230, 255 }, { 100, 130, 180 }, { 200, 240, 255 }),
	GlacierCore = core("Glacier Core", "Frostfall", "Legendary", "GlacierTitan", "Crystal", { 120, 210, 255 }, { 40, 100, 170 }, { 160, 240, 255 }),
	-- Magma Basin
	AshCore = core("Ash Core", "MagmaBasin", "Uncommon", "AshCloud", "Swirl", { 90, 85, 85 }, { 40, 35, 35 }, { 255, 120, 60 }),
	EruptionCore = core("Eruption Core", "MagmaBasin", "Rare", "VolcanoJr", "Cracked", { 70, 50, 45 }, { 255, 90, 20 }, { 255, 150, 40 }),
	MeteorCore = core("Meteor Core", "MagmaBasin", "Epic", "Meteor", "Flame", { 110, 80, 60 }, { 255, 100, 20 }, { 255, 180, 60 }),
	InfernoCore = core("Inferno Core", "MagmaBasin", "Legendary", "InfernoDrake", "Flame", { 255, 70, 20 }, { 120, 10, 10 }, { 255, 220, 80 }),
	-- Deep Abyss
	RiptideCore = core("Riptide Core", "DeepAbyss", "Uncommon", "RiptideEel", "Pod", { 40, 140, 170 }, { 20, 60, 90 }, { 90, 255, 230 }),
	WhirlpoolCore = core("Whirlpool Core", "DeepAbyss", "Rare", "Maelstrom", "Swirl", { 30, 110, 200 }, { 10, 40, 90 }, { 100, 220, 255 }),
	TsunamiCore = core("Tsunami Core", "DeepAbyss", "Epic", "TsunamiColossus", "Wave", { 30, 150, 230 }, { 230, 250, 255 }, { 120, 230, 255 }),
	UndertowCore = core("Undertow Core", "DeepAbyss", "Legendary", "UndertowLeviathan", "Spiked", { 20, 60, 110 }, { 0, 20, 50 }, { 60, 255, 210 }),
	-- Prehistoric
	TarCore = core("Tar Core", "Prehistoric", "Rare", "TarBlob", "Pod", { 35, 30, 30 }, { 90, 70, 40 }, { 255, 170, 70 }),
	IceAgeCore = core("Ice Age Core", "Prehistoric", "Epic", "MammothGlacier", "Crystal", { 190, 225, 245 }, { 130, 100, 70 }, { 210, 245, 255 }),
	AsteroidCore = core("Asteroid Core", "Prehistoric", "Legendary", "ExtinctionAsteroid", "Cracked", { 90, 80, 75 }, { 255, 110, 30 }, { 255, 200, 90 }),
	SupervolcanoCore = core("Supervolcano Core", "Prehistoric", "Mythic", "Supervolcano", "Flame", { 60, 30, 25 }, { 255, 60, 20 }, { 255, 230, 120 }),
	-- Skylands
	LightningCore = core("Lightning Core", "Skylands", "Rare", "Thunderbird", "Charged", { 250, 240, 140 }, { 80, 90, 160 }, { 255, 255, 170 }),
	JetstreamCore = core("Jetstream Core", "Skylands", "Epic", "JetstreamDrake", "Swirl", { 190, 230, 255 }, { 255, 255, 255 }, { 170, 230, 255 }),
	SupercellCore = core("Supercell Core", "Skylands", "Legendary", "Supercell", "Charged", { 70, 75, 110 }, { 30, 30, 50 }, { 160, 200, 255 }),
	SolarCore = core("Solar Core", "Skylands", "Mythic", "SolarStorm", "Flame", { 255, 210, 60 }, { 255, 120, 20 }, { 255, 250, 200 }),
	-- Void Realm
	RiftCore = core("Rift Core", "VoidRealm", "Rare", "RiftWisp", "Crystal", { 140, 60, 220 }, { 40, 10, 70 }, { 210, 120, 255 }),
	VoidCore = core("Void Core", "VoidRealm", "Epic", "VoidEntity", "Spiked", { 25, 10, 40 }, { 120, 40, 200 }, { 200, 90, 255 }),
	BlackHoleCore = core("Black Hole Core", "VoidRealm", "Legendary", "BlackHole", "Swirl", { 10, 5, 15 }, { 255, 150, 60 }, { 255, 190, 110 }),
	SingularityCore = core("Singularity Core", "VoidRealm", "Mythic", "Singularity", "Charged", { 255, 255, 255 }, { 60, 0, 120 }, { 255, 120, 255 }),
	-- Event-only
	ChaosCore = core("Chaos Core", "Any", "Chaos", "ChaosStorm", "Chaos", { 255, 40, 220 }, { 40, 255, 230 }, { 255, 255, 120 }),
}

---------------------------------------------------------------------------
-- Disasters: the hatched collectibles. `archetype` picks the model builder;
-- `incomeFactor` fine-tunes inside a zone/rarity.
---------------------------------------------------------------------------
local function disaster(name, archetype, c1, c2, glow, incomeFactor)
	return { name = name, archetype = archetype, colors = { c1, c2, glow }, incomeFactor = incomeFactor or 1 }
end

GameConfig.Disasters = {
	DustDevil = disaster("Dust Devil", "Vortex", { 214, 190, 150 }, { 160, 130, 95 }, { 255, 235, 190 }),
	HailSprite = disaster("Hailstorm Sprite", "Cloud", { 235, 240, 250 }, { 150, 190, 230 }, { 200, 240, 255 }),
	MiniTornado = disaster("Mini Tornado", "Vortex", { 140, 150, 165 }, { 80, 85, 100 }, { 180, 210, 255 }),
	Thunderhead = disaster("Thunderhead", "StormCloud", { 90, 92, 115 }, { 50, 50, 70 }, { 255, 240, 90 }),
	SporeCloud = disaster("Spore Cloud", "Cloud", { 190, 140, 220 }, { 120, 180, 90 }, { 230, 190, 255 }),
	BrambleQuake = disaster("Bramble Quake", "Golem", { 100, 130, 55 }, { 70, 50, 35 }, { 170, 255, 110 }),
	VineSerpent = disaster("Vine Serpent", "Serpent", { 60, 160, 70 }, { 30, 90, 40 }, { 140, 255, 150 }),
	WildfireFox = disaster("Wildfire Fox", "Beast", { 255, 120, 30 }, { 255, 230, 180 }, { 255, 200, 60 }),
	Sandstorm = disaster("Sandstorm", "Vortex", { 230, 190, 120 }, { 180, 130, 70 }, { 255, 220, 150 }),
	MirageWisp = disaster("Mirage Wisp", "Wisp", { 255, 170, 70 }, { 255, 230, 150 }, { 255, 240, 160 }),
	SinkholeMaw = disaster("Sinkhole Maw", "Maw", { 140, 100, 70 }, { 40, 25, 20 }, { 255, 160, 80 }),
	QuakeTitan = disaster("Quake Titan", "Golem", { 125, 95, 70 }, { 60, 40, 30 }, { 255, 120, 50 }),
	FrostWisp = disaster("Frost Wisp", "Wisp", { 210, 240, 255 }, { 140, 190, 240 }, { 220, 250, 255 }),
	AvalancheGolem = disaster("Avalanche Golem", "Golem", { 235, 245, 255 }, { 150, 170, 195 }, { 180, 230, 255 }),
	BlizzardBeast = disaster("Blizzard Beast", "Beast", { 230, 240, 255 }, { 110, 150, 200 }, { 200, 240, 255 }),
	GlacierTitan = disaster("Glacier Titan", "Golem", { 130, 210, 255 }, { 50, 110, 180 }, { 170, 240, 255 }, 1.1),
	AshCloud = disaster("Ash Cloud", "StormCloud", { 85, 80, 80 }, { 40, 35, 35 }, { 255, 120, 60 }),
	VolcanoJr = disaster("Volcano Jr.", "Volcano", { 75, 55, 45 }, { 255, 90, 20 }, { 255, 160, 40 }),
	Meteor = disaster("Meteor", "Meteor", { 110, 85, 65 }, { 255, 110, 25 }, { 255, 190, 70 }),
	InfernoDrake = disaster("Inferno Drake", "Serpent", { 255, 80, 20 }, { 120, 15, 10 }, { 255, 220, 80 }, 1.1),
	RiptideEel = disaster("Riptide Eel", "Serpent", { 40, 150, 180 }, { 20, 70, 100 }, { 90, 255, 230 }),
	Maelstrom = disaster("Maelstrom", "Vortex", { 30, 110, 200 }, { 220, 245, 255 }, { 100, 220, 255 }),
	TsunamiColossus = disaster("Tsunami Colossus", "Wave", { 30, 150, 230 }, { 235, 250, 255 }, { 120, 230, 255 }),
	UndertowLeviathan = disaster("Undertow Leviathan", "Serpent", { 20, 60, 110 }, { 60, 255, 210 }, { 60, 255, 210 }, 1.1),
	TarBlob = disaster("Tar Pit Blob", "Maw", { 35, 30, 30 }, { 90, 70, 40 }, { 255, 170, 70 }),
	MammothGlacier = disaster("Mammoth Glacier", "Beast", { 140, 100, 70 }, { 200, 235, 250 }, { 210, 245, 255 }),
	ExtinctionAsteroid = disaster("Extinction Asteroid", "Meteor", { 90, 80, 75 }, { 255, 120, 40 }, { 255, 210, 100 }, 1.1),
	Supervolcano = disaster("Supervolcano", "Volcano", { 60, 35, 30 }, { 255, 60, 20 }, { 255, 230, 120 }, 1.1),
	Thunderbird = disaster("Thunderbird", "Bird", { 250, 230, 120 }, { 70, 80, 150 }, { 255, 255, 170 }),
	JetstreamDrake = disaster("Jetstream Drake", "Serpent", { 200, 235, 255 }, { 255, 255, 255 }, { 170, 230, 255 }),
	Supercell = disaster("Supercell", "StormCloud", { 70, 75, 110 }, { 30, 30, 50 }, { 160, 200, 255 }, 1.1),
	SolarStorm = disaster("Solar Storm", "Wisp", { 255, 210, 60 }, { 255, 120, 20 }, { 255, 250, 200 }, 1.1),
	RiftWisp = disaster("Rift Wisp", "Wisp", { 160, 70, 240 }, { 50, 15, 90 }, { 220, 140, 255 }),
	VoidEntity = disaster("Void Entity", "Entity", { 25, 10, 40 }, { 140, 50, 220 }, { 210, 100, 255 }),
	BlackHole = disaster("Black Hole", "BlackHole", { 5, 0, 10 }, { 255, 150, 60 }, { 255, 190, 110 }, 1.1),
	Singularity = disaster("Singularity", "Entity", { 250, 250, 255 }, { 70, 0, 130 }, { 255, 130, 255 }, 1.15),
	ChaosStorm = disaster("Chaos Storm", "Vortex", { 255, 40, 220 }, { 40, 255, 230 }, { 255, 255, 120 }),
}

---------------------------------------------------------------------------
-- Core spawning
---------------------------------------------------------------------------
GameConfig.Spawning = {
	NestPointsPerZone = 6,
	RespawnDelay = 22,
	NestRadius = 34, -- spawn points are placed on a ring around the nest
	NestDepth = 0.68, -- nest center at this fraction of the zone length
}

---------------------------------------------------------------------------
-- Guardians
---------------------------------------------------------------------------
GameConfig.Guardian = {
	SleepTime = 7,
	AwakeTime = 11,
	LeashRadius = 85,
	AggroRadius = 55,
	TagRange = 7,
	PatrolSpeed = 8,
	KnockbackForce = 70,
	TagCooldown = 1.5,
}

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
GameConfig.Events = {
	Interval = 300, -- seconds between refreshes
	Warning = 30,
	FrenzyDuration = 10,
	FrenzyRareBoostPerRank = 1.8, -- weight *= boost^(rank-1) during frenzy
	FrenzyIncubationMult = 4,
	FrenzyMutationMult = 3,
	ChaosCoresPerFrenzy = 3,
}

---------------------------------------------------------------------------
-- Upgrades. Costs are for going from `level` to `level + 1`.
---------------------------------------------------------------------------
GameConfig.Upgrades = {
	Treadmill = { name = "Treadmill", desc = "More Speed per step", startLevel = 1, maxLevel = 30, baseCost = 40, growth = 2.15 },
	Carry = { name = "Backpack", desc = "Carry more cores", startLevel = 1, maxLevel = 4, costs = { 400, 9000, 250000 } },
	Pods = { name = "Incubator Pod", desc = "Hatch more at once", startLevel = 2, maxLevel = 8, baseCost = 150, growth = 3.4 },
	Pedestals = { name = "Display Pedestal", desc = "Show more disasters", startLevel = 4, maxLevel = 16, baseCost = 120, growth = 2.0 },
	Shield = { name = "Storm Shield", desc = "Longer base lock", startLevel = 1, maxLevel = 5, baseCost = 500, growth = 4, durations = { 30, 45, 60, 75, 90 } },
}
GameConfig.UpgradeOrder = { "Treadmill", "Carry", "Pods", "Pedestals", "Shield" }

---------------------------------------------------------------------------
-- Economy / data
---------------------------------------------------------------------------
GameConfig.Economy = {
	StartMoney = 0,
	SellFraction = 1.0, -- of value; value = income * 60
	ValueSeconds = 60,
	OfflineIncubationCap = 3600 * 8,
}

GameConfig.Data = {
	StoreName = "StealADisaster_PlayerData_v1",
	SchemaVersion = 1,
	AutosaveInterval = 90,
	MaxStoredCores = 24,
}

GameConfig.RateLimits = {
	-- tokens per second, burst
	Upgrade = { 4, 6 },
	Shield = { 1, 2 },
	Sell = { 3, 5 },
	Place = { 4, 6 },
	Generic = { 6, 10 },
}

---------------------------------------------------------------------------
-- Lookups
---------------------------------------------------------------------------
GameConfig.ZoneById = {}
GameConfig.ZoneIndex = {}
for i, z in ipairs(GameConfig.Zones) do
	z.index = i
	GameConfig.ZoneById[z.id] = z
	GameConfig.ZoneIndex[z.id] = i
end

-- core -> disaster reverse map & validation
GameConfig.CoreByDisaster = {}
for id, c in pairs(GameConfig.Cores) do
	c.id = id
	GameConfig.CoreByDisaster[c.disaster] = id
end
for id, d in pairs(GameConfig.Disasters) do
	d.id = id
	local coreId = GameConfig.CoreByDisaster[id]
	local c = coreId and GameConfig.Cores[coreId]
	d.rarity = c and c.rarity or "Common"
	d.zone = c and c.zone or "Suburb"
end

return GameConfig
