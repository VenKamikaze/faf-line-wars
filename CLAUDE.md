# Line Wars (FAF map) — working notes

## Where the detail lives

Read these rather than re-deriving; each is current and cited.

- `README.md` — the whole design: game loop, layout, **map marker contract** (lane/Core/spawn/no-build marker names), economy, ACU rules, win condition, lobby options, engine findings, dev workflow. Start here.
- `FACTORY-QUEUE-DESIGN.md` — why the factory-queue model exists, with `file:line` engine citations, plus the open questions (the static economy is the big one still open). Read before touching `lib/FactoryQueue.lua`.
- `UNITS.md` — **generated**. Every buildable factory and unit with the mass/energy actually charged, sorted by cost. The balance reference.
- `lib/UnitTypes.lua` — the single balance table (which factories exist, which units each offers). `units/LineWars_units.bp` — what they cost, plus storage caps.
- `lua-examples/{maps,mods}` — reference FAF maps/mods (Wave of Death, The Great Pass, KotH) for how others solve things.

## Git

- **Trunk is `master`.** `origin/main` is an orphan stub (one "Initial commit", no common ancestor with `master`) and `origin/HEAD` wrongly points at it — diff/PR against `master`, never `main`.

## Verify & deploy

- `luac5.1 -p <file>` — syntax-checks `.lua` and `.bp`; the only local verification that exists. Run before every sync.
- Nothing else is locally testable: behaviour must be confirmed by Kamikaze in-game. Do not claim a change works.
- `deployed-map` is a symlink to a SEPARATE copy. Code flows repo→deployed; `_save.lua`/`_scenario.lua`/`.scmap` flow deployed→repo (authored in FAFMapEditor). NEVER blanket-copy `*.lua` — it clobbers those three. Use the guarded sync in README "Development workflow" (copies code only; `cmp`-checks each editor-authored file and warns on stderr + skips when deployed differs). Kamikaze keeps a pre-edit deployed snapshot in `/tmp/dpm/`. Pre-flight with `diff -rq LineWars-2p.v0001 deployed-map/`, and `git show HEAD:<path> | diff - deployed-map/<path>` to find which commit deployed is at, before overwriting anything.
- `python3 tools/gen-units-md.py` — regenerates `UNITS.md` after editing `lib/UnitTypes.lua` or `units/LineWars_units.bp`.

## Debugging

- `~/.faforever/logs/game_*.log` — `grep "LineWars:"` for `Config.Log` output. This is the only real evidence channel; read it before theorising.
- `unzip -oq ~/.faforever/gamedata/lua.nx2 -d <scratchpad> && grep -rn <sym>` — gamedata archives are plain zips; extract and grep to settle engine questions rather than guessing. `units.nx2` = blueprints (verify ids/costs), `lua.nx2` = engine source under `lua/sim/`.

## FA Lua dialect

- `for i, v in table do` (no `pairs`/`ipairs`) and `table.getn` — Lua 5.0 style. Match it.
- Blueprint ids are lowercase: `categories.ueb0101`. `string.upper` on one yields nil and throws.

## Engine gotchas already paid for

- `PrintText` from sim shows on EVERY client. Use `Config.PrintTextFor` / `PrintTextForSide`, which gate on `GetFocusArmy()` — safe for UI-only effects, never for anything touching sim state (desync).
- `SetBlockCommandQueue(true)` also blocks the script's own `IssueBuildFactory`/`IssueClearCommands`. Never use it as an affordability gate.
- Blueprint edits must be LOAD-time (a map `.bp` merge). Runtime `__blueprints` edits do not reach the engine, and a map `.bp` loses to mods — test without unit-overhaul mods (BlackOps/Total Mayhem).
- The map's own `AddRestriction` destroys script-spawned units too; anything spawned must be in the allowed category set.
- Sim desync: never *iterate* a table keyed by a unit object where the order reaches sim state (spawn order, `Random()` draws, who gets charged when broke). Lua hashes object keys by pointer, which differs per client. Sort by `.EntityId` first — see `SortedFactories` in `lib/FactoryQueue.lua`. Object keys used only for membership tests (`AcuRules`' `buffed`) are fine, and string/integer-keyed tables are already deterministic (content-hashed, no seed randomisation).
- Prefer the fields `Unit:OnPreCreate` caches — `.EntityId`, `.Blueprint`, `.UnitId`, `.Army` (`lua/sim/Unit.lua:277`) — over the moho getters. A moho call on a destroyed entity throws and kills the calling thread; the cached field survives and costs no engine call.
