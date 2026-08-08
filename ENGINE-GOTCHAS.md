# Engine gotchas

FAF-specific behaviour that cost real debugging time on this map. Read before
changing anything structural.

> The project-agnostic version — everything here plus the desync rule, the Lua
> 5.0 dialect, map/mod anatomy and a symptom→cause table, written for *any* FAF
> map or mod — lives in [`FAF-SCRIPTING-GUIDE.md`](FAF-SCRIPTING-GUIDE.md).
> Design and rules live in [`README.md`](README.md).

## The Lua environment

**Reading an undefined global ERRORS. `X = nil` is not "off", it is a crash.**
`lua/system/config.lua:55-59` puts an `__index` on `_G` that calls
`error("access to nonexistent global variable ...")` instead of returning nil.
Assigning nil to a module-level name never creates the key, so every later read
of it throws. **To disable a `Config` value, give it `false`.**

The failure is quiet — it logs at `warning:`, not `error:`, and play continues.
`Config.AcuTuneCommand = nil` threw out of `AcuRules.Start()` before its
`ForkThread` and took the ACU build-rate buff, movement multipliers, midline
rule and no-build zones offline for a whole match (game 27570431); the only
visible symptom was "the ACU moves at 1x". Two habits catch it: fork critical
loops **before** optional setup in any `Start()`, and check that every
`Config.X` read has a definition.

**A long-lived `ForkThread` the game depends on must not be able to throw**, and
`pcall`ed code must never `WaitSeconds` — this Lua cannot yield across a `pcall`
boundary.

**`MarkerToPosition` errors on a missing marker**, so optional markers cannot be
probed with it. `Config.GetMarker()` reads
`Scenario.MasterChain._MASTERCHAIN_.Markers[name]` directly and returns nil.

## Spawning, categories and restrictions

**Blueprint-id categories are lowercase.** `categories.ueb1101` exists;
`categories.UEB1101` does not (zero uppercase uses in `gamedata/lua.nx2`).
`EntityCategory + nil` throws *"get as UserData expected but got nil"*, which
surfaces as the whole `OnStart` silently failing. `AllowedCategories()`
nil-guards and WARNs for this reason.

**`CreateUnitHPR` throws on failure — it does not return nil — and the army unit
cap is what makes it fail.** The lobby's cap applies per army, `ARMY_WAVE_n`
extra armies included, and a persistent queue re-spawning the standing wave
every round walks into it (a lane with no opposing player is worst: nothing
there ever dies). In game 27565454 one refusal at round 26 unwound through
`SpawnWave` → `SpawnWaveForArmy` → `RoundManager`'s loop and **killed the
round-loop thread**: no further rounds or waves, no on-screen error, and
`FactoryQueue` charging on for waves that never came. Every call site is now
`pcall`ed per unit, per lane and per army, and each round logs every wave army's
`UnitCap_Current`/`UnitCap_MaxCap` — FAF's own JsonStats blob reports human
armies only, so a wave army's population appears nowhere else.

