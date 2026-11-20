# Steal a Disaster — Design Document

## 1. Reference research (Steal an Egg)

Sources that could be reached from the build environment (the allthings.how and
roblox.com pages themselves were not reachable — DNS blocked in the sandbox — so the
research below comes from search-result summaries of the same guides plus wiki
mirrors):

- games.gg biomes guide, stealanegg.fandom.com/wiki/Zones, stealaneggwiki.net/speed,
  eldorado.gg biomes post, games.gg / techwiser / rblxguide beginner guides.

What the reference does (the parts we keep as *structure*):

| Element | Steal an Egg | What we take |
|---|---|---|
| Loop | Train Speed → run to biome → steal egg → hatch in pen → pets earn $/s | Same loop, Disaster themed |
| Route | Bases at the start, biomes laid out one after another along one long path | One long central route, 9 zones |
| Gating | Biomes are free to walk into; **stealing** needs the biome's Speed | Same: zones open, cores need Speed |
| Gates | Forest 0 → Lake 900 → Desert 10K → Jungle 40K → Snow 170K → Volcano 700K → … billions | ~3–4× per zone but much flatter (no billion grinds) |
| Speed | Treadmill is the unlimited source, ~+200/step early, upgrades/trails multiply | Base treadmill, per-step gain, upgrade levels |
| Guardians | One animal per biome guarding eggs, some sleep | One guardian per zone, sleep/wake cycle, leash |
| Carrying | Weight penalty, carrying several eggs stacks penalty | Weight per rarity, capacity upgrade |
| Hatching | Place in pen/incubator, timer by rarity (rare = long) | Incubator pods, rarity timers, visible progress |
| Mutations | 5 mutations, the main earnings multiplier | 5 Disaster mutations |
| Night | Night blocks stealing | Replaced by the 5-minute refresh + Chaos Frenzy |

## 2. Core loop

```
 ┌──► TRAIN on base treadmill (Speed ↑)
 │        │
 │        ▼
 │   RUN down the central route to the furthest zone you qualify for
 │        │
 │        ▼
 │   STEAL a Disaster Core from a nest (dodge / outrun the Guardian)
 │        │   (or steal an incubating core from another player's base)
 │        ▼
 │   ESCAPE home while slowed by the core's weight  ──► caught? core drops back
 │        │
 │        ▼
 │   INCUBATE in a pod (timer by rarity, visible progress, mutation chance)
 │        │
 │        ▼
 │   DISASTER hatches onto a display pedestal → passive $/s
 │        │
 └── SPEND money: treadmill level, carry capacity, pods, pedestals, shield
```

Every 5 minutes: 30 s warning → world core refresh → **10 s Chaos Frenzy**
(rare odds ×, special Chaos Cores spawn, incubation ×4). Owned data is never touched.

## 3. Map layout (top-down, +Z is "deeper")

```
z=-210 ┌──────────────── STARTING HUB (safe) ────────────────┐
       │ [Base 1]                                  [Base 5]  │
       │ [Base 2]        Index kiosk  Shop kiosk   [Base 6]  │
       │ [Base 3]           ═══ central avenue ═══ [Base 7]  │
       │ [Base 4]                                  [Base 8]  │
z=180  └────────────────────┬─ Route entrance ┬──────────────┘
z=200   ║ 1 SUBURB        (0 Speed)    lawns, fences, cul-de-sac, houses
z=460   ║ 2 OVERGROWTH    (600)        giant mushrooms, vines, ruins
z=720   ║ 3 DROUGHTLANDS  (3K)         cracked clay, mesas, cacti, bones
z=980   ║ 4 FROSTFALL     (12K)        snow, glaciers, ice spires, pines
z=1240  ║ 5 MAGMA BASIN   (40K)        basalt, lava rivers, vents
z=1500  ║ 6 DEEP ABYSS    (120K)       sunken trench, coral, kelp, glow
z=1760  ║ 7 PREHISTORIC   (350K)       ferns, tar pits, giant bones
z=2020  ║ 8 SKYLANDS      (1M)         floating islands over clouds
z=2280  ║ 9 VOID REALM    (3M)         black glass, purple rifts, shards
z=2540  ╚═ end
```

- Each zone is 260 studs long and 150 wide, with a gate arch carrying a SurfaceGui sign
  (zone name, required Speed, rarity preview).
- The nest (core spawn points) sits in the back half of each zone, so reaching a zone's
  cores means crossing the whole zone. The guardian patrols the nest.
- Bases sit on both sides of the hub, all facing the central avenue, so stealing from
  other players is a short detour, but escapes are visible.

## 4. Progression curve

**Speed → WalkSpeed:** `W(S) = min(16 + 5·log2(1 + S/250), 90)`

| Speed | 0 | 600 | 3K | 12K | 40K | 120K | 350K | 1M | 3M |
|---|---|---|---|---|---|---|---|---|---|
| WalkSpeed | 16 | 24.9 | 34.5 | 44.1 | 52.7 | 60.5 | 68.3 | 75.8 | 83.7 |

**Treadmill:** max 4 steps/s, server-counted. Gain per step = `5 · 1.55^(level-1)`.
Level cost = `40 · 2.15^(level-1)`.

**Income** (common, per second) per zone: 2, 6, 18, 50, 140, 400, 1.1K, 3K, 9K.
Rarity multipliers: Common 1, Uncommon 1.6, Rare 2.6, Epic 4.5, Legendary 8,
Mythic 15, Chaos 30. Mutation multipliers ×1.5 – ×5.

Target pacing (checked by `tests/specs/balance.spec.lua`, which simulates a player):
each new zone should unlock 2–15 minutes after the previous one, about 1 hour total to
reach the Void Realm, so there's a reachable milestone every few minutes.

**Carrying:** capacity 1 → 4 via upgrades. Walk multiplier
`max(0.45, 1 - 0.12 · Σweight)`; weight by rarity 1 / 1.2 / 1.5 / 2 / 2.5 / 3 / 3.5.

**Guardian:** chase speed = `0.78 · W(zone gate)`. A player at exactly the gate
carrying a common core moves at 0.88 · W, so they escape. A legendary (0.70) gets
caught unless the player has trained past the gate. Guardians sleep 7 s / wake 11 s
and leash 85 studs from the nest.

**Incubation:** 15 / 30 / 60 / 120 / 240 / 480 / 600 s by rarity, +8 % per zone index.
Frenzy multiplies incubation rate ×4.

## 5. Systems & ownership rules

- **Server-authoritative.** Clients only send intents (buy upgrade, toggle shield,
  sell). Pickup uses server ProximityPrompts. Delivery is detected on the server by
  position, not by remote.
- **Ownership transfer happens only on delivery.** While a core is carried it stays
  owned by its source (the world nest, or the victim's incubator slot, flagged
  `InTransit`). Death, disconnect, being tagged by a guardian or the owner, or a
  teleport flag → it goes back to the source. If the victim leaves mid-steal, the
  steal is cancelled first, so the item can't exist twice.
- **Anti-teleport.** Carriers are position-sampled every Heartbeat. Moving further than
  `maxWalk·dt·1.6 + 6` studs in one sample drops everything.
- **Rate limiting.** Token bucket per player per remote.
- **Persistence.** DataStore `UpdateAsync` with retries, autosave every 90 s, save on
  leave + BindToClose, schema version + sanitizer for corrupt/old data.
  In-memory fallback when the DataStore is unavailable (Studio without API access).
