# Alternative design: factory build queue as the wave list

**Status: proposed, not implemented.** Investigated 2026-07-20. Every engine
claim below was checked against the extracted `lua.nx2` / `units.nx2` sources
and is cited; the open questions at the end are genuinely undecided.

## The idea

Replace "one spawner structure per unit type" with **one real T1 Land Factory
per player**. The player queues units in that factory's normal build menu. Each
unit that finishes is destroyed and increments a per-player counter; at the end
of the round the wave spawner reads the counters and creates that many units in
the `ARMY_WAVE_n` army as it does today.

The factory build menu becomes the whole interface for army composition.

## Why this beats what we have

The current design and the abandoned clone experiment both fight the same
constraint: **the 48x48 build-menu icon is looked up by blueprint id and a map
cannot add art at the VFS root** (see [Abandoned: cloned
blueprints](#abandoned-cloned-blueprints)). Every custom build button is
therefore a "Place Holder" tile.

This design sidesteps it completely. The things the player clicks are **stock
units** (`uel0106`, `uel0201`, `uel0103`, `uel0104`, …), which already have real
icons, real names and real tooltips. **No `.bp` file is needed at all** — the
whole `units/` blueprint-override mechanism becomes optional, used only for
balance tweaks (unit `BuildTime`, factory `BuildRate`) rather than load-bearing.

Two further wins that fall out for free:

- **Resource drain is native.** Mass and energy drain progressively while the
  factory builds, which is exactly the desired behaviour, with no script.
- **Removing queued units is native.** Items sitting in the factory queue are
  removed by clicking them in the queue UI — real icons, instant, and fully
  refunded because nothing has been spent yet.

## Verified engine findings

**The completion hook exists and is usable from map script.**
`ScenarioFramework.CreateUnitBuiltTrigger(callback, unit, category)`
(`ScenarioFramework.lua:307` → `scenariotriggers.lua:449`) simply calls
`unit:AddOnUnitBuiltCallback(callback, category)` (`sim/Unit.lua:4327`).
Callbacks are dispatched by `DoOnUnitBuiltCallbacks` (`sim/Unit.lua:4334`),
which filters with `EntityCategoryContains(v.category, unit)` and skips dead
units. Signature is `callback(factory, finishedUnit)`. `FactoryBuilderManager.lua:281`
uses it exactly this way with `categories.ALLUNITS`.

**Build-list filtering already works via the existing restriction.**
`LineWars-2p_script.lua:55` calls
`ScenarioFramework.AddRestriction(armyName, categories.ALLUNITS - allowed)`.
Adding the land factory and the chosen unit ids to `allowed` makes the factory's
menu show exactly those units and nothing else. The ACU is unaffected — land
units are `BUILTBYTIER1FACTORY`, not `BUILTBYCOMMANDER`, so allowing them does
not put them in the ACU's menu.

**Restrictions are per player army only** (loop at `LineWars-2p_script.lua:48`),
so the `ARMY_WAVE_n` armies stay unrestricted and wave spawning is unaffected by
whatever we allow or forbid for players.

**Refunds are trivial if we ever want them.** `brain:GiveResource('Mass', n)` is
already used by `lib/Economy.lua:37`.

**The factory queue can also be read directly** —
`Unit:GetCommandQueue()` (`sim/Unit.lua:5082`) — which enables the
variant where units never actually get built (see open question 1).

**Watch out:** `AddRestriction` destroys restricted units on completion
(`Unit.OnStopBeingBuilt() cannot create restricted unit`). The units we want the
factory to build must be in the allowed set; do not rely on the restriction
system as the "destroy the built unit" mechanism. Use the callback.

## Implementation sketch

1. `lib/SpawnerTypes.lua` becomes a list of **buildable wave units** (stock
   blueprint ids per faction) rather than spawner structures. Everything that
   currently keys off a structure id keys off a unit id instead.
2. `LineWars-2p_script.lua` allowed set = ACU + Core + land factory + the wave
   unit ids.
3. On factory completion (`OnStopBeingBuilt` on a factory, or a scan at spawn
   time), register `CreateUnitBuiltTrigger(cb, factory, categories.MOBILE)`.
4. `cb(factory, unit)` → `LW.Pending[armyName][unit:GetUnitId()] += 1`, then
   `unit:Destroy()`.
5. `lib/WaveSpawner.lua` reads `LW.Pending[armyName]` instead of scanning for
   spawner structures, and clears it after spawning.
6. `lib/Economy.lua` — `SpawnerIncomeFor` no longer has spawner structures to
   sum; see open question 2.

## Known limitation: per-unit "remove" buttons

A decrement button is not a real unit, so it would need a fabricated blueprint —
which puts us straight back on placeholder icon art. There is no way to add a
build-menu button with custom art from a map.

Mitigation: rely on native queue cancellation, which covers the case that
actually matters (nothing is paid until the unit completes). Units that have
already completed are committed to the wave. The refund *mechanic* is one line
(`GiveResource`); only the *button* is blocked.

## Resolved: economy of the never-build queue (2026-07-21)

Decision: adopt the **queue-as-wave-list** variant (open question 1, "reading
`GetCommandQueue()`") for its visual clarity — the player sees exactly what the
wave will contain. The factory is pinned so it **never actually builds**; the
queue is purely a display of committed intent, and resources are charged by
script. Two concerns were investigated against the extracted `lua.nx2` sources.

**Concern A — can the engine stop a player queuing units they can't afford?**
No. There is **no native affordability gate anywhere** in sim or UI (no
`CanAfford`/cost check exists in the whole tree). The build button issues
`IssueBlueprintCommand("UNITCOMMAND_BuildFactory", id, count)` unconditionally
(`construction.lua:1388`); the engine will queue units you cannot pay for. Its
only economy enforcement is that a factory *building for real* drains as it goes
and stalls when broke — the exact mechanism this variant removes.

The usable lever is `factory:SetBlockCommandQueue(flag)` — an engine method
(used internally by `FactoryUnit` during roll-off, e.g. `FactoryUnit.lua:263`)
that hard-blocks the player from adding *anything* to that factory's queue. It
is all-or-nothing (cannot block a single unit conditionally), which is enough:
flip it on when the player's budget hits zero, off when income recovers.

**Concern B — charge mass/energy immediately when a unit is queued.**
There is **no queue-add event to hook.** The only build callback is
`OnStartBuild` (`Unit.lua:2838`), which fires when the factory *actually starts*
an item, not when it is queued; there is no `OnUnitCommand`/`OnCommandIssued` in
the sim at all. So charge-on-add must be done by **polling**
`unit:GetCommandQueue()` (`Unit.lua:5082`, returns orders carrying `commandType`
and `blueprintId`) and diffing against the previous tick's snapshot. All the
primitives to act on the diff exist and are confirmed callable:
- `brain:TakeResource('Mass'/'Energy', n)` / `brain:GiveResource('Mass'/'Energy', n)`
  — deduct on add, refund on native cancel (`GiveResource` already used at
  `Economy.lua:37`, `ACUUnit.lua:168`).
- `brain:GetEconomyStored('Mass'/'Energy')` — read the budget.
- `unit:SetBuildRate(0)` — the "never build" pin: 0 fraction/sec means nothing
  ever completes, and native drain is proportional to build rate so it is also
  zero. (`SetPaused(true)` is an alternative but the player can unpause it;
  build-rate 0 is safer, or re-pause each poll.)

**Recommended mechanism (resolves both, needs no queue reconstruction).** Per
player, each tick: (1) factory pinned at `SetBuildRate(0)`; (2) read
`GetCommandQueue()`, diff vs last snapshot — item **added** → `TakeResource`
its `BuildCostMass`/`BuildCostEnergy`, item **removed** (native queue-cancel,
which is free and uses real icons) → `GiveResource` refund; (3) if stored budget
falls below the cheapest allowed unit → `SetBlockCommandQueue(true)`, when income
lifts it back → `SetBlockCommandQueue(false)`. Because add is charged on the same
poll that blocks when broke, **the queue is self-limiting** — the player can
never commit more than the budget, and no specific queued item ever has to be
removed.

**The one engine gap this design sidesteps.** Factory build orders
(`commandType 7`, `BuildFactory`) have **no re-issue callback** in the stock
command helpers — `sim/commands/shared.lua:252` leaves `[7]` with no `Callback`;
only `BuildMobile` (8) has one (`IssueBuildAllMobile`, engineer-style). So
programmatically *rebuilding* a factory queue from the sim is not a solved
primitive; `IssueClearFactoryCommands({factory})` (clear-all) is the only sim
handle on the queue. Charge-on-add + block-when-broke means we only ever need
clear-all as a nuclear option, never surgical removal.

Caveats: poll every tick (0.1s) so a human cannot spam-queue faster than we
charge — worst case is one tick of slight over-commit, acceptable (let the budget
dip marginally rather than trimming). `TakeResource` floors stored at 0 (no
negative debt), which is fine because block-when-broke keeps committed cost ≤
stored anyway; the player's real resource bar then visibly reflects the reserved
cost, which is the intended UX.

## Open questions

1. ~~**Do units really get built, or is the queue itself the wave list?**~~
   **Resolved (2026-07-21):** queue-as-wave-list, factory pinned to never build,
   resources charged by the poll-and-charge mechanism above. See the resolution
   section.
2. **What drives mass income now that spawner structures are gone?**
   Working direction (2026-07-21): move to a **static, upgrade-proof** economy
   decoupled from ACU production, made of three script-granted streams:
   - **Flat ACU income** — every ACU grants a fixed baseline (e.g. +1 mass),
     *regardless of enhancements.* Motivation: the ACU natively produces mass and
     mods such as **BlackOps ACUs** add economy enhancements, so leaving income
     tied to native production makes it upgrade- and mod-dependent. Native ACU
     production is `Economy.ProductionPerSecondMass` applied via
     `SetProductionPerSecondMass` (`Unit.lua:308`, and re-applied with
     `MassProdAdjMod` at `Unit.lua:1270` when enhancements install). Neutralize it
     by calling `SetProductionPerSecondMass(0)`/`SetProductionPerSecondEnergy(0)`
     on the ACU each tick (the `lib/AcuRules.lua` tick loop already exists), then
     grant the flat baseline via `GiveResource`. Re-zeroing every tick makes it
     robust against any enhancement or mod that re-adds production.
   - **Mass per lane kill** — award mass to a player for each wave unit their side
     destroys. The killer already gets a callback: `instigator:OnKilledUnit(self)`
     (`Unit.lua:1602`). Since wave units live in the `ARMY_WAVE_n` armies, map the
     killing wave army back to its owning player and `GiveResource` the bounty.
   - **Controlled lane points** — marker-defined capture points along each lane
     (reuse the existing `LW_`-marker convention); a point "controlled" by a side
     grants recurring income (e.g. +2 mass per point per income tick). Control
     test = proximity/ownership of nearby units at the point, evaluated on the
     same tick as income.

   This replaces the old spawner-income and flat-scaling models entirely and gives
   Line Wars its own map-control economy loop. Open sub-questions: how "control"
   is decided (nearest live unit? presence within radius? contested = no income?),
   kill-bounty values per unit tier, and whether energy uses the same three
   streams or a simpler flat grant.
3. ~~**Does build time cap army size too aggressively?**~~ **Moot (2026-07-21):**
   the factory never builds (`SetBuildRate(0)`), so build time no longer gates
   anything — army size is gated purely by budget vs queued cost. Unit
   `BuildCostMass`/`BuildCostEnergy` are now the only relevant balance levers;
   `BuildTime`/factory `BuildRate` are irrelevant.
4. ~~**Should ACU assist be allowed?**~~ **Moot (2026-07-21):** assisting a
   factory pinned to build-rate 0 does nothing. (The 4x ACU build-rate buff in
   `lib/AcuRules.lua` still applies to the ACU's own building, unaffected.)
5. ~~**How many factories per player?**~~ **Resolved (2026-07-24): as many as you
   can pay for, and each one is bound to a lane.** Extra factories were the
   answer to two separate wants: reinforcing a teammate's lane, and mixing unit
   kinds (land vs air). So:
   - no factory is placed for the player any more — the ACU builds them, which
     makes *where* you build one a real decision;
   - `LW.Factories[armyName]` is keyed by the factory unit, each with its own
     `committed` queue, its own `kind` (LAND/AIR) and its own `lane`. Reconcile,
     the affordability rebuild (`IssueClearCommands` + `IssueBuildFactory`) and
     the block-when-broke check are all per factory, which also removes the old
     residual where a rebuild consolidated every queue onto the primary factory;
   - a factory's lane is decided once, when it finishes building, by nearest lane
     *axis* (the segment between that lane's two Core markers) among lanes held by
     a living player on the builder's side. Its wave spawns at that lane's spawn
     marker and marches that lane, while staying in the builder's own
     `ARMY_WAVE_n` — already allied to that whole side, so no alliance work.
   - a factory that dies refunds everything still paid for in its queue.

   Open sub-question: nothing stops a player putting *all* their factories in a
   teammate's lane and leaving their own Core naked. That is arguably a valid (if
   desperate) team play, so it is left alone until a game says otherwise.

6b. **`SetBlockCommandQueue` is unusable as an affordability gate** (found
   2026-07-24, from `game_27471277.log`). It blocks sim-issued orders, not just
   the player's clicks, so the rejection rebuild (`IssueClearCommands` +
   `IssueBuildFactory`) was swallowed whenever the flag was set — the queue
   emptied, and the next tick read that as "player cancelled everything" and
   refunded the whole standing wave. It fired only on AIR because the block
   threshold was the cheapest unit of that factory kind, and a bomber's stock
   **2050 energy** against a 3900 cap kept air factories permanently "broke"
   (land's threshold is 20 mass / 80 energy, and the log shows land taking 0
   refunds against `ura0103`'s 42). `FactoryUnit` also drives that flag itself in
   `IdleState`, `FinishBuildThread` and `RolloffBody` (`FactoryUnit.lua:263, 386,
   424`), so a per-tick setter fights the factory's state machine. **The flag is
   now unused**; affordability is enforced only per unit, and a rebuild is
   verified on the following tick (retry x3) before its absence is believed.

7. **Can an assisting ACU force a pinned factory to build?** Open question 4
   assumed not. That assumption is untested, and it matters more now that players
   site their own factories and will naturally assist them. Rather than resolve
   it, `FactoryQueue.PurgeStrayUnits` destroys any wave-type unit found in a
   player army on every tick: if an assist ever does complete an order, the diff
   refunds the queue slot and the unit is deleted, so assisting is self-defeating
   instead of exploitable. Worth confirming in-game which of the two is happening.

   2026-07-24: Kamikaze found that spam-clicking a bomber fast enough occasionally
   *did* produce one or two real units, i.e. `SetBuildRate(0)` alone was not
   holding under queue churn. Factories are now **also `SetPaused(true)`**, and
   both locks are re-applied every tick rather than once at adoption (a player can
   press unpause, and the factory's own state machine resets flags behind us).
   Pause is the right primitive here: it stops progress while *keeping* the queue,
   which is exactly the semantics this design wants.
6. ~~**Rally point behaviour.**~~ **Moot (2026-07-21):** no unit ever completes,
   so there is no completed-unit pop or stray movement to worry about.

## Abandoned: cloned blueprints

Recorded so it is not re-attempted blind.

The previous attempt defined **new** unit blueprints from a map, cloning the T1
Power Generator. Confirmed possible: `StoreBlueprint` only merges when the id
already exists and `Merge` is set, otherwise it stores outright, and
`UnitBlueprint()` → `SetShortId()` honours an explicit `BlueprintId`. The engine
does synthesise `categories.<newid>` for custom ids — the buttons appeared and
the build restriction accepted them.

It was abandoned for two reasons:

- **Placeholder art is unavoidable.** `construction.lua:574` and `:766` build
  the icon path from the blueprint id, falling back to
  `/icons/units/default_icon.dds` — which is literally an image reading
  "Place Holder". Four identical placeholder tiles is unacceptable for the
  primary interface of the mode.
- **An unresolved hang/crash** when selecting one of the cloned build icons. The
  game log contains **no error** at the point it dies. Note that
  `GetResource: Invalid name ""` and `Invalid type for RMeshBlueprintLOD` appear
  in *every* log including runs predating this work — they are pre-existing
  noise from the other enabled mods, not the cause. Never confirmed whether the
  hang was inherent to map-defined blueprints or an interaction with the
  BlackOps / Nuclear Repulsor Shields / Nomads mods in the load order; testing
  with those disabled was the outstanding diagnostic.

Two real bugs were found and fixed along the way and are worth keeping in mind
if blueprint work resumes:

- **`bp.Source` is load-bearing, not bookkeeping.** The engine derives asset
  paths from it: `ExtractMeshBlueprint` (`Blueprints.lua:507`) builds the mesh id
  as `gsub(bp.Source, "_[a-z]+%.bp$", "_mesh")` and resolves the `.scm` LODs
  relative to it, and a unit's script is found as `<source dir>/<id>_script.lua`.
  Clearing it on a clone points both at the map folder, where no such files exist.
- **`Unit:DoDeathWeapon()` iterates `bp.Weapon` with no nil guard**
  (`sim/Unit.lua`). Removing a unit's weapons must use `{}`, not `nil`, or every
  death throws.

## Fixed regardless of which design wins

`units/LineWars_spawners_unit.bp` never actually worked before 2026-07-20 — the
build-menu descriptions and economy overrides were silently failing. Cause:
`debug.getinfo` returns a **backslash-separated OS path** under wine
(`z:\home\...\units\linewars_spawners_unit.bp`), but the path-stripping pattern
used forward slashes, and `doscript` resolves through the **VFS** (`/maps/<name>/`)
rather than the OS filesystem. The file threw on its `doscript` line every run
and the loader's `safecall` swallowed it. Now fixed by taking only the map folder
name and rebuilding a VFS path. If this design is adopted the file may go away
entirely, but the lesson applies to any map-side `.bp`.