**`AddRestriction` destroys script-spawned units too.** The map's own
`AddRestriction(ALLUNITS - allowed)` killed the Core on completion (*"Unit.
OnStopBeingBuilt() cannot create restricted unit"*). Adding it to the allowed
set fixes that, but **an exemption granted so the script can spawn something
also hands it to the players** — and "players still cannot build it, since it is
T3 and all engineers are restricted" is wrong, because the ACU is not an
engineer. Stock `ueb1301` carries `BUILTBYTIER3COMMANDER` and `UEF`, so the
instant a UEF player finished `T3Engineering` the Core appeared in their build
menu at a stock 2500 e/s against a Core throttled to 500 (game 27565454; the
same enhancement unlocks the experimentals, so both appeared at once).

The durable fix is at the blueprint end, where a restriction exemption cannot
undo it: `units/LineWars_units.bp` overwrites those two `Categories` entries
with an inert marker, so no ACU's `BuildableCategory` can express it while the
script spawns it as before. **Anything else added to `allowed` wants the same
audit.** `CoreStorage`'s `ueb1106`/`ueb1105` and their faction pairs carry
`BUILTBYTIER2COMMANDER`, so any ACU past `AdvancedEngineering` can build
storage; that one is deliberately left buildable and repriced instead.

## Blueprints from a map

**A map can override blueprints without shipping a mod.** `LoadBlueprints()` in
`lua/system/Blueprints.lua` runs `DiskFindFiles(preGameData.CurrentMapDir,
'*.bp')` after the game files and **before mods**, on both the sim and UI side
(`CurrentMapDir` is written into `Game.prefs` by `ui/lobby/lobby.lua`).
`StoreBlueprint` honours `Merge = true`, merging fields into the stock blueprint
rather than replacing it, so only differences need stating.

- **A map `.bp` loses to mods**, which load after it. Test without unit-overhaul
  mods (BlackOps/Total Mayhem), and keep a runtime fallback for anything that
  matters. Runtime `__blueprints` edits do not reach the engine at all.
- **Merges can add and change fields, but cannot delete them.** Adding a key the
  stock blueprint lacks does work: `MaxBrake` is absent from the ACU blueprints
  entirely and `BlueprintMerged` still adds it (verified in game 27570392 by
  reading `GetBlueprint().Physics.MaxBrake` back).
- Useful targets: `Description` (the *entire* build-button hover tooltip —
  `construction.lua` sets `tooltipID = LOC(bp.Description)` and builds a
  title-only tooltip), `General.UnitName` (unit-info panel name),
  `StrategicIconName`, `Economy.*`, `Physics.*`.
- A `.bp` may call `UnitBlueprint{}` any number of times and may use
  `doscript(path, env)`, so `LineWars_spawners_unit.bp` generates all 12 merges
  from `SpawnerTypes.lua` rather than duplicating them.
- It runs inside the loader's `safecall`, so a failure degrades to stock rather
  than crashing. Grep the log for `Blueprints Loading: Blueprints from current
  map`.

**The 48x48 build-menu art is not changeable from a map.** It is looked up as
`<skin textures>/icons/units/<id>_icon.dds`, and only mods and skins mount at
the VFS root — map folders mount at `/maps/<name>/`. The workaround is
`StrategicIconName`, which the build button draws as an overlay; set it to the
icon of the unit *produced* rather than of the proxy structure. Full custom art
would need a companion mod.

## Units and motion

**`BuffBlueprint` is a sim global usable from map code**, so ACU buffs need no
mod. `Buff.ApplyBuff(acu, 'LineWarsAcu')` is keyed by unit object in
`AcuRules`, so a rebuilt ACU gets re-buffed.

**A buff's `MoveMult` is three settings wearing one hat.**
`lua/sim/Buff.lua:386-390` passes the single value to `SetSpeedMult`,
`SetAccMult` *and* `SetTurnMult`, so speed, acceleration and turn rate can never
differ under a buff. Call the three yourself when they need to.

**There is no brake multiplier, at all.** Those three are the only motion
`Set*Mult` calls in the engine, and `unit:GetNavigator()` exposes only `SetGoal`
and `AbortMove` (both grepped across `lua.nx2`, 2026-08-08). `MaxBrake` is
blueprint-only, so any large speed buff **must** be paired with a load-time
`Physics` merge or arrival behaviour falls apart — braking is what caused the
ACU movement stutter. Many blueprints omit `MaxBrake` entirely (all four ACUs
do; the near-identical SACU `UEL0301` declares it), and `MaxBrake >
MaxAcceleration` is the normal idiom (`UEL0101`: 9 against 4.5), not a 1:1
mirror. Tune on **time to stop** (`v/b`) rather than stopping distance: stock FA
land units sit in a 0.5–1.0 s band.

**Never mutate a unit's state on a fast tick when nothing changed.** Any re-fire
of the UI's `OnSelectionChanged` runs `construction.OnSelection`, whose first
act is `UnitViewDetail.Hide()` (`construction.lua:2530`) plus a full rebuild of
the build-icon grid — and that panel is only re-shown by a fresh MouseEnter. A
redundant `SetPaused`/`SetBuildRate` on a 0.1 s loop therefore made the hover
stats window vanish unless the mouse kept moving. Check before you set (`Pin` in
`lib/FactoryQueue.lua`); note `Unit:GetBuildRate` clamps to 0.00001, never 0
(`lua/sim/Unit.lua:1149`), so compare against an epsilon.

**A factory's command queue merges only *consecutive* identical `BuildFactory`
orders**, and the UI stacks the same way (`construction.lua:2419`). One
`IssueBuildFactory({f}, bp, n)` per blueprint is what makes a re-issued queue
read as grouped.

**`SetBlockCommandQueue(true)` also blocks the script's own
`IssueBuildFactory`/`IssueClearCommands`.** Never use it as an affordability
gate.

## Chat from the sim

**Chat is readable from the sim without any UI code.** For every message it
receives, the stock UI fires a SimCallback whose only job is to record it into
the replay (`ui/game/chat.lua:810` → `SimUtils.GiveResourcesToPlayer`, whose
first act is `SendChatToReplay(data)` before returning early because
`From == To`). `data.Sender` is the nickname, `data.Msg.text` is what was typed.
`SendChatToReplay` is called *unqualified* from inside that function, so it
resolves through SimUtils' module environment at call time — replacing
`import('/lua/simutils.lua').SendChatToReplay` intercepts every message. A
leading `/` survives into `msg.text`: `chat.lua:719` strips it only when
building `args` for `RunChatCommand`.

Hooking the callback table itself is **not** possible: `Callbacks` in
`SimCallbacks.lua` is a file-local that captured its function reference at load.

**The sim sees exactly one copy per receiving client**, since `ReceiveChat` runs
on every client that got the message and each issues its own callback. Confirmed
by counting dispatches: in the 5-player game 27565454 every `/sos` logged 5
times (one player's 4 uses gave 20 lines); in solo game 27570392 every `/acu`
logged once. The dedupe in `ChatCommands` (sender + text + game time, 0.5 s) is
therefore **load-bearing** — without it `/sos` would have fired five times per
use. All copies land within one tick, so 0.5 s is ample. Handlers are dispatched
with `ForkThread` so a throw cannot take replay chat logging down with it.

## On-screen text

**The first `PrintText` of the game can kill `PrintText` for the whole session.**
`textdisplay.lua:17` captures its parent as a module upvalue at load time —
`local worldView = borders.GetMapGroup()` — and `GetMapGroup()` returns `false`
until `gamemain.CreateUI` builds the border controls. The sim starts before
that, so a message sent from `OnStart` loads `textdisplay` with a dead parent
and every later `PrintText` throws *"maui/text.lua(19): Expected a game
object"*. Unrecoverable: the module is cached and sim code cannot reach UI code
to repair it. Observed in `game_27479823.log` — 138 errors and no on-screen text
at all for the whole match.

**Every message therefore goes through `Config.Announce`**, which queues
anything printed in the first `Config.HudStartDelaySeconds` (8) and flushes it
when the gate opens. `Config.WaitForHud()` is for anything that repaints on a
cycle, since a queued batch flushing late would collide with the next cycle. If
on-screen text goes missing again and that error is in the log, raise
`HudStartDelaySeconds`.

**`PrintText` from the sim shows on EVERY client.** Use `Config.PrintTextFor` /
`PrintTextForSide`, which gate on `GetFocusArmy()` — safe for UI-only effects,
never for anything touching sim state (desync).

**A bare `%` in a lobby option label, value text or value help** goes through
`string.format` and silently kills the rest of the options panel. Escape it as
`%%` (option-level `help` is the exception).

**The objectives panel does not exist in skirmish.** `gamemain.lua:305` only
calls `objectives2.CreateUI` when `campaignMode` is set, so `SimObjectives` /
`Sync.ObjectivesTable` are a dead end for a skirmish map's HUD. `PrintText` is
the only display channel.

## Tooling

**The gamedata `.nx2` archives are plain zips.** `unzip
~/.faforever/gamedata/lua.nx2` (engine + UI lua), `units.nx2` (blueprints),
`textures.nx2` (icons) is the fastest way to answer "what does the engine
actually do here".
