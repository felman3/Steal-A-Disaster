# Zone Builder Contract

Each route zone is built by `src/server/World/Zones/<ZoneId>.lua` (ZoneId from
`GameConfig.Zones[i].id`). If a file is missing, `Generic.lua` is used.
`Suburb.lua` is the reference implementation, so read it first. The language rules in
`docs/ART_CONTRACT.md` apply.

```lua
return function(ctx)
	-- build everything under ctx.folder
	return { palette = { accent = {r,g,b}, gate = {r,g,b}, gateMaterial = Enum.Material.X,
	                     nest = {r,g,b}, nestMaterial = Enum.Material.X } }
end
```

`ctx` fields:
| field | meaning |
|---|---|
| `folder` | Model to parent all parts into |
| `index`, `zone` | zone index and its config table |
| `z0`, `z1`, `length` | zone spans world Z from `z0` to `z1` (260 studs) |
| `width` | 150: zone spans X from -75 to +75 (invisible walls at ±76) |
| `pathWidth` | 26: the central route corridor is `abs(x) <= 13` |
| `nest`, `nestRadius` | nest center (Vector3, y = 0) and spawn-ring radius (34) |
| `rng(a, b)` | deterministic random (float in [a, b], or [0,1) without args) |
| `Kit`, `tree` | part helpers, plus a reusable tree builder (`tree(parent, pos, scale, leafColor)`) |

The MapBuilder adds the gate arch at `z0`, the nest floor/ring/plinths and the
guardian. **Do not build those.**

## Hard rules (enforced by `tests/specs/zones.spec.lua`)
1. **Ground:** collidable ground must cover the full zone footprint, with its top at
   y = 0 (±0.7). No holes the player can fall through (Skylands can have open-air
   gaps outside the corridor, but the corridor and nest must be solid).
2. **Corridor is clear:** no collidable part may intrude into `abs(x) <= 13`, between
   `z0` and the nest, from y = 0.8 to y = 12. Decorative non-colliding parts are OK.
2b. **Exit path is clear:** the same corridor (`abs(x) <= 13`) from the nest's
   clear radius to `z1` (the walk on to the next zone).
3. **Nest is clear:** no collidable part above y = 0.8 within `nestRadius + 14`
   of the nest center (the guardian patrols and players dodge there).
4. **Stay in bounds:** every part's center satisfies `abs(x) <= 80` and
   `z0 - 2 <= z <= z1 + 2`. Height ≤ 120.
5. **Budget:** ≤ 650 parts per zone. Prefer few big parts plus a handful of hero props.
6. Must not error, and must return a `palette`.

## Art direction
Every zone must read as a **different place**, not a recolor:
distinct ground materials, a signature landmark (hero prop) visible from the
gate, 2–3 recurring prop types, and themed lighting accents (PointLights/Neon
used sparingly). Keep the composition readable: the open corridor leads the eye
to the nest, landmarks frame it, and dense props sit near the side walls.
