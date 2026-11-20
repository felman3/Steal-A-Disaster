# Art & Code Contract (for anyone adding models or zone builders)

## Language rules (hard requirements)
All `.lua` under `src/` must be valid **in both Luau and Lua 5.4**, because the
headless test runner executes them in Lua 5.4 (wasmoon) against a Roblox mock:

- No compound assignment (`+=`, `-=`...), no `continue`, no type annotations,
  no backtick strings, no `if … then … else` *expressions*, no `//` floor division,
  no numeric literals with `_`, no generalized iteration (`for k, v in t do`) —
  always `pairs`/`ipairs`.
- `string.format("%d", x)` needs an integer, so wrap with `math.floor`.
- Luau stdlib extras (`math.clamp`, `table.find`, `table.clear`, `string.split`,
  `task.*`, `typeof`) are polyfilled by the harness and are fine to use.
- Use `table.unpack`, never bare `unpack`.

## Building parts
Use `src/shared/Models/Kit.lua` (`Kit.part`, `Kit.ball`, `Kit.cylinder`,
`Kit.wedge`, `Kit.light`, `Kit.particles`, `Kit.billboard`, `Kit.text`,
`Kit.rgb`, `Kit.shade`, `Kit.mix`). Plain Parts only, with no asset ids (no MeshId,
no image textures except Roblox built-in `rbxasset://` particle textures).

Remember: Roblox **Ball parts are always uniform spheres** (a non-uniform size is
forced uniform). For ellipsoids use horizontal `Kit.cylinder` bodies, several
balls, or blocks. Cylinders run along their X axis; `Kit.cylinder` already
rotates them to stand vertically (height along Y).

The mock validates every property assignment against Roblox's schema: unknown
properties or wrong datatypes (e.g. a number for `Color`, `Enum.Font` for
`Material`) throw.

## Collectible model conventions (`CoreModels`, `DisasterModels`, `GuardianModels`)
- Return a `Model` with `PrimaryPart` = an invisible part named `Root`.
- Build around the origin. For disasters, the **bottom of the model sits at y = 0**
  (it stands on a pedestal top). For cores, the center is at y = 0.
- All parts `Anchored = true`, `CanCollide = false`, `CanTouch = false`
  (`Kit.setCollide(model, false)` at the end).
- Disasters: about 4–7 studs tall at Common, up to ~9 studs for Legendary/Mythic.
  Guardians: 10–18 studs tall, chunky, readable silhouettes.
- Animation is client-side, driven by attributes:
  - Model attributes `AnimBob` (studs amplitude), `AnimSpin` (rad/s, whole model yaw).
  - Part attribute `Orbit` (rad/s): the part revolves around the model Root's Y axis.
  - Part attribute `SelfSpin` (rad/s): the part spins around its own Y axis.
- Mutation visuals: a `ForceField` aura and a colored particle emitter
  (see `CoreModels.mutationFx`). Golden makes metal/caps gold.
- Keep the part count reasonable: cores ≤ 25 parts, disasters ≤ 45, guardians ≤ 70.
- Faces give character: eyes = black balls with a small white highlight ball;
  angry brows = thin dark blocks.

## Silhouette principle
Each archetype must be recognizable as a black silhouette at 60 studs:
a Vortex is an inverted funnel, a Volcano is a cone with a glowing crater, a
Serpent is an S-curve with a head, a Golem is a blocky humanoid, and so on.
Avoid "floating ball with a tint".
