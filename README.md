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
- [ ] In-game test of ally-lane reinforcement and the air factory
- [ ] Static economy: flat ACU income, kill bounties, lane capture points
- [ ] Lanes 2 and 3 markers (ally reinforcement is untestable until lane 2 exists)
- [ ] Balance pass using [UNITS.md](UNITS.md)
- [ ] More unit roles (shields, T2, experimental mass sink)

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
    UnitTypes.lua             factories and the units they build (the balance table)
    FactoryQueue.lua          per-factory queues: charge, refund, lane binding
    RoundManager.lua          round timer loop + announcements
    WaveSpawner.lua           wave spawning, platoon march orders, idle watchdog
    Economy.lua               income models (spawner income / flat scaling)
    CoreStorage.lua           per-round mass-storage growth on each Core
    WinCondition.lua          Cores, elimination, side victory
    AcuRules.lua              ACU buffs, no-build zones, midline rule
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

`<lane>` is 1..3, `<side>` is `A` or `B`. Waypoints are probed from `n = 1`
upward and stop at the first gap. No-build zones are probed from `i = 1`
likewise, so numbering must not skip.

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

The two levers are those files and nothing else. Build time is irrelevant:
factories never build, so mass and energy alone gate army size.

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
- **Mobile AA** is 55 mass and only useful against a bomber opponent; now that
  the air factory also builds an interceptor, ground AA overlaps the air-to-air
  role. If air stays rare, AA is a dead purchase and wants either a price cut or
  a ground role.

Also worth noting: starting mass (150) buys two Assault Bot Spawners and
nothing else — a Tank or Artillery Spawner is unaffordable on round 1.

## Engine findings

FAF-specific behaviour that cost real debugging time. Worth reading before
changing anything structural.

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
