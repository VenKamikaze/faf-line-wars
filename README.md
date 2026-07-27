# FAF Line Wars

A Line Wars game mode (WC3 / SC2 Nexus-Wars style) for Supreme Commander:
Forged Alliance Forever, implemented as a scripted skirmish map.

**The loop:** timed rounds. During each build phase you build factories with your
ACU and queue units in them; the queue never actually builds, it *is* your
standing wave, paid for the moment you queue it. When the round ends every
factory's queue spawns and marches down its lane attack-moving everything it
meets. Destroy the enemy Core at the far end before your own falls. Up to three
lanes, each a mirrored 1v1 (lobby slots 1v2, 3v4, 5v6) — but a factory built in a
teammate's lane reinforces *that* lane, so a team can gang up on one duel.

It is a **map, not a mod** — players just pick it in the lobby, with nothing to
enable. Keeping it that way constrains some of the design; see
[Engine findings](#engine-findings).

## Status

- [x] Script framework scaffolded
- [x] `LineWars-2p.scmap` + `_save.lua` built in FAFMapEditor (lane 1 only)
- [x] First in-game smoke test — round loop, income and wave march confirmed
- [x] Cores spawn and register death triggers
- [x] ACU rules: 4x build/move, no-build zones, midline return
- [x] Factory-queue model replaces spawner structures (`lib/FactoryQueue.lua`)
- [x] Per-round storage growth (`lib/CoreStorage.lua`, mass 216/316/416 …, energy 3900/4400/4900 …)
- [x] Player-sited factories, one queue each, lane-bound by where they stand
- [x] Air factory + attack bombers + interceptors (air-to-air counter)
- [x] Lane capture points (`lib/CapturePoints.lua`) — land units capture, income to the side
- [x] In-game test of ally-lane reinforcement and the air factory
- [ ] Static economy remainder: flat ACU income, kill bounties
- [x] Lanes 2 and 3 markers (ally reinforcement is untestable until lane 2 exists)
- [x] Tech 2: land and air factory upgrades, with a unit set behind each
- [ ] Balance pass using [UNITS.md](UNITS.md)
- [x] Defense structures: T1/T2/T3 Point Defense, T1/T2/T3 AA, T2 Shield, built directly by the ACU on its own side of the lane
- [x] Tech 3: land and air factory upgrades, symmetric roles + one signature unit per faction per domain
- [x] In-game test of tier 3 and of the differential upgrade-cost fix
- [x] ACU-built experimentals (one per faction, tech-3 gated, handed to the wave army on completion)
- [x] Core energy output ramps with the round instead of a flat 2500 e/s

## Layout

```
LineWars-2p.v0001/            the map folder FAF loads
  LineWars-2p_scenario.lua    armies, teams, ExtraArmies, file paths
  LineWars-2p_options.lua     lobby options: income model, round length, Core HP
  LineWars-2p_script.lua      entry point: OnPopulate/OnStart, alliances, wiring
  LineWars-2p.scmap           map file created by FAFMapEditor, 512x256 (10x5 km)
  LineWars-2p_save.lua        armies + markers, written by FAFMapEditor
  units/
    LineWars_units.bp         storage, factory/unit cost merges + the cross-faction Ravager
  lib/
    Config.lua                all tuning + army/lane/marker contract
    UnitTypes.lua             factories/units + the ACU-built defense structures (the balance table)
    FactoryQueue.lua          per-factory queues: charge, refund, lane binding
    RoundManager.lua          round timer loop + announcements
    WaveSpawner.lua           wave spawning, platoon march orders, idle watchdog
    Economy.lua               income models (spawner income / flat scaling)
    CapturePoints.lua         LW_Cap zones: land units capture, side earns income
    ChatCommands.lua          reads chat sim-side and dispatches /commands
    Sos.lua                   /sos: one lane-wipe per player per game
    Hud.lua                   how-to-play card at start + the live scoreboard
    CoreStorage.lua           per-round mass + energy storage growth on each Core
    WinCondition.lua          Cores, elimination, side victory
    AcuRules.lua              ACU buffs, no-build zones (with a defense-structure carve-out), midline rule
    SpawnerTypes.lua          dead: the abandoned spawner-structure design
UNITS.md                      generated balance reference (every buildable unit)
tools/gen-units-md.py         regenerates UNITS.md from UnitTypes.lua + gamedata
FACTORY-QUEUE-DESIGN.md       the factory-queue design, with engine citations
lua-examples/                 reference maps/mods (Wave of Death, The Great Pass, KotH)
deployed-map                  symlink to the deployed copy under ~/Games/faf-linux
backup/                       pre-rename snapshots of the map files
```

`lib/*.lua` are imported with `ScenarioInfo.directory` and fall back to a
hardcoded `'/maps/LineWars-2p.v0001/'`, so **renaming the map folder means
editing that fallback in every lib file**. `.bp` files under `units/` are the
exception: they run in the blueprint loader before `ScenarioInfo` exists, so they
must not reference it at all.

## Map contract

Everything the script needs from the `.scmap` is markers. All are **Blank
Markers** placed in FAFMapEditor; names are case-sensitive and must match
exactly. Missing markers are handled gracefully (WARN + skip) rather than
crashing, except spawn/Core markers for an occupied slot.

| Marker | Purpose | Required |
| --- | --- | --- |
| `LW_L<lane>_Core_<side>` | where that side's Core is placed | yes, per occupied slot |
| `LW_L<lane>_Spawn_<side>` | where that side's wave appears | yes, per occupied slot |
| `LW_L<lane>_Wp<n>_<side>` | optional path points, walked in order before the enemy Core | no |
| `LW_NoBuild<i>_A` / `_B` | opposite corners of an axis-aligned no-build rectangle | no |
| `LW_L<lane>_Cap<n>` | centre of a capture point (fixed radius `CapturePointRadius`) | no |
| `LW_L<lane>_Cap<n>+` … `+++` | same, but a high-value point: each `+` steps the mass+energy payout up a multiple (`+` = x2, `++` = x3, `+++` = x4) | no |

`<lane>` is 1..3, `<side>` is `A` or `B`. Waypoints and capture points are probed
per lane from `n = 1` upward and stop at the first gap; no-build zones from
`i = 1` likewise — so numbering must not skip. Each capture `n` is probed in all
four `+` forms, so renaming `Cap4` to `Cap4++` does not read as a gap; give a
point at most one name. Capture markers are read only for
lanes that have a player, so an empty lane's points never activate.

Armies in `_save.lua` must be `ARMY_1`..`ARMY_6` plus `ARMY_WAVE_1`..`ARMY_WAVE_6`,
and the wave armies must also be listed in `_scenario.lua` under
`customprops.ExtraArmies`.

### Lane 1 as currently built (512x256 map)

```
        x=55.5              x=151.5          x=327.5            x=423.5
        Core_A              Spawn_A          Spawn_B            Core_B
  |------[A]-----------------[*]==============[*]-----------------[B]------|
        <-- A builds here -->|<- no-build 1 ->|<-- B builds here -->
```

All lane-1 markers sit at z ≈ 191.5. `LW_NoBuild1` spans x 151.5–327.5,
z 128.5–255.5 — i.e. exactly the corridor between the two spawn points, so
neither player can wall off the lane. Each player's buildable ground is the
strip behind their own spawn marker.

Lanes 2 and 3 have no markers yet, so **only lobby slots 1 and 2 are usable**.
A player in slots 3–6 gets a WARN and no Core, and the first wave they try to
spawn throws — `WaveSpawner` calls `MarkerToPosition` on the spawn and Core
markers, which errors rather than returning nil. Guarding that is worth doing
when lanes 2 and 3 go in.

## Game rules

### Rounds

`RoundManager` waits `InitialGraceSeconds` (5s), then loops: announce the build
phase, count down (30s and 10s warnings), then spawn every living player's wave
and increment the round. Round length is a lobby option, default 60s.

### Economy

No mass extractors and no reclaim — **all income is script-granted** by
`Economy.lua` on a 1s tick, so income is exactly what the design says it is.

| | Model 1 — spawner income (default) | Model 2 — flat, scales per round |
| --- | --- | --- |
| Mass/s | `BaseMassIncome` + sum of each completed spawner's `income` | `BaseMassIncome × (1 + 0.25 × (round − 1))` |
| Effect | Nexus-Wars style: spawners are both army *and* investment | Everyone earns the same; spawners are army only |

Both models grant a flat `BaseEnergyIncome` (100/s). Starting resources are 150
mass / 500 energy.

**Income growth is a lobby option, applied to mass and energy alike.** Two paired
options drive it: **Income growth interval** (Never / every 1–10 rounds, default
every 4) and **Income growth step** (25–200% of base, default 50%). A step lands
**on each multiple of the interval** — at the default of 4 that is rounds 4, 8,
12, 16. Steps are **additive on the base, not compounding**: at the defaults you
earn 100% of base for rounds 1–3, 150% from round 4, 200% from round 8, which is
a straight line rather than a curve that runs away by round 20.
`Config.IncomeGrowthMultiplier`
is the single source; `Economy.lua` folds it into the same bracket as income
model 2's own per-round growth so the two curves add instead of multiplying.

**The Core pays a flat energy income.** The Core is a UEF T3 power generator
(`ueb1301`), which at stock produces **2500 e/s** from the moment it is spawned —
twenty-five times `BaseEnergyIncome`, which is why the "energy is the scarce
resource" reasoning behind the 1:5 unit prices never really bit in play.
`CoreStorage.ApplyCoreEnergy` sets each Core to `Config.CoreEnergyForRound(round)`
= `CoreEnergyBase` (**500**) plus `CoreEnergyPerRound` for each round after the
first, capped at `CoreEnergyMax`. Applied once from `WinCondition.SpawnCores` (so
the start delay isn't free energy) and again at the top of every round.

**`CoreEnergyPerRound` is 0, so that ramp is deliberately switched off** — economy
growth belongs in one place and that place is the two lobby options above. The
machinery is kept rather than deleted: set `CoreEnergyPerRound` non-zero and the
Core scales again with no other change.

This uses the live engine setter `Unit:SetProductionPerSecondEnergy`, **not** a
`.bp` merge, deliberately: a map blueprint merge on `ueb1301` would be silently
overridden by a unit-overhaul mod, whereas the setter reaches the engine directly
whatever is loaded. Nothing re-applies the blueprint value behind it —
`Unit.UpdateProductionValues` (`sim/Unit.lua:1265`) only runs when an
energy/mass-production *buff* is applied or removed, and the map never buffs a
Core. Total round-1 energy income is therefore ~620/s (Core 500 +
`BaseEnergyIncome` 100 + the ACU's stock 20), before capture points.

Two caveats now that spawner structures are gone: **model 1 is currently
identical to a flat `BaseMassIncome`** (there are no spawners left to add income),
and the ACU gifts its own `StorageMass` as mass at warp-in, so you actually start
with ~216 mass rather than 150. Replacing this whole section with the static
economy (flat ACU income, kill bounties, lane capture points) is the next design
task — see [FACTORY-QUEUE-DESIGN.md](FACTORY-QUEUE-DESIGN.md) open question 2.

**Storage is the real budget cap.** `lib/CoreStorage.lua` stacks a hidden,
invulnerable mass-storage building **and** an energy-storage one on each Core at
the start of every round after the first, so your ceilings are
216 / 316 / 416 … mass and 3900 / 4400 / 4900 … energy. The amounts live in
`units/LineWars_units.bp`; note those merges lose to unit-overhaul mods, so play
Line Wars without BlackOps/Total Mayhem or the caps silently revert.

The energy step was added with tier 3 (2026-07-26). Before it, energy storage was
a flat 3900 all game — the ACU's alone — and because `FactoryQueue` charges a
queued unit's full energy price **atomically**, nothing dearer than 3900e could
ever be queued however long you saved. On the map's ~1:5 mass:energy pricing that
was a hard ceiling of 780 mass per unit, which no T3 unit fits under.

`SetResourceSharing(false)` is set per brain, so allies on the same side cannot
prop each other up.

#### Capture points

`lib/CapturePoints.lua` turns every `LW_L<lane>_Cap<n>` marker into a fixed-radius
(`CapturePointRadius`, 12) circular objective, but only for lanes that have a
player. Detection reuses King of the Hill's
`GetUnitsAroundPoint(LAND*MOBILE-COMMAND, centre, radius, 'Ally')` — so only
**mobile land waves capture** (air waves are `AIR`, not `LAND`; the ACU is
excluded too, so you can't hold a point by parking your commander). Control is
**side-based** (A vs B), so a reinforcing ally's
wave can capture too — but income is **lane-local**: only the controlling side's
player *in that lane* earns it, not distant teammates. A point held by a
reinforcing ally when the lane's own player is dead pays nobody.

The rate is the **Capture point income** lobby option, a multiplier
(`Config.CaptureIncomeScales`) on `CapturePointMass` (2/s) and
`CapturePointEnergy` (25/s). Each rung is half the one above, so every step is
50% either way: `High` is the flat rate the map used before this was an option
and `Average` — the default — is half of it, because a full-strength point pile
scaled income up far too fast in play. To rebalance, edit that one table.

| Setting | Multiplier | Mass/s | Energy/s |
| --- | --- | --- | --- |
| Very low | 0.125 | 0.25 | 3.1 |
| Low | 0.25 | 0.5 | 6.3 |
| **Average** (default) | 0.5 | 1 | 12.5 |
| High | 1.0 | 2 | 25 |
| Very high | 2.0 | 4 | 50 |

**High-value points.** Append up to three `+` to a marker name to multiply that
point's mass *and* energy payout on top of the lobby scale: `LW_L1_Cap4+` pays
x2, `Cap4++` x3, `Cap4+++` x4. Such a point draws its ring with that
many concentric lines — a x3 point is visibly bolder than a plain one — so the
prize is readable on the map without a legend.

Control is **sticky**: a land unit only has to *pass through* the circle to
capture it — it need not stay — and the point remains that side's until it is
**contested** (both sides have a unit inside at once, which suspends income and
clears control) or the enemy takes it alone. A debug-draw ring shows the state:
red for A, blue for B (from `Config.SideColors`), yellow contested, grey neutral.
FA has no per-unit colour override, so the ring — the same mechanism KotH uses —
is the visual rather than a colour-flipping structure. Place the `LW_Cap`
markers on contested ground in FAFMapEditor; with none placed the module is a
no-op.

### Factories and the wave queue

Your ACU builds factories; nothing is placed for you. A factory is pinned to
`SetBuildRate(0)` **and** `SetPaused(true)`, re-applied every tick, and never
produces anything — **its build queue is your standing wave**.
`lib/FactoryQueue.lua` polls `GetCommandQueue()` every 0.1s, diffs it, and:

- charges mass and energy the instant a unit is queued, one unit at a time and
  only if you can fully afford it (an unaffordable add is rejected and that
  factory's queue rebuilt from the paid set, which is why you can't buy a tank
  for 1 mass);
- refunds anything you cancel — and everything still paid for in a factory that
  dies, however it died;
- verifies on the next tick that a rebuild actually landed, retrying up to three
  times before it will believe the queue and refund.

`SetBlockCommandQueue` is deliberately **not** used as a "you're broke" early-out.
It blocks the script's own `IssueBuildFactory` as well as the player's clicks, so
a rebuild issued while blocked vanished and the next tick refunded the entire
standing wave — the bug that made every air factory refund on loop, since a
bomber's stock 2050 energy kept air factories permanently past the threshold.
`FactoryUnit`'s own `IdleState`/`RolloffBody` drive that flag too
(`FactoryUnit.lua:263, 386, 424`), so setting it per tick fought the factory's
state machine.

The queue is **persistent**: pay once, and it spawns every round until you cancel
it. Which units each factory offers is `lib/UnitTypes.lua` — the ACU's build
restriction is derived from it, so a land factory shows only land roles and an
air factory only air ones. See [UNITS.md](UNITS.md) for the full list with costs.

**Tech tiers** use the stock factory **upgrade button**, for the same reason the
whole model uses stock units: the art already exists. Because a pinned factory
never progresses an order, the upgrade sits in its queue and `FactoryQueue`
intercepts it — validates it is the exact next tier for that building, charges
the upgrade cost, then swaps the building in place, carrying the lane
binding and the paid wave across. It is instant, so there is no cancel window.
Tier gating of the *units* is then free: a T1 building's `BuildableCategory` is
`BUILTBYTIER1FACTORY`, which no T2 unit carries, so "upgrade before you can build
this" is enforced by the engine, not by script.

**The upgrade cost is a *differential*, and getting that wrong was a real bug.**
Every stock factory above tier 1 sets `Economy.DifferentialUpgradeCostCalculation
= true`, and `Game.GetConstructEconomyModel` (`lua/game.lua:57`) then prices the
upgrade as the target's cost **minus the cost of the building being upgraded** —
that is what the upgrade button's tooltip shows
(`unitviewDetail.lua:856` passes the builder's own Economy as the third
argument). Until 2026-07-26 `FactoryQueue` charged the target's *full* blueprint
cost, so the T2 air upgrade advertised 200 mass and silently demanded 350: the
click was rejected as unaffordable with nothing on screen to explain it.
`FactoryQueue.UpgradeCost` now applies the same differential. Consequence for
tuning: the numbers in `units/LineWars_units.bp` are **not** the price — set
them so the *difference* between consecutive tiers is what you want charged, and
read the `Pay` columns in [UNITS.md](UNITS.md) to check.

| Factory | Upgrade | Charged | Unlocks |
| --- | --- | ---: | --- |
| Land | Land Factory HQ (T2) | 250m / 1200e | Heavy Tank, Mobile Missile Launcher, Mobile Flak |
| Land | Land Factory HQ (T3) | 500m / 2500e | Siege Assault Bot, Heavy Artillery, T3 Mobile AA, Mobile Shield, Faction Special |
| Air | Air Factory HQ (T2) | 350m / 1750e | Gunship, Fighter/Bomber |
| Air | Air Factory HQ (T3) | 650m / 3250e | Air Superiority Fighter, Heavy Air |

**Tier 3 rosters.** Land gets three symmetric roles — Siege Assault Bot
(Titan / Harbinger / Loyalist / Othuum), mobile Heavy Artillery, and T3 Mobile AA
— plus the Mobile Shield Generator, the one T3 unit that changes how a wave
behaves rather than how hard it hits. Air gets the air-superiority fighter
(`*a0303`).

Each faction then gets **one signature unit** per domain. On land that is
deliberately asymmetric: UEF **Percival** and Cybran **The Brick** are heavy
brawlers, Aeon **Sprite Striker** and Seraphim **Usha-Ah** are long-range
snipers. In the air, UEF **Broadsword** and Cybran **Wailer** are the two stock
T3 heavy gunships; Aeon has no gunship so it gets the **Restorer**, and Seraphim
has neither, so it gets the **Sinntha** strategic bomber.

Two roster ids look wrong and are not: the T3 mobile AA units are `delk002`
(Cougar), `dalk003` (Redeemer), `drlk001` (Bouncer) and `dslk004` (Uyanah) —
expansion-pack blueprints, exactly like the T2 fighter/bombers below, and live in
FAF (build-mode hotkeys, AI platoon templates, balance changelogs).

**The mass cap, not income, is what gates T3.** At 216 + 100/round a 480-mass
Titan arrives around round 4 and an 840-mass Othuum around round 7, but the
1280–1750 mass signature units are rounds 12–16. That is intended (they should
be a late-game statement) but it is the dial to turn if T3 feels out of reach:
either add `BuildCostMass` overrides in `units/LineWars_units.bp` or grow the
per-round storage step there.

The fighter/bombers are the expansion-pack airframes — `dea0202` Janus (UEF),
`xaa0202` Swift Wind (Aeon), `dra0202` Corsair (Cybran), `xsa0202` Notha
(Seraphim). Those prefixes are correct, not typos: only the Seraphim one follows
the `uea`/`uaa`/`ura`/`xsa` pattern the rest of the roster uses. All four are live
FAF units with real icons and meshes. Aeon's is the exception in role as well —
Swift Wind is a pure air-to-air Combat Fighter and drops no bombs.

Every tier building must be in `AllowedCategories` (it is — `AllFactoryIds`
includes the tier ids) or the map's own `AddRestriction` destroys the upgraded
building the instant it appears.

**Factories are lane-bound.** When a factory finishes building it is bound to the
friendly lane whose axis it stands closest to — the segment between that lane's
two Core markers, so a factory pushed forward still reads as its own lane.
Candidates are only lanes held by a living player on your side, so:

- build near your own Core (the normal case) and you feed your own lane;
- walk into a teammate's lane, build there, and that factory's wave spawns at
  *their* spawn marker and marches *their* lane. The units stay in your own
  `ARMY_WAVE_n`, which is allied to that whole side, so they simply fight
  alongside your teammate's wave.

Each factory is an independent queue, so you can run a tank line at home and a
bomber line in a teammate's lane at the same time.

Wave units are created into the per-player `ARMY_WAVE_n` army, assigned to a
platoon, and given `AggressiveMoveToLocation` through the waypoints to the enemy
Core. A 10s watchdog re-issues orders to any idle wave unit, since platoons can
finish their orders or trip over pathing while enemies remain; idle units are
re-pathed down the lane they are *standing in*, so reinforcements aren't dragged
home.

One hole the design has to plug: an ACU assisting a pinned factory is the only
way an order could still reach completion. `PurgeStrayUnits` destroys any
wave-type unit found in a player army each tick, so assisting refunds the queue
slot and gives you nothing — self-defeating rather than exploitable.

### ACU rules

The ACU is the only builder. `AcuRules.lua` applies a `BuffBlueprint` giving 4x
`BuildRate` and 4x `MoveMult` — this mode is about what you queue, not about
walking, and the speed is what makes siting a factory in a teammate's lane a
practical choice rather than a round-long trek. A 1s tick then enforces:

- **No-build zones** — structures inside a zone are refunded pro-rata by
  `GetFractionComplete()` and destroyed, so a misclick is not a death sentence.
  Factories are **not** exempt: a factory is exactly what you'd wall a lane with,
  and losing one refunds its paid queue as well.
- **Midline rule** — an ACU closer to the enemy Core marker than its own is
  `Warp()`ed back to `MidlineReturnOffset` (10) in front of its own Core, so you
  cannot rush the enemy with your commander.
- **Defense-structure carve-out** — the ACU may also build seven faction-matched
  defense structures directly (T1/T2/T3 Point Defense, T1/T2/T3 AA, T2 Shield;
  see [UNITS.md](UNITS.md)). Unlike everything else, these ARE allowed inside a
  no-build zone — that's the point, it's how you hold a forward choke — but
  never past the midline of the lane they're actually sited in. Checked on the
  structure's own position (not the ACU's), using the same Core-distance test
  as the midline rule above, generalized to whichever lane the position is
  actually nearest (`FactoryQueue.LaneForPosition`, the same rule factories use
  for lane binding — so one built in a teammate's reinforced lane is judged by
  that lane's Cores). A structure that ends up past the midline is refunded
  pro-rata and destroyed, exactly like any other no-build-zone violation. **The
  tier column is a real gate, and the engine applies it** — a pre-upgrade ACU
  does not show T3 items in its build menu (original SupCom behaviour, confirmed
  in game). Note the blueprints alone would suggest otherwise: the stock
  `BuildableCategory` carries `BUILTBYCOMMANDER`, `BUILTBYTIER2COMMANDER` **and**
  `BUILTBYTIER3COMMANDER` from the start with no prerequisite
  (`UEL0001_unit.bp:227-231`), so do not conclude from that line that T3 is
  ungated. These use the engine's own
  construction economy (cost drains gradually over `BuildTime`, gated normally)
  rather than `FactoryQueue`'s charge/refund machinery, since the ACU builds
  them directly instead of queuing them.

**ACU tech upgrades** are the stock enhancements and are optional (nothing in
the map gates on them; they buy build rate, health and regen). The tech-3 one,
`T3Engineering`, is repriced by `units/LineWars_units.bp` from stock 2400 mass
to **1500** — a nested `Enhancements` merge, which `BlueprintMerged` recurses
into, so only that one field moves. Enhancement costs are absolute, not
differential like the factory upgrades, and are paid off gradually over
`BuildTime` rather than charged atomically, so the energy half (left at stock
50000, against 100 e/s base income) is the real gate rather than the army energy
cap. Its prerequisite `AdvancedEngineering` is untouched at 800m/21000e.

  **T3 Point Defense is one building for everyone.** Stock FA ships exactly one,
  the UEF **Ravager** (`xeb2306`), and an ACU's `BuildableCategory` is
  faction-scoped (`"BUILTBYTIER3COMMANDER CYBRAN"`), so only a UEF ACU could
  reach it. `units/LineWars_units.bp` appends `AEON`/`CYBRAN`/`SERAPHIM` to its
  `Categories` — at explicit indices 18–20, because `BlueprintMerged`
  (`lua/system/Blueprints.lua:91`) merges key by key and a plain list would
  overwrite the first three stock entries — so every ACU's expression matches
  it. It keeps its UEF model and name whoever builds it, which is cosmetic and
  intended. Its stock 2000m/17600e is 3.7x the T2 Point Defense; Line Wars
  prices it at exactly 2x (1080m/7560e), the same step stock uses between T2 and
  T3 AA. If a unit-overhaul mod with real per-faction T3 PD is loaded its ids
  aren't in `UnitTypes.AcuStructures`, so the map hides them and the Ravager
  stays — one more reason to play without those mods.

### ACU experimentals

`lib/Experimentals.lua`. One land experimental per faction, built **directly by
the ACU** like the defense structures, but with two twists: it is gated behind
the ACU's tech-3 upgrade, and the player never gets to drive it.

| Faction | Unit | Blueprint | Mass | Energy |
| --- | --- | --- | ---: | ---: |
| UEF | Fatboy | `uel0401` | 7000 | 70000 |
| Aeon | Galactic Colossus | `ual0401` | 6875 | 68750 |
| Cybran | Monkeylord | `url0402` | 5000 | 52000 |
| Seraphim | Ythotha | `xsl0401` | 6625 | 66000 |

Costs are a **quarter of stock mass and a fifth of stock energy** — the one group
in `units/LineWars_units.bp` that overrides mass, and the one that is not on the
map's ~1:5 curve.

- **Faction locking is free.** All four already carry both
  `BUILTBYTIER3COMMANDER` and their own faction category, and every ACU's stock
  `BuildableCategory` is `{"BUILTBYCOMMANDER <F>", "BUILTBYTIER2COMMANDER <F>",
  "BUILTBYTIER3COMMANDER <F>"}` — so a Cybran ACU can only ever match the
  Monkeylord, with no blueprint merge (unlike the Ravager above).
- **The tier gate is the engine's; the script's is belt-and-braces.** The
  blueprints read as if T3 were ungated — that third term is present from tick 0
  with no prerequisite, and `T3Engineering`'s `BuildableCategoryAdds` is the
  identical string — but the engine does hide T3 items from a pre-upgrade ACU's
  build menu regardless. `lib/Experimentals.lua` adds a second gate anyway (the
  `AddRestriction`/`RemoveRestriction` pattern `lib/AirGate.lua` uses, lifted per
  army once `acu:HasEnhancement('T3Engineering')` goes true, polled on
  `Config.ExperimentalTickSeconds` — there is no enhancement-finished callback a
  map can reach). It is behind `Config.ExperimentalsScriptTierGate`: a stuck
  script gate fails to "never buildable at all", so turn the flag off and rely on
  the engine if the unlock ever misfires. The completion sweep runs either way.
- **Ownership transfers on completion.** The same 1s loop sweeps the player's
  army for a complete experimental and hands it to their `ARMY_WAVE_n` via
  `SimUtils.TransferUnitsOwnership` (`lua/SimUtils.lua:246`), which carries
  health, veterancy and orientation across, and — the reason to use it rather
  than `ChangeUnitArmy` directly — handles the Fatboy's `ExternalFactory` child
  explicitly. It returns **new** units; the originals are gone. `WaveSpawner`
  gained `MarchUnits(armyName, lane, units)` so the new unit is sent down its
  lane immediately rather than waiting up to 10s for the idle watchdog.
  Candidates are sorted by cached `.EntityId` before transferring, because each
  transfer allocates a new entity id and that order is sim state.
- **A third `UnitTypes` table, `AcuExperimentals`.** These ids must stay out of
  `AllUnitIds()` for the same reason `AcuStructures` does: it feeds
  `FactoryQueue.WaveCategory()` and hence `PurgeStrayUnits`, which `Destroy()`s
  any unit of that category found in a player army every tick — and a half-built
  experimental legitimately sits there for minutes.
- **No no-build/midline handling.** `AcuRules`' sweep only walks
  `categories.STRUCTURE`, and these are `MOBILE`. One sited inside a no-build
  corridor leaves under its own orders within the second, so there is nothing to
  wall a lane with.
- **Build time is left at stock.** A pre-upgrade ACU (build rate 10 x
  `AcuBuildRateMult` 4) would take ~20 minutes on a Fatboy, but `T3Engineering`
  sets `NewBuildRate = 100`, so a tech-3 ACU is at ~2 minutes. The gate pays for
  itself.

### Win condition

`ScenarioInfo.Options.Victory = 'sandbox'` disables the standard skirmish
conditions; the script owns win/loss entirely. Each player gets a Core at their
lane's Core marker, made non-capturable and non-reclaimable, with health
multiplied by `CoreBaseHealthMultiplier` (10) × the lobby option. Core death
eliminates that player and kills both their army and their wave army. A side
wins when every player on the other side is out.

Alliances are dictated by **start position, not lobby teams**: same side = ally,
opposite side = enemy, and each player is allied to their own wave army.

**Wave colours are dictated by side.** `Config.SideColors` forces side A red and
side B blue via `SetArmyColor`, applied to the `ARMY_WAVE_n` armies only. Players
keep their lobby colours, so you can still tell teammates apart, while the
zoomed-out tactical view shows the push and pull of every lane in two colours.

### SOS (chat command)

A player types **`/sos`** in chat to detonate the **mobile** units standing in
the lane they started in. Structures (Cores, factories, lane towers, ACU-built
defences) are always untouched, and no ACU dies unless
`Config.SosKillsCommander` is set. The charge is spent even if the lane happens
to be empty, and everyone sees a global announcement naming the caller and the
lane (`L1 (middle)` / `L2 (top)` / `L3 (bottom)`).

Two lobby options shape it. **SOS uses per player** (default 1; `None` disables
the command, which then explains itself rather than silently doing nothing).
**SOS destroys** picks between *enemy units only* — clears the push and leaves
your own wave standing — and *every unit in the lane*, which kills your own wave
and any ally reinforcing you as well, so pressing it costs you the units you
already paid for.

"In the lane" means nearest **lane axis** (`FactoryQueue.LaneForAnyPosition`),
the same measure factories are bound by, so a teammate's reinforcing wave
marching through the lane is caught too. Victims are sorted by `.EntityId`
before being killed: death weapons damage neighbours, so kill order reaches sim
state and must not depend on engine list order (the usual desync rule).

The command reaches the sim without any UI code — see *Engine findings* below
for how, and `lib/ChatCommands.lua` for the citations. Tunables:
`Config.SosCommand`, `SosCharges`, `SosKillsCommander`.

### Scoreboard and the how-to-play card

`lib/Hud.lua` prints a plain-ASCII how-to-play card at map start
(`Config.IntroDurationSeconds`, default 30s) and then repaints a scoreboard —
one row per player: nickname, lane, capture points held in their own lane, SOS
charges left — every `Config.ScoreboardPeriodSeconds`.

A map cannot ship UI lua, and the objectives panel is campaign-only
(`gamemain.lua:305` gates `objectives2.CreateUI` behind `campaignMode`), so
`PrintText` is the entire toolbox. `textdisplay.PrintToScreen` pools text
controls per screen location and reuses the first **inactive** one, appending a
new control when they are all still live, so a repeating display must satisfy

```
ScoreboardPeriodSeconds > ScoreboardLineDuration + 1     -- +1s = the alpha fade
```

or it grows a fresh set of rows every cycle, forever. Obeying it costs one
fade-out/fade-in per cycle; both values are Config tunables because the
flicker-versus-freshness trade is a taste call. The board owns `'lefttop'` —
keep it off `'center'`, which `RoundManager` and `CapturePoints` write to.

**The period must be measured in real seconds, not with `WaitSeconds`.**
`WaitSeconds` counts *game* time, which speeds up and slows down with the `+`/`-`
sim-speed keys, while textdisplay's fade counts *real* time. Pacing the board with
`WaitSeconds(12)` therefore broke its own rule the moment the sim was sped up — at
10x the period is 1.2 real seconds against a 10-second fade, so every cycle
appended a whole new set of rows. That was the "scoreboard printed multiple times
when I speed up the sim" symptom. `Config.RealSeconds()`
(`GetSystemTimeSecondsOnlyForProfileUse`) decides when a repaint is due;
`ScoreboardPollSeconds` only sets how often the loop checks. The same applies to
the HUD gate, which waits for a real-world event (the UI appearing). That clock
differs per client, so like `GetFocusArmy()` it may drive UI output only.

Both displays sit flush against a screen edge, because a `PrintText` location is a
fixed anchor with no offset. `Config.HudLeftPad` (leading spaces) insets them and
`Config.ScoreboardTopSpacerLines` (blank lines printed above the board, one per
line of shift) pushes the board clear of the mass/energy bars.

### On-screen messages

Sim code runs identically on every client, so a bare `PrintText` puts the message
on *everyone's* screen — an AI's "not enough mass" would pop up in front of you.
`Config.PrintTextFor(armyName, …)` and `PrintTextForSide(side, …)` gate on
`GetFocusArmy()`, which is the local client's army and therefore differs per
client. That is safe for UI-only effects and **never** for anything touching sim
state; the engine uses the same trick in `SimSync.lua` (`CancelCountdown`).
Failed queues, no-build-zone refunds and midline warps are addressed to the one
player; lane reinforcement is addressed to that player's side; round timers,
lane losses and victory stay global.

### Lobby options

The `default` field of an option is a **1-based index into its `values` list**,
not a value key. Every option here lists its default first and uses
`default = 1`; the one exception is *SOS destroys*, which uses `default = 2`.

| Option | Key | Values (**default** in bold) |
| --- | --- | --- |
| Income model | `opt_lw_income_model` | **Spawner income**, Flat scaling |
| Round length | `opt_lw_round_time` | **60s**, 45s, 90s, 120s |
| Core toughness | `opt_lw_core_health` | **Normal**, x2, x4 |
| Allow air units from round | `opt_lw_air_from_round` | **3**, Immediate, 2, 4, 5, 10, Never |
| Map start delay | `opt_lw_start_delay` | **10s**, None, 5s, 15s, 30s, 60s, 120s |
| Income growth interval | `opt_lw_income_growth_rounds` | **Every 4 rounds**, Never, every 1/2/3/5/6/7/8/9/10 |
| Income growth step | `opt_lw_income_growth_pct` | **50%**, 25%, 75%, 100%, 150%, 200% |
| Capture point income | `opt_lw_capture_income` | **Average**, Very low, Low, High, Very high |
| SOS uses per player | `opt_lw_sos_charges` | **1**, None, 2, 3 |
| SOS destroys | `opt_lw_sos_targets` | Enemy units only, **Every unit in the lane** |

Air gating (`lib/AirGate.lua`) locks the air factory and air units behind an
`AddRestriction`/`RemoveRestriction` on the build menu (the King of the Hill
tech-phase pattern), lifted when the round counter reaches the chosen round.
`Never` = 9999 sentinel (`Config.AirNeverRound`). The start delay replaces the
old fixed `InitialGraceSeconds`.

The two **income growth** options are a pair and only make sense read together —
interval says *how often*, step says *how much*, both as a share of base income
and additive rather than compounding (`Config.IncomeGrowthMultiplier`). `Never` =
the same 9999 sentinel, here `Config.IncomeGrowthNever`. "Every X rounds" means a
step on each multiple of X — rounds 4, 8, 12 at the default. One corner falls out
of that: at "every 1 round" round 1 is already one step above base.

Read via accessors in `Config.lua` that supply defaults, because
`ScenarioInfo.Options` may be missing keys on offline/sandbox starts. **Keep each
accessor's fallback equal to the lobby default**, or a sandbox run behaves
differently from a real game for no visible reason.

## Balance reference

**[UNITS.md](UNITS.md)** lists every buildable factory and unit with the mass and
energy a player is actually charged, plus health and speed, sorted by cost for
relative pricing. It is generated — after changing which units exist
(`lib/UnitTypes.lua`) or what they cost (`units/LineWars_units.bp`), run:

```
python3 tools/gen-units-md.py
```

The two levers are those files and nothing else for the wave-unit economy:
factories never build, so mass and energy alone gate army size. The five
ACU-built defense structures (see "Defense-structure carve-out" above) are the
one exception — they use real ACU construction, so `BuildTime` also matters
there.

### Open balance questions

- **Experimental affordability, and the Colossus's 99999 HP.** At a quarter of
  stock mass a Fatboy is 7000 mass; against `BaseMassIncome` 2/s plus capture
  points that is many rounds of *total* income during which the ACU builds
  nothing else, so the first in-game question is simply whether anyone ever
  finishes one. Mass is the lever (energy at a fifth of stock is comparatively
  the cheaper half). Separately: FAF's Galactic Colossus really does ship with
  **99999 health** against the Fatboy's 12500 and the Monkeylord's 45000, so the
  four are nowhere near a matched set at equal price. A `Defense.MaxHealth`
  nested merge in `units/LineWars_units.bp` would bring it into line the same way
  the `Enhancements` merge reprices the ACU upgrade.
- **Core energy vs. the 1:5 unit prices.** Every energy override in
  `units/LineWars_units.bp` was pitched against "100 e/s", but the Core has been
  quietly paying 2500 e/s on top all along, so energy has never actually been the
  constraint those comments assume. `CoreEnergyBase` 500 makes it one for the
  first time — a fifth of what it was. If early rounds feel energy-starved, raise
  `CoreEnergyBase` before touching any unit price; it is one number in
  `lib/Config.lua`. Note energy now also grows with the income-growth options,
  which the old flat 2500 masked entirely.

- **Bomber energy.** Stock is 90 mass / **2050 energy** against a 3900 energy cap,
  which made a second bomber unqueueable for most of a round. Overridden to 450,
  keeping the ~1:5 mass:energy ratio the T1 land units use. Whether air is now
  *too* cheap is the open question.
- **First-factory tempo.** Round 1 storage is 216 and the land factory is
  overridden to 100 mass, so the opening is factory → ~116 mass of units. Air is
  150, i.e. an opening air factory costs most of a round.
- **Interceptor energy.** Stock is 50 mass / **2250 energy**, the same energy
  trap the bomber had. Overridden to 250 to hold the ~1:5 mass:energy ratio, so
  an interceptor (50m/250e) sits just under a bomber (90m/450e) and stays a
  reactive counter to an air push. Whether air as a whole is too cheap is the
  same open question as the bomber.
- **T2 energy.** Stock T2 air is priced 1:20 mass:energy (a Vulthoo is
  500m/**10000e**), which against the flat 3900 energy cap is not expensive but
  unbuildable. Every T2 air unit and the T2 air factory are overridden to the
  same ~1:5 ratio the rest of the map uses, mass left at stock so the factions
  keep their relative pricing. The T2 land units needed almost none of this —
  heavy tanks and flak are already 1:5 at stock; only the mobile missile
  launcher (1:7.5) was pulled into line. Open question: whether 1:5 is right at
  the top of the range, where a single Vulthoo at 2500e is two thirds of the
  entire energy pool.
- **The mass cap, not income, gates the top of T2.** Storage is 216 on round 1
  and +100 a round, so a single unit costing more than the current cap simply
  cannot be bought however long you save: a Corsair or Notha (420) is a round-4
  purchase and a Vulthoo (500) round-5, well after the T2 upgrade itself is
  affordable. Either the storage step needs to be larger, or the heavy end of T2
  needs a mass override the way the factories got one.
- **~~Energy storage never grows~~ — RESOLVED 2026-07-26, now needs tuning.**
  This was the stated blocker for T3 and it came true: at 1:5 pricing a flat
  3900e cap means no unit over 780 mass can ever be queued. `CoreStorage` now
  grants an energy-storage building per round alongside the mass one, so the cap
  is 3900 + 500/round. 500 is a first guess pitched so the dearest T3 purchase
  (a 1750-mass Sinntha at 8750e) becomes queueable at roughly the round its mass
  cost does. Open: whether 500 is the right step, and whether energy growing at
  all makes energy stop being a meaningful second constraint.
- **T3 pricing, entirely untested.** Every T3 unit's energy is overridden to the
  same ~1:5 ratio, mass left at stock — but stock T3 air is priced as badly as
  1:114 (a 450-mass air-superiority fighter costs 51200e), so these are the
  largest overrides in the file by far. The mass cap then gates the top of T3
  much harder than it gates T2: the faction signature units at 1280–1750 mass
  are rounds 12–16 purchases. Open: whether that reads as "a late-game
  statement" or just "never happens in a real game".
- **Mobile AA** is 55 mass and only useful against a bomber opponent; now that
  the air factory also builds an interceptor, ground AA overlaps the air-to-air
  role. If air stays rare, AA is a dead purchase and wants either a price cut or
  a ground role.
- **Defense-structure cost, unverified in-game.** No `.bp` override is applied
  to any of them except the T3 Point Defense (the Ravager, cut from 2000m to
  1080m so it sits at 2x the T2 one rather than 3.7x)
  — see UNITS.md's "ACU-built defense structures" section. Stock costs are
  assumed to already deliver a real economy/time decision: T1 Point Defense's
  250 mass alone exceeds the round-1 storage cap of 216; T2 Shield's up to 700
  mass takes several rounds of storage growth to afford; and real `BuildTime`
  under gradual construction ties up the ACU the way queued units tie up mass.
  This relies on gradual ACU-construction economy (drains over `BuildTime`,
  stalls rather than blocks) behaving differently from `FactoryQueue`'s atomic
  per-unit charge — unconfirmed whether it reads as "a real strategic
  decision" in play, rather than unreachable-early or trivially cheap-late.

Also worth noting: starting mass (150) buys two Assault Bot Spawners and
nothing else — a Tank or Artillery Spawner is unaffordable on round 1.

## Engine findings

FAF-specific behaviour that cost real debugging time. Worth reading before
changing anything structural.

> The project-agnostic version of this — everything below plus the desync rule,
> the Lua 5.0 dialect, map/mod anatomy and a symptom→cause table, written for
> *any* FAF map or mod rather than for Line Wars — lives in
> [`FAF-SCRIPTING-GUIDE.md`](FAF-SCRIPTING-GUIDE.md).

- **Blueprint-id categories are lowercase.** `categories.ueb1101` exists;
  `categories.UEB1101` does not. `EntityCategory + nil` throws *"get as UserData
  expected but got nil"*, which surfaces as the whole `OnStart` silently
  failing. Confirmed by grepping `gamedata/lua.nx2` — there are zero uppercase
  uses. `AllowedCategories()` nil-guards and WARNs for this reason.
- **`AddRestriction` destroys script-spawned units too.** The Core never
  appeared because the map's own `AddRestriction(ALLUNITS - allowed)` killed it
  on completion (*"Unit.OnStopBeingBuilt() cannot create restricted unit"*).
  The fix is to include `Config.CoreBlueprint` in the allowed set; players still
  cannot build it, since it is T3 and all engineers are restricted.
- **A map can override blueprints without shipping a mod.** `LoadBlueprints()`
  in `lua/system/Blueprints.lua` runs `DiskFindFiles(preGameData.CurrentMapDir,
  '*.bp')` after the game files and before mods, on **both** the sim and UI
  side. `CurrentMapDir` is written into `Game.prefs` by `ui/lobby/lobby.lua`.
  `StoreBlueprint` honours `Merge = true`, which merges fields into the stock
  blueprint rather than replacing it — so we only state what differs. Merges can
  add and change fields but **cannot delete** them.
  - Useful targets: `Description` (this is the *entire* build-button hover
    tooltip — `construction.lua` sets `tooltipID = LOC(bp.Description)` and
    builds a title-only tooltip), `General.UnitName` (the unit-info panel name),
    `StrategicIconName`, and `Economy.*`.
  - A `.bp` may call `UnitBlueprint{}` any number of times and may use
    `doscript(path, env)`, so `LineWars_spawners_unit.bp` generates all 12
    merges from `SpawnerTypes.lua` instead of duplicating them. The build-menu
    text therefore cannot drift from the balance table.
  - It runs inside the loader's `safecall`, so a failure degrades to stock
    descriptions rather than crashing. Grep the game log for
    `Blueprints Loading: Blueprints from current map`.
- **The 48x48 build-menu art is *not* changeable from a map.** It is looked up
  as `<skin textures>/icons/units/<id>_icon.dds` and only mods and skins mount
  at the VFS root; map folders mount at `/maps/<name>/`. The workaround is
  `StrategicIconName`, a blueprint field that the build button draws as an
  overlay — set to the icon of the unit *produced* rather than of the proxy
  structure, so the button reads at a glance. Full custom art would need a
  companion mod players must enable, which is explicitly not wanted.
- **Chat is readable from the sim without any UI code.** For every chat message
  it receives, the stock UI fires a SimCallback whose only job is to record the
  message into the replay (`ui/game/chat.lua:810` →
  `SimUtils.GiveResourcesToPlayer`, whose first act is `SendChatToReplay(data)`
  before it returns early because `From == To`). `data.Sender` is the nickname
  and `data.Msg.text` is what was typed. `SendChatToReplay` is called
  *unqualified* from inside that function, so it resolves through SimUtils'
  module environment at call time, and replacing
  `import('/lua/simutils.lua').SendChatToReplay` intercepts every message —
  which is how `/sos` works. A leading `/` survives into `msg.text`:
  `chat.lua:719` strips it only when building `args` for `RunChatCommand`, and
  the only registered client-side commands are the four notify toggles.
  Handlers are dispatched with `ForkThread` so a throw cannot take replay chat
  logging down with it. **The sim sees more than one copy of a single message**
  (confirmed: one typed `/sos` logged two dispatches in a 4-player game), since
  `ReceiveChat` runs on every client that received it and each issues its own
  callback — hence the dedupe in `ChatCommands`. Hooking the callback table
  itself is not possible:
  `Callbacks` in `SimCallbacks.lua` is a file-local that captured its function
  reference at load. **Unconfirmed:** `ReceiveChat` runs on every client that
  received the message, so the sim may see one copy per receiving client;
  `ChatCommands` dedupes on sender + text + game time and logs every
  invocation so the first game log settles it.
- **The first `PrintText` of the game can kill `PrintText` for the whole
  session.** `textdisplay.lua:17` captures its parent as a module upvalue at
  load time — `local worldView = borders.GetMapGroup()` — and `GetMapGroup()`
  returns `false` until `gamemain.CreateUI` builds the border controls. The sim
  starts before that, so a message sent from `OnStart` loads `textdisplay` with
  a dead parent and every later `PrintText` throws *"maui/text.lua(19): Expected
  a game object"*. Unrecoverable: the module is cached and sim code cannot reach
  UI code to repair it. Observed in `game_27479823.log` — 138 errors, no
  on-screen text at all for the whole match. **Every message in this map
  therefore goes through `Config.Announce`**, which queues anything printed in
  the first `Config.HudStartDelaySeconds` (8) and flushes it when the gate
  opens; `Config.WaitForHud()` is for anything that repaints on a cycle, since a
  queued batch flushing late would collide with the next cycle. If on-screen
  text goes missing again and that error is in the log, raise
  `HudStartDelaySeconds`.
- **The objectives panel does not exist in skirmish.** `gamemain.lua:305` only
  calls `objectives2.CreateUI` when `campaignMode` is set, so `SimObjectives` /
  `Sync.ObjectivesTable` are a dead end for a skirmish map's HUD. `PrintText` is
  the only display channel, and its control pool has the refresh rule described
  under *Scoreboard* above.
- **`BuffBlueprint` is a sim global usable from map code**, so ACU buffs need no
  mod either. `Buff.ApplyBuff(acu, 'LineWarsAcu')` is keyed by unit object in
  `AcuRules`, so a rebuilt ACU gets re-buffed.
- **`MarkerToPosition` errors on a missing marker**, which makes probing for
  optional markers impossible. `Config.GetMarker()` reads
  `Scenario.MasterChain._MASTERCHAIN_.Markers[name]` directly and returns nil
  instead.
- **The gamedata `.nx2` archives are plain zips.** `unzip ~/.faforever/gamedata/
  lua.nx2` (engine + UI lua), `units.nx2` (blueprints), `textures.nx2` (icons)
  is the fastest way to answer "what does the engine actually do here".

## Development workflow

The repo copy and the deployed copy are **separate directories**; FAF loads only
the deployed one. `deployed-map` is a symlink to it. Do **not** blanket-copy
`*.lua`: three files (`_save.lua`, `_scenario.lua`, `.scmap`) are authored in
FAFMapEditor against the deployed copy and flow deployed→repo — the opposite
direction — so a naive `cp` clobbers unsynced map work. Sync code with the guard
below, which copies code only and, for each editor-authored file, **skips it and
warns on stderr when the deployed copy differs** from the repo so you can decide
(merge / copy back / clobber) before anything is overwritten:

```sh
src=LineWars-2p.v0001; dst=deployed-map

# Code flows repo→deployed — copy unconditionally.
cp -r "$src/lib" "$src/units" \
      "$src/LineWars-2p_script.lua" "$src/LineWars-2p_options.lua" "$dst/"

# Editor-authored files flow deployed→repo — never pushed. Warn on divergence.
for f in LineWars-2p_save.lua LineWars-2p_scenario.lua LineWars-2p.scmap; do
    cmp -s "$src/$f" "$dst/$f" || \
        echo "WARN: $f differs deployed↔repo — NOT copied; reconcile first (merge / copy back / clobber)" >&2
done

diff -r "$src" "$dst"   # after a clean sync, only the guarded files above may remain
```

To go the other way after a map edit, copy the diverged editor-authored file(s)
`deployed-map/ → repo` by hand once you've confirmed the change is wanted.

Launch with `~/Games/faf-linux/run-offline`. Game logs land in
`~/.faforever/logs/game_*.log` and are the only real debugging channel —
`Config.Log()` (gated on `Config.DebugMode`) prefixes everything with
`LineWars:`, so `grep -E 'LineWars|WARN|error' ~/.faforever/logs/game_*.log` is
the usual first move after a run.

A stale empty `line_wars.v0001` directory in the FAF maps folder produces a
harmless *"no scenario file"* line in the log — not a symptom of anything.

See `lua-examples/` for reference implementations lifted from published maps
(Wave of Death, The Great Pass, King of the Hill).
