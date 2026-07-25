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
- [x] Per-round storage growth (`lib/CoreStorage.lua`, 216 / 316 / 416 …)
- [x] Player-sited factories, one queue each, lane-bound by where they stand
- [x] Air factory + attack bombers + interceptors (air-to-air counter)
- [x] Lane capture points (`lib/CapturePoints.lua`) — land units capture, income to the side
- [ ] In-game test of ally-lane reinforcement and the air factory
- [ ] Static economy remainder: flat ACU income, kill bounties
- [ ] Lanes 2 and 3 markers (ally reinforcement is untestable until lane 2 exists)
- [x] Tech 2: land and air factory upgrades, with a unit set behind each
- [ ] Balance pass using [UNITS.md](UNITS.md)
- [x] Defense structures: T1/T2 Point Defense, T1/T2 AA, T2 Shield, built directly by the ACU on its own side of the lane
- [ ] More unit roles (T3, experimental mass sink)

## Layout

```
LineWars-2p.v0001/            the map folder FAF loads
  LineWars-2p_scenario.lua    armies, teams, ExtraArmies, file paths
  LineWars-2p_options.lua     lobby options: income model, round length, Core HP
  LineWars-2p_script.lua      entry point: OnPopulate/OnStart, alliances, wiring
  LineWars-2p.scmap           map file created by FAFMapEditor, 512x256 (10x5 km)
  LineWars-2p_save.lua        armies + markers, written by FAFMapEditor
  units/
    LineWars_units.bp         storage + factory-cost blueprint merges
  lib/
    Config.lua                all tuning + army/lane/marker contract
    UnitTypes.lua             factories/units + the ACU-built defense structures (the balance table)
    FactoryQueue.lua          per-factory queues: charge, refund, lane binding
    RoundManager.lua          round timer loop + announcements
    WaveSpawner.lua           wave spawning, platoon march orders, idle watchdog
    Economy.lua               income models (spawner income / flat scaling)
    CapturePoints.lua         LW_Cap zones: land units capture, side earns income
    CoreStorage.lua           per-round mass-storage growth on each Core
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

`<lane>` is 1..3, `<side>` is `A` or `B`. Waypoints and capture points are probed
per lane from `n = 1` upward and stop at the first gap; no-build zones from
`i = 1` likewise — so numbering must not skip. Capture markers are read only for
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

Both models grant a flat `BaseEnergyIncome` (100/s). Energy is deliberately not
meant to be a constraint in v1. Starting resources are 150 mass / 500 energy.

Two caveats now that spawner structures are gone: **model 1 is currently
identical to a flat `BaseMassIncome`** (there are no spawners left to add income),
and the ACU gifts its own `StorageMass` as mass at warp-in, so you actually start
with ~216 mass rather than 150. Replacing this whole section with the static
economy (flat ACU income, kill bounties, lane capture points) is the next design
task — see [FACTORY-QUEUE-DESIGN.md](FACTORY-QUEUE-DESIGN.md) open question 2.

**Storage is the real budget cap.** `lib/CoreStorage.lua` stacks a hidden,
invulnerable mass-storage building on each Core at the start of every round after
the first, so your mass ceiling is 216 / 316 / 416 … The amounts live in
`units/LineWars_units.bp`; note those merges lose to unit-overhaul mods, so play
Line Wars without BlackOps/Total Mayhem or the caps silently revert.

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
player *in that lane* earns `CapturePointMass` (2/s) and `CapturePointEnergy`
(25/s), not distant teammates. A point held by a reinforcing ally when the lane's
own player is dead pays nobody.

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
the target building's cost, then swaps the building in place, carrying the lane
binding and the paid wave across. It is instant, so there is no cancel window.
Tier gating of the *units* is then free: a T1 building's `BuildableCategory` is
`BUILTBYTIER1FACTORY`, which no T2 unit carries, so "upgrade before you can build
this" is enforced by the engine, not by script. Tier 2 currently offers:

| Factory | T2 upgrade | Unlocks |
| --- | --- | --- |
| Land | Land Factory HQ (250m/1200e) | Heavy Tank, Mobile Missile Launcher, Mobile Flak |
| Air | Air Factory HQ (350m/1750e) | Gunship, Fighter/Bomber |

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
- **Defense-structure carve-out** — the ACU may also build five faction-matched
  defense structures directly (T1/T2 Point Defense, T1/T2 AA, T2 Shield; see
  [UNITS.md](UNITS.md)). Unlike everything else, these ARE allowed inside a
  no-build zone — that's the point, it's how you hold a forward choke — but
  never past the midline of the lane they're actually sited in. Checked on the
  structure's own position (not the ACU's), using the same Core-distance test
  as the midline rule above, generalized to whichever lane the position is
  actually nearest (`FactoryQueue.LaneForPosition`, the same rule factories use
  for lane binding — so one built in a teammate's reinforced lane is judged by
  that lane's Cores). A structure that ends up past the midline is refunded
  pro-rata and destroyed, exactly like any other no-build-zone violation. No
  upgrade is needed for the T2 pair: the stock ACU's `BuildableCategory` already
  carries `BUILTBYTIER2COMMANDER` from the start. These use the engine's own
  construction economy (cost drains gradually over `BuildTime`, gated normally)
  rather than `FactoryQueue`'s charge/refund machinery, since the ACU builds
  them directly instead of queuing them.

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

| Option | Key | Values (default first) |
| --- | --- | --- |
| Income model | `opt_lw_income_model` | Spawner income, Flat scaling |
| Round length | `opt_lw_round_time` | 60s, 45s, 90s, 120s |
| Core toughness | `opt_lw_core_health` | Normal, x2, x4 |
| Allow air units from round | `opt_lw_air_from_round` | 3, Immediate, 1, 2, 4, 5, 10, Never |
| Map start delay | `opt_lw_start_delay` | 10s, None, 5s, 15s, 30s, 60s, 120s |

Air gating (`lib/AirGate.lua`) locks the air factory and air units behind an
`AddRestriction`/`RemoveRestriction` on the build menu (the King of the Hill
tech-phase pattern), lifted when the round counter reaches the chosen round.
`Never` = 9999 sentinel (`Config.AirNeverRound`). The start delay replaces the
old fixed `InitialGraceSeconds`.

Read via accessors in `Config.lua` that supply defaults, because
`ScenarioInfo.Options` may be missing keys on offline/sandbox starts.

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
- **Energy storage never grows.** Mass storage climbs +100/round via
  `CoreStorage`, but the 3900 energy cap is the ACU's alone and nothing adds to
  it, so energy is a flat ceiling on any single purchase for the whole game. If
  T3 units are added, either that ceiling has to rise or their energy has to keep
  shrinking relative to mass.
- **Mobile AA** is 55 mass and only useful against a bomber opponent; now that
  the air factory also builds an interceptor, ground AA overlaps the air-to-air
  role. If air stays rare, AA is a dead purchase and wants either a price cut or
  a ground role.
- **Defense-structure cost, unverified in-game.** No `.bp` override is applied
  (see UNITS.md's new "ACU-built defense structures" section) — stock costs are
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
