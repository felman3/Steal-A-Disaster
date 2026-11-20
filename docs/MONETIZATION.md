# Monetization

Everything lives in `src/shared/Config/MonetizationConfig.lua`. The game stays
fully playable without Robux, and nothing for sale affects PvP.

## What is sold

| Key | Type | Intended price | What it does |
|---|---|---|---|
| `TurboTreadmill` | Game Pass (permanent) | 149 R$ | 2× Speed from every treadmill step |
| `DoubleCash` | Game Pass (permanent) | 149 R$ | 2× income from displayed disasters |
| `InstantHatch` | Developer Product | 29 R$ | Finishes ONE incubating pod now (rarity, mutation chance and value unchanged) |
| `SpeedBoost` | Developer Product | 49 R$ | 2× treadmill Speed for 15 min of play time; repeat buys add time; never above ×3 with Turbo |
| `CashPack` | Developer Product | 79 R$ | 10 min of base income, minimum = highest unlocked zone's common income × 600 × 2 |

Where players find them: Turbo, Double Cash and Cash Pack are in the **⭐ BOOSTS**
section at the bottom of the Upgrades panel. Speed Boost is a prompt on your own
treadmill console, and Instant Hatch is a prompt on your own incubating pods.
There are no pop-ups and nothing prompts on spawn or during a run.

Not sold (on purpose): shield advantages, extra tag range, steal protection,
guardian immunity, carry/pod/pedestal beyond the normal caps, cores or disasters,
instant Speed or zone skips, random/gacha items. Later candidates (not built):
VIP, Lucky Mutations, Summon Chaos Frenzy, Big Cash Pack.

## How purchases are granted

- **Developer Products** are granted only in `MarketplaceService.ProcessReceipt`
  (`MonetizationService:processReceipt`):
  - unknown player, data not loaded, or a session whose save failed to load → `NotProcessedYet` (Roblox retries);
  - `PurchaseId` already in the player's saved `receipts` → `PurchaseGranted`, nothing granted again;
  - otherwise grant → record the `PurchaseId` in the same saved document → save → `PurchaseGranted`.
    If the save fails, `NotProcessedYet`; the retry sees the recorded id and does not grant twice.
- **Game Passes** are checked with `UserOwnsGamePassAsync` on every join and cached
  in saved data (`passes`). An API outage keeps the cached entitlement; a successful
  "not owned" (refund) removes it. `PromptGamePassPurchaseFinished` grants immediately.
- The `RequestPurchase` remote only opens Roblox's purchase prompt. It never grants
  on a live server.
- **Shop prices** come from `MarketplaceService:GetProductInfo`. `intendedPrice`
  is documentation only.
- **Unconfigured items** (`id = 0`) are hidden and never sold on live servers. In
  Studio they can be "bought" through a mock flow that runs the same grant code
  (`MockInStudio = true`), so you can test everything without spending Robux.

## Setup checklist (Creator Dashboard)

1. **Publish the place** (File → Publish to Roblox). Passes and products belong to a published experience.
2. Creator Dashboard → your experience → **Monetization → Passes**. Create 2 passes, upload an icon for each, turn on **Item for Sale**, and set the price:
   - **Turbo Treadmill**: 149 R$
   - **Double Cash**: 149 R$
3. **Monetization → Developer Products**. Create 3 products:
   - **Instant Hatch**: 29 R$
   - **Speed Boost**: 49 R$
   - **Cash Pack**: 79 R$
4. Copy each **ID** into `src/shared/Config/MonetizationConfig.lua` (the `id = 0` fields):
   `TurboTreadmill`, `DoubleCash`, `InstantHatch`, `SpeedBoost`, `CashPack`.
5. Game Settings → Security → turn on **Enable Studio Access to API Services** (needed for saving and receipts in Studio).
6. Run `npm test`, `npm run lint` and `npm run build`, then open the rebuilt `StealADisaster.rbxlx` and publish again.
7. In Studio, buy each item once. With real IDs, Studio shows Roblox's **test purchase** dialog and doesn't charge you. Check that:
   - Cash Pack adds money once per purchase;
   - Speed Boost shows `⚡x2` (or `x3` with Turbo) on the treadmill screen;
   - Instant Hatch finishes the pod you used it on;
   - both passes show **OWNED ✓** in the shop, and still do after rejoining.
8. Optional: set `MockInStudio = false` once real IDs are in, so Studio only uses real test purchases.
