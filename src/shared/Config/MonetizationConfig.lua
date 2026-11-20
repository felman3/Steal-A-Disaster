--[[
	MonetizationConfig — every Game Pass and Developer Product in one place.

	`id` is the real Roblox asset id. It stays 0 until the item is created in the
	Creator Dashboard (see docs/MONETIZATION.md). While an id is 0:
	  * live servers hide the item and never sell it;
	  * Studio can run a mock purchase (MockInStudio) so the full grant path can be
	    tested without spending Robux.

	`intendedPrice` is documentation only. The shop shows the price returned by
	MarketplaceService:GetProductInfo, and Roblox charges whatever the item is set to.

	Fairness rules: nothing here touches PvP (shield, tag range, carry cap, steal
	protection), and nothing sells cores, disasters, zones or random rewards.

	Pure data (no Roblox types) so the headless tests can load it.
]]

local MonetizationConfig = {}

-- Studio only: items whose id is still 0 can be bought through a mock flow.
MonetizationConfig.MockInStudio = true

-- Processed Developer Product PurchaseIds kept per player (idempotency window).
MonetizationConfig.ReceiptHistorySize = 200

MonetizationConfig.Items = {
	TurboTreadmill = {
		type = "GamePass",
		id = 0,
		intendedPrice = 149,
		permanent = true,
		icon = "🏃",
		name = "Turbo Treadmill",
		benefit = "2× Speed from every treadmill step",
		description = "Permanently doubles the Speed you earn on your treadmill.",
	},
	DoubleCash = {
		type = "GamePass",
		id = 0,
		intendedPrice = 149,
		permanent = true,
		icon = "💰",
		name = "Double Cash",
		benefit = "2× income from your disasters",
		description = "Permanently doubles the money your displayed disasters earn.",
	},
	InstantHatch = {
		type = "DeveloperProduct",
		id = 0,
		intendedPrice = 29,
		permanent = false,
		icon = "🥚",
		name = "Instant Hatch",
		benefit = "Finishes one incubating pod now",
		description = "Hatches one pod immediately. Rarity, mutation chance and value are unchanged.",
	},
	SpeedBoost = {
		type = "DeveloperProduct",
		id = 0,
		intendedPrice = 49,
		permanent = false,
		icon = "⚡",
		name = "Speed Boost",
		benefit = "2× treadmill Speed for 15 minutes",
		description = "Counts down only while you play. Buying again adds time; it never raises the multiplier.",
		durationSeconds = 900,
	},
	CashPack = {
		type = "DeveloperProduct",
		id = 0,
		intendedPrice = 79,
		permanent = false,
		icon = "💵",
		name = "Cash Pack",
		benefit = "About 10 minutes of your income",
		description = "Scales with your progress: 10 minutes of your base income, with a minimum set by your highest unlocked zone.",
		incomeSeconds = 600,
		-- minimum = highest unlocked zone's common income × incomeSeconds × this
		minimumZoneIncomes = 2,
	},
}

-- Robux rows in the shop (Game Passes first, then one-time boosts). Speed Boost and
-- Instant Hatch are also sold on the treadmill console and on incubating pods.
MonetizationConfig.BoostsOrder = { "TurboTreadmill", "DoubleCash", "CashPack", "SpeedBoost", "InstantHatch" }

-- Treadmill Speed multiplier is additive: x1 base, x2 with Turbo OR a Boost, x3 with both.
MonetizationConfig.TurboSpeedBonus = 1
MonetizationConfig.BoostSpeedBonus = 1
MonetizationConfig.DoubleCashMult = 2

return MonetizationConfig
