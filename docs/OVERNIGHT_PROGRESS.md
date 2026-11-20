# Overnight progress (session handoff)

_Last updated: after the "Shop categories + toast/banner Z-order" batch._

## 1. Status
- Branch: `claude/adoring-albattani-tv15ea` (pushed to origin after each batch; never force-pushed).
- Latest commit: see `git log -1` (this file is committed with each batch).
- Roblox: **published** by the user. Universe `10778014315`, root place `71402086993128`, visibility **PRIVATE**.
  Studio opens it from Roblox (Team Create). Studio id changes per session: use `list_roblox_studios`.
  `save_place` = new place version (NOT a publish). Last saved version: 7.
- Monetization: code complete (ec9125e). **Products NOT created yet** (all ids are still 0 in
  `src/shared/Config/MonetizationConfig.lua`). Blocker below.

## 2. Completed (this run)
- Product icons: `tools/make-icons.js` → `assets/icons/*.png` (5 icons, committed).
- **Quick Travel** (a5a40d7): right column HOME / STEAL / SHOP / TRAIN / ZONES
  (`src/client/UI/QuickTravel.lua`), server `TravelService` + pure `TravelLogic`, `RequestTravel` remote,
  Zones panel in `Panels.lua` (M key). Rules: alive+loaded, not carrying, 4 s cooldown, Speed-gated zones,
  safe landing spots offset from other players, carry anti-teleport tracker reset, camera turns behind you.
- **Shop categories**: ⚡ SPEED / 🏠 BASE & CARRY / 🥚 INCUBATOR / 💎 GAME PASSES / 🎁 BOOSTS. All 5 Robux
  items now in the shop (Speed Boost + Instant Hatch also in-world). Panel title "🛒 SHOP".
  "Not enough money — you need $X more." message.
- **Bug fixed**: toasts and announcement banners were drawn behind open panels (ZIndex 1 vs 10).
  Now Toasts 40, Banner 35 (`Announcer.lua`).

## 3. In progress
- Nothing half-done. Next task = see priorities.

## 4. Remaining priorities (ranked)
1. **Monetization products** — blocked on user (see 6). When unblocked: create 2 passes + 3 products
   (multipart POST with `imageFile` from `assets/icons`), re-list to read real IDs, put IDs in
   MonetizationConfig, rebuild, sync Studio, test purchases (Studio test purchase dialog), commit.
2. UI overlap/responsiveness pass: phone sizes (Galaxy A06 800x360, iPhone), Zones panel + shop on phone,
   Quick Travel collapsed state on touch, world labels (TREADMILL billboard is occluded by the base side
   wall at close range; pedestal labels show base income while HUD shows Double Cash total).
3. Disaster Index improvements: search, rarity filter, sort, income per disaster, progress
   (existing index in `Panels.lua` buildIndex — extend, don't rebuild).
4. Environment: distant background scenery around the route/hub (currently empty sky/void beyond walls),
   hub/base polish. Zone builders in `src/server/World/Zones/*.lua` must keep `tests/specs/zones.spec.lua`
   contract (corridor clear, part budget ≤650/zone, gate signs visible).
5. Progression info: stats panel (owned disasters, collection %, income, boosts), maybe daily reward.
6. Audio/visual polish (no audio assets exist; only original/licensed).
7. Performance pass; second full QA cycle (incl. 2-player PvP via StudioTestService).

## 5. Technical notes
- Source of truth `src/`; `npm test` (214 pass), `npm run lint`, `npm run build` (writes build/ AND root
  `StealADisaster.rbxlx`). All Lua must be Luau ∩ Lua 5.4 (no `+=`, no `continue`, etc.).
- Syncing to Studio: mirror each edit with `multi_edit` (same old/new strings) or create new modules with
  `multi_edit` + className; then verify with the checksum script
  (scratchpad `checksums.js`, algorithm h=(h*31+byte)%2147483647 over source without \r) against the
  Luau checksum loop over ReplicatedStorage.Shared / ServerScriptService.Server / StarterPlayerScripts.Client.
- Test idioms: specs use `env.D.Vector3`, `env.run` for yielding code, `env.market` (Marketplace mock),
  `env.studio` (IsStudio toggle), `env.datastore.failNext`, `env.M.remoteLog`.
- In-game Studio commands: `/money n`, `/speed n`, `/core Id`, `/hatch`, `/frenzy`, `/guardians off`, `/reset`
  (TextChatService; type with keyboard: Slash, wait 500 ms, textInput, wait 300 ms, Return).
- Services: PlayerData, Zone, Base, Economy, Speed, Event, CoreSpawn, Carry, Steal, Incubator,
  DisasterCollection, Guardian, Upgrade, Monetization, Travel, Dev.
- **Worked MCP tools**: execute_luau (Edit/Server/Client), multi_edit, start_stop_play, screen_capture
  (one at a time — parallel captures time out), user_mouse_input / user_keyboard_input,
  character_navigation, StudioTestService:ExecuteMultiplayerTestAsync (2+ players via execute_luau),
  open_cloud_invoke (universe:read, game-pass:read/write, developer-product:read/write granted), save_place.
- **Limitations**: Open Cloud create endpoints need multipart, which the tool only sends with a file;
  files must be in an **approved upload directory** (none approved → creation blocked).
  Scripts can't set TextChatService.ChatVersion. Device simulator setters fail during play
  (set device before play). Mouse clicks map wrongly under the device simulator.

## 6. Needs the user
- **Assistant Settings → MCP Permissions → approve upload directory**
  `C:\Users\USER\Desktop\Steal-A-Disaster-claude-adoring-albattani-tv15ea\assets\icons`
  (needed to create the passes/products with icons).
- Optional: Game Settings → Security → Enable Studio Access to API Services (real DataStore in Studio).

## 7. Testing status
- Automated: 214 pass; lint ok; build ok.
- Studio (published place): all 5 Quick Travel buttons, locked-zone refusal (click + forced remote),
  zone travel after unlock, refusal while carrying, camera after travel, shop categories render,
  not-enough-money toast above the shop. Earlier sessions: full loop, PvP 2-player, monetization mock.
- Not verified: real Robux test purchases (no product ids), real phones, DataStore persistence in Studio.
