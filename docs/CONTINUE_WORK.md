# Continue work (next session)

1. Read `docs/OVERNIGHT_PROGRESS.md` (status, decisions, tools, blockers). Don't re-analyse the project.
2. `git status` and `git log --oneline -5`; confirm the last batch is committed and pushed.
3. `list_roblox_studios` → use the published place (universe 10778014315). Check the upload-directory
   approval: try the Turbo Treadmill game-pass POST with `assets/icons/TurboTreadmill.png`.
   If approved → finish monetization (priority 1). Always list existing passes/products first (no duplicates).
4. Otherwise continue the top unfinished priority in section 4. Read only the files that task touches.
5. Per batch: implement → targeted tests → `npm test` / `npm run lint` / `npm run build` → mirror to Studio
   with multi_edit + checksum check → Studio playtest → commit → push → update OVERNIGHT_PROGRESS.md.
6. Don't redo passing tests or completed features. Keep prices/benefits of monetization unchanged.
