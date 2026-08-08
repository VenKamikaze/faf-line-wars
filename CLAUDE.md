# Line Wars (FAF map) — working notes

## Where the detail lives

Read these rather than re-deriving; each is current and cited.

- `README.md` — the whole design: game loop, layout, **map marker contract** (lane/Core/spawn/no-build marker names), economy, ACU rules, win condition, lobby options, dev workflow. It is also the repo's GitHub front page, so keep it about the design and push engine detail to the file below. Start here.
- `ENGINE-GOTCHAS.md` — **this project's** hard-won FAF engine behaviour, grouped by area (Lua environment, spawning/restrictions, map `.bp` overrides, units and motion, chat, on-screen text). The "Engine gotchas already paid for" list below is its summary; this is the cited long form. Read before changing anything structural.
- `FACTORY-QUEUE-DESIGN.md` — why the factory-queue model exists, with `file:line` engine citations, plus the open questions (the static economy is the big one still open). Read before touching `lib/FactoryQueue.lua`.
- `FAF-SCRIPTING-GUIDE.md` — **project-agnostic**. How to write Lua for FAF maps/mods generally: the Lua 5.0 dialect, map/mod file anatomy, the determinism (desync) rule, restrictions/spawning, blueprint limits, and a symptom→cause table. Claims are tagged [GAME]/[SRC]/[BP]/[ASSUMED]. If reading README.md, this can usually be ignored. If writing large features involving engine-facing code then it may be useful to review.
- `UNITS.md` — **generated**. Every buildable factory and unit with the mass/energy actually charged, sorted by cost. The balance reference.
- `lib/UnitTypes.lua` — the single balance table (which factories exist, which units each offers). `units/LineWars_units.bp` — what they cost, plus storage caps.
- `lua-examples/{maps,mods}` — reference FAF maps/mods (Wave of Death, The Great Pass, KotH) for how others solve things.

## Git

- **Trunk is `master`.** `origin/main` is an orphan stub (one "Initial commit", no common ancestor with `master`) and `origin/HEAD` wrongly points at it — diff/PR against `master`, never `main`.

## Verify & deploy

- `luac5.1 -p <file>` — syntax-checks `.lua` and `.bp`; the only local verification that exists. Run before every sync. **It is a 5.1 parser checking 5.0-dialect code**, so `#t`, `pairs`, `ipairs` and a bare `for i,v in t do` all pass it cleanly — the dialect rules below are not tool-enforced and must be checked by reading.
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

- **Never write `X = nil` to turn a `Config` value off — use `false`.** Assigning nil creates no key, and FA puts an `__index` on `_G` that *errors* on reading a nonexistent global (`lua/system/config.lua:55-59`) rather than returning nil. One such read threw out of `AcuRules.Start()` before its `ForkThread` and silently disabled every ACU rule for a whole match. It logs at `warning:`, not `error:`, and play continues — so fork critical loops **before** optional setup in any `Start()`, and check that every `Config.X` read has a definition.
- `PrintText` from sim shows on EVERY client. Use `Config.PrintTextFor` / `PrintTextForSide`, which gate on `GetFocusArmy()` — safe for UI-only effects, never for anything touching sim state (desync).
- `SetBlockCommandQueue(true)` also blocks the script's own `IssueBuildFactory`/`IssueClearCommands`. Never use it as an affordability gate.
- **Never mutate a unit's state on a fast tick when nothing changed.** Any re-fire of the UI's `OnSelectionChanged` runs `construction.OnSelection`, whose first act is `UnitViewDetail.Hide()` (`construction.lua:2530`) plus a full rebuild of the build-icon grid — and that panel is only re-shown by a fresh MouseEnter. A redundant `SetPaused`/`SetBuildRate` on a 0.1s loop therefore made the hover stats window vanish unless the mouse kept moving. Check before you set (`Pin` in `lib/FactoryQueue.lua`). Note `Unit:GetBuildRate` clamps to 0.00001, never 0 (`lua/sim/Unit.lua:1149`), so compare against an epsilon.
- A factory's command queue merges only **consecutive** identical `BuildFactory` orders; the UI stacks the same way (`construction.lua:2419`). One `IssueBuildFactory({f}, bp, n)` per blueprint is what makes a re-issued queue read as grouped.
- Blueprint edits must be LOAD-time (a map `.bp` merge). Runtime `__blueprints` edits do not reach the engine, and a map `.bp` loses to mods — test without unit-overhaul mods (BlackOps/Total Mayhem).
- The map's own `AddRestriction` destroys script-spawned units too; anything spawned must be in the allowed category set.
- Sim desync: never *iterate* a table keyed by a unit object where the order reaches sim state (spawn order, `Random()` draws, who gets charged when broke). Lua hashes object keys by pointer, which differs per client. Sort by `.EntityId` first — see `SortedFactories` in `lib/FactoryQueue.lua`. Object keys used only for membership tests (`AcuRules`' `buffed`) are fine, and string/integer-keyed tables are already deterministic (content-hashed, no seed randomisation).
- Prefer the fields `Unit:OnPreCreate` caches — `.EntityId`, `.Blueprint`, `.UnitId`, `.Army` (`lua/sim/Unit.lua:277`) — over the moho getters. A moho call on a destroyed entity throws and kills the calling thread; the cached field survives and costs no engine call.
