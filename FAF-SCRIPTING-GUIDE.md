# Writing Lua for Supreme Commander: FAF — map scripts and mods

A working guide for anyone (especially an LLM) generating or modifying Lua for
Supreme Commander: Forged Alliance Forever. It is engine-facing, not
project-facing: every rule here is stated as a property of the engine, with a
citation, and a worked example only afterwards. Nothing in it requires knowing
what the example project does.

Written for FAF (the Forged Alliance Forever patched client), not retail FA.
Most of it applies to both; where it does not, that is called out.

---

## 0. How to use this guide

### Confidence markers

Every non-obvious claim below carries one of these. **Respect them.** The single
worst failure mode for a document like this is presenting a hypothesis as a
fact, because the reader has no way to tell them apart and will build on it.

| Marker | Meaning |
|---|---|
| **[GAME]** | Observed working (or failing) in an actual running game. |
| **[SRC]** | Read directly out of engine/UI Lua source, with a path. Correct about what the Lua does; may still be wrong about what the C engine underneath does. |
| **[BP]** | Read directly out of a shipped blueprint in `units.nx2`. |
| **[ASSUMED]** | Inference that has not been tested. Treat as a question, not an answer. |

Line numbers drift between patches. Cited paths are stable; re-grep for the
symbol rather than trusting the number.

### The three rules that matter most

1. **You cannot test this locally.** There is no test harness, no headless sim,
   no unit-test framework. `luac5.1 -p <file>` syntax-checks and that is all.
   Syntax-clean is not "works" and must never be reported as such. The only real
   evidence channel is the game log after a human runs the map.
2. **Settle engine questions by reading the engine, not by guessing.** The
   gamedata archives are plain zips (§10). Extracting and grepping them takes
   ten seconds and is the difference between a citation and a hallucination.
   Unit ids, method names and blueprint fields are the most commonly
   hallucinated things in this domain — verify every one.
3. **Sim code runs on every client simultaneously and must produce identical
   results.** This is the constraint that makes SupCom scripting different from
   ordinary Lua, and violating it produces a desync, which is the hardest class
   of bug here to diagnose. §4 is the whole story.

---

## 1. The dialect

FA's Lua is a modified **Lua 5.0**. Code written in idiomatic 5.1+ style will
often parse and then behave wrongly. These are the highest-frequency errors.

### Iteration: no `pairs`, no `ipairs`

```lua
for i, v in someTable do      -- correct
for i, v in ipairs(t) do      -- WRONG for this dialect
```

The table itself is the iterator expression. Both key and value are bound, in
that order, for arrays and hashes alike. Match the surrounding code — a codebase
that uses `pairs` somewhere is telling you it has a compatibility shim, not that
5.1 style is fine.

### Length: `table.getn`, not `#`

```lua
local n = table.getn(list)     -- correct
local n = #list                -- WRONG
```

`table.insert`, `table.remove`, `table.sort` all exist and behave normally.

### Blueprint ids and categories are lowercase — always

**[GAME]** `categories.ueb1101` exists. `categories.UEB1101` does not; it is
`nil`. Feeding nil into a category expression throws *"get as UserData expected
but got nil"*, and because that usually happens inside `OnStart`, the symptom is
that **the entire script silently does nothing** — no error banner, just a dead
map. Confirmed by grepping `lua.nx2`: there are zero uppercase uses anywhere in
the shipped code.

```lua
-- Correct: index, don't uppercase, and guard.
local cat = categories[bp]
if not cat then
    WARN('unknown blueprint id: ' .. tostring(bp))
else
    allowed = allowed + cat
end
```

Never write `categories[string.upper(bp)]`. This is a trap specifically for
models trained on other engines where ids are conventionally uppercase.

### Prefer cached unit fields over moho getters

**[SRC]** `Unit:OnPreCreate` (`lua/sim/Unit.lua`, ~line 277) caches `.EntityId`,
`.Blueprint`, `.UnitId` and `.Army` on the unit table. Prefer those over
`GetEntityId()`, `GetBlueprint()`, `GetUnitId()`, `GetArmy()`.

Two reasons, and the first is a real bug source: **a moho call on a destroyed
entity throws, and an uncaught error inside a forked thread kills that thread
silently** — your loop simply stops running with no obvious log line. The cached
field survives destruction. It also costs no engine call, which matters in a
per-tick loop.

```lua
table.sort(list, function(a, b) return a.EntityId < b.EntityId end)   -- good
table.sort(list, function(a, b) return a:GetEntityId() < b:GetEntityId() end)
                                                      -- throws if one just died
```

Always check `unit.Dead` before touching a unit you are holding a reference to.

### Module scope: bare `function` becomes a module member

`import()` evaluates a file in its own environment table and returns it. A
top-level `function Foo()` in `lib/Config.lua` is reached by the importer as
`Config.Foo`, with no `M.` prefix or `return` statement anywhere in the file.

```lua
-- lib/Config.lua
function GetMarker(name) ... end          -- no 'local', no export table

-- caller
local Config = import('/maps/MyMap.v0001/lib/Config.lua')
Config.GetMarker('MY_Spawn_A')
```

`local function` is genuinely private to the module. This is why FA modules look
like they are polluting globals when they are not.

### Threading

`ForkThread(fn, ...)` starts a coroutine; `WaitSeconds(n)` and `WaitTicks(n)`
yield inside it. **[SRC]** The sim runs at **10 ticks per second** — engine code
converts ticks to seconds by multiplying by 0.1 (`lua/sim/Recall.lua`, ~422:
`VoteTime * 0.1, -- convert ticks to seconds`). So 0.1s is one tick and is the
practical floor for a poll loop.

**[SRC]** Debug draw calls (`DrawLine`, `DrawCircle`) persist for a single tick,
so anything drawn must be redrawn every tick from a loop. The engine's own marker
debug overlay is exactly this shape — a `ForkThread` running `while true do` and
re-issuing every `DrawCircle`/`DrawLine` each pass (`lua/sim/MarkerUtilities.lua`,
~385–412). That file is also a good dialect specimen: note it iterates
`for k, marker in markers do`, confirming §1's form in engine source.

---

## 2. Anatomy of a map

A map is a directory under `maps/`, named `<MapName>.v<NNNN>`, holding:

| File | Authored by | Purpose |
|---|---|---|
| `<Map>.scmap` | Map editor | Binary terrain/heightmap/textures. |
| `<Map>_scenario.lua` | Editor (regenerated on save) | Metadata: name, description, size, army/team configuration, paths to the other files. |
| `<Map>_save.lua` | Editor (regenerated on save) | Markers, areas, per-army unit groups, props. |
| `<Map>_options.lua` | Hand-written | Lobby options. |
| `<Map>_script.lua` | Hand-written | The game-mode logic entry point. |
| `lib/*.lua` | Hand-written | Anything you factor out. |
| `units/*.bp` | Hand-written | Blueprint merges (§7). |

**The split matters operationally.** `_scenario.lua`, `_save.lua` and `.scmap`
are *editor outputs* — if a human is editing the map in FAFMapEditor, those files
flow editor→repo and a naive `cp *.lua` in the other direction destroys their
work. Keep code files and editor files on separate sync paths, and diff before
overwriting. **[GAME]** The editor also rewrites things you hand-edited in
`_scenario.lua` on every save (it recomputes `reclaim` from map props and strips
comments), so `_scenario.lua` is a poor place to keep hand-authored intent.

### `_scenario.lua`

```lua
version = 3
ScenarioInfo = {
    name = "My Mode",
    description = "<LOC MyMode_Description>...",
    type = 'skirmish',
    starts = true,
    size = {512, 512},
    map    = '/maps/MyMap.v0001/MyMap.scmap',
    save   = '/maps/MyMap.v0001/MyMap_save.lua',
    script = '/maps/MyMap.v0001/MyMap_script.lua',
    Configurations = {
        ['standard'] = {
            teams = { { name = 'FFA', armies = {'ARMY_1', 'ARMY_2'} } },
            customprops = {
                -- Armies that exist in the sim but take no lobby slot: script-
                -- owned unit pools, neutral/hostile forces, etc.
                ['ExtraArmies'] = STRING('ARMY_NEUTRAL ARMY_ATTACKER'),
            },
        },
    },
}
```

**[GAME]** `size` is **cosmetic metadata only** — it labels the lobby preview and
does not resize terrain. If it disagrees with the `.scmap` heightmap, the real
heightmap wins and players can move and build in the parts you thought you had
cut off. To actually confine play, see `SetPlayableArea` in §6.

### `_options.lua`

```lua
options = {
    {
        default = 60,
        label = "Round length",
        help  = "Length of the build phase",
        key = 'opt_mymode_round_time', pref = 'opt_mymode_round_time',
        values = {
            { text = "60 seconds (default)", help = "Standard", key = 60 },
            { text = "90 seconds",           help = "Relaxed",  key = 90 },
        },
    },
}
```

The selected `key` lands in `ScenarioInfo.Options['opt_mymode_round_time']`.

Two conventions worth keeping:

- **List the intended default first in `values` *and* set it as `default`.**
  Different lobby paths treat `default` as a value key or as an index; doing both
  makes the right thing happen either way.
- **Read every option through an accessor with a fallback.** `ScenarioInfo.Options`
  can be missing keys entirely on offline/sandbox starts, and a nil option that
  propagates into arithmetic fails far from its cause.

```lua
function GetRoundSeconds()
    return (ScenarioInfo.Options or {}).opt_mymode_round_time or 60
end
```

### `_script.lua`

Two entry points, called by the engine in this order:

```lua
local ScenarioUtils     = import('/lua/sim/ScenarioUtilities.lua')
local ScenarioFramework = import('/lua/ScenarioFramework.lua')
-- ScenarioInfo.directory is set by the loader; prefer it over a hardcoded path.
local DIR = ScenarioInfo.directory or '/maps/MyMap.v0001/'
local Config = import(DIR .. 'lib/Config.lua')

function OnPopulate()
    ScenarioUtils.InitializeArmies()    -- creates armies + spawns INITIAL groups
end

function OnStart(self)
    ScenarioInfo.Options.Victory = 'sandbox'   -- if the script owns win/loss
    -- ... alliances, restrictions, state setup, start your loops
end
```

Put shared mutable state in one table hung off `ScenarioInfo` (e.g.
`ScenarioInfo.MyMode = { Round = 1, ... }`) so every module reaches it without a
circular import.

**`ListArmies()` returns only armies that actually exist** — empty lobby slots
are absent. Intersect it with your own list of expected player armies to get
"who is really playing":

```lua
for i, armyName in ListArmies() do
    if Config.PlayerArmies[armyName] then table.insert(active, armyName) end
end
```

---

## 3. Anatomy of a mod

A mod is a directory under `mods/` with a `mod_info.lua`:

```lua
name = "King of the Hill"
uid = "jip-koth-23"          -- must be globally unique; never reuse another's
version = 23
description = "..."
author = "..."
icon = "/mods/King of the Hill/icon.png"
selectable = true            -- appears in the lobby mod list
enabled = true
exclusive = false            -- true = cannot be combined with other mods
ui_only = false              -- true = no sim code; no desync risk, no sim access
requires = {} requiresNames = {} conflicts = {} before = {} after = {}
```

Layout convention (from the King of the Hill mod, a good reference
implementation):

| Path | Loaded as |
|---|---|
| `hook/lua/<path>.lua` | **Hook** — merged over the engine file of the same path. Runs after it; you capture and wrap the original. |
| `modules/*.lua` | Plain modules you `import()` yourself. |
| `mod_options.lua` | Lobby options, as a global named `options` — same schema as a map's `_options.lua` (§2). |
| `lua/AI/LobbyOptions/lobbyoptions.lua` | Lobby options again, as a global named `AIOpts`. |

**[ASSUMED]** The relationship between those last two is not settled here. In the
King of the Hill mod they are 241-line near-duplicates differing only by the
global name and — revealingly — **one key whose capitalisation has already
drifted** between the copies (`kingOfTheHillTechCurve` vs
`KingOfTheHillTechCurve`). Which one the lobby actually reads was not verified.
If you need both, generate one from the other rather than maintaining two copies;
KotH demonstrates precisely how that goes wrong.

The hook idiom — keep the original, do not replace it:

```lua
-- hook/lua/simInit.lua
local oldBeginSession = BeginSession
function BeginSession()
    oldBeginSession()
    import('/mods/My Mod/modules/sim-start.lua').Start()
end
```

**[ASSUMED]** Hooks are believed additive across mods, so several mods can hook
the same file — this follows from the capture-and-wrap shape but was not verified
against the loader here. Either way, replacing
rather than wrapping is the usual cause of "works alone, breaks with other mods".

### Map or mod?

| Want | Choose |
|---|---|
| A game mode tied to specific terrain/markers | **Map.** No install step for players. |
| A game mode for arbitrary maps | **Mod.** |
| Custom 48x48 build-menu icon art | **Mod** — impossible from a map (§7). |
| Blueprint edits guaranteed to stick | **Mod** — a map's merges lose to mods (§7). |
| Custom UI panels | **Mod** (`ui_only = true` if there is no sim component). |

---

## 4. Determinism — the desync rule

**This is the most important section.**

SupCom is a **lockstep** simulation. Every client runs the identical sim code
over the identical inputs and must arrive at bit-identical state. Nothing is
replicated: if two clients ever diverge, they stay diverged, and the game reports
a desync some unpredictable time later.

So the rule is:

> **No value that can differ between clients may ever influence sim state.**

Three quite different-looking bugs are all this same rule. Learn the rule, not
the three cases, because there are others.

### 4a. Iteration order over a table keyed by a unit

**[GAME]** This is a real desync that shipped and had to be fixed.

Lua hashes a userdata key by its **pointer**. Engine handles live at different
addresses in different processes, so a table keyed by unit objects iterates in a
**different order on every client**.

```lua
local records = {}          -- records[factoryUnit] = { ... }
for f, rec in records do    -- order differs per client!
```

Harmless on its own. It becomes a desync the moment that order reaches sim state.
In the observed case it reached it twice over:

- The order built each wave's spawn list, and each unit was then placed with a
  `Random()` positional offset — so the same wave landed at different positions,
  and got different entity ids, on each client.
- The order decided which factories were charged first when the economy was
  tight — so *which* purchases were accepted and which rejected differed per
  client.

The symptom was a desync appearing reliably a few minutes in, once players had
two or more of the keyed objects. **With one key there is only one order**, which
is exactly why this class of bug hides during early testing and surfaces later.

**Fix: sort by a synced id before iterating.**

```lua
-- Iteration order over a table keyed by unit userdata follows the hash of the
-- engine handle, which differs per client. EntityId is synced (identical on
-- every client), so sorting on it gives every client the same order.
local function SortedKeys(records)
    local list = {}
    for k, rec in records do table.insert(list, k) end
    table.sort(list, function(a, b) return a.EntityId < b.EntityId end)
    return list
end
```

Use the cached `.EntityId` field, not `GetEntityId()` — see §1; a dead unit still
in the table would otherwise throw inside the comparator and kill the thread.
(The original fix used the getter and had to be hardened afterwards. When you
copy a fix out of a repo's history, check whether a later commit revised it.)

**Status, stated precisely, because this is the doc's flagship example:** the
desync itself is **[GAME]** — it was observed repeatedly in real multiplayer logs
with a consistent round-2/3 onset. The *diagnosis* above, and the sort as its
remedy, are **[ASSUMED]**: strongly supported by the mechanism and by the onset
matching the ≥2-entries threshold, but the fix was shipped `luac -p` clean and
**not yet confirmed in-game**. The underlying engine facts — that Lua hashes
userdata by pointer, and that `EntityId` is synced — are what carry the
reasoning; treat the specific repair as a well-motivated hypothesis rather than a
closed case.

**What is safe, and why it matters:**

- **String- and integer-keyed tables are deterministic.** Lua content-hashes
  those, and there is no per-process seed randomisation. You do not need to sort
  `committed[blueprintId] = count`.
- **Membership tests are safe.** `if buffed[unit] then` never exposes order. A
  unit-keyed table used purely as a set needs no fix.
- Only *ordered traversal that feeds sim state* is the problem.

### 4b. `Random()` call order is load-bearing

The sim's RNG is seeded identically on every client, so it returns the same
sequence — but only if every client makes the **same calls in the same order**.
Any nondeterministic ordering upstream of a `Random()` call (4a being the classic
source) silently permutes the draws.

Corollary: a `Random()` call inside a per-client conditional is always a desync.

### 4c. `GetFocusArmy()` and per-client UI

**[SRC]** `GetFocusArmy()` is callable from sim code and returns **the local
client's army index** (-1 for observers). Its value differs per client by design.

That makes it perfect for one job and catastrophic for every other:

```lua
-- SAFE — UI-only, touches no sim state.
local function IsFocus(armyName)
    if not GetFocusArmy then return true end   -- sandbox/headless: no focus concept
    return GetFocusArmy() == GetArmyBrain(armyName):GetArmyIndex()
end

function PrintTextFor(armyName, text, size, color, duration, location)
    if IsFocus(armyName) then PrintText(text, size, color, duration, location) end
end

-- DESYNC — a branch on a per-client value that changes the sim.
if GetFocusArmy() == myIndex then brain:TakeResource('MASS', 100) end
```

The engine itself uses the safe pattern (`lua/SimSync.lua`, `CancelCountdown`),
which is the precedent for it being legitimate.

The reason you need it at all: **[SRC]** a bare `PrintText` from sim code appends
to `Sync.PrintText` (`lua/SimSync.lua`, ~line 216) with no per-player filter, so
it shows on **every** client. **[GAME]** Without the gate, one player's "not
enough mass" pops up on everybody's screen. Scope player-specific feedback with
the gate; leave genuinely global announcements ungated.

### 4d. Checklist before you write sim code

- Am I iterating a table keyed by a unit/object? → sort by `.EntityId`.
- Does the result of that iteration change unit positions, resources, spawn
  order, or `Random()` draw order? → it must be sorted.
- Am I branching on anything per-client (`GetFocusArmy`, UI state, local prefs)?
  → the branch may only produce UI effects.
- Am I reading wall-clock time, or anything outside the sim? → don't.

### 4e. Debugging a suspected desync

Desyncs report late and vaguely, so work backwards from onset:

1. **When did it start?** "Round 2–3, every game" points at a state that only
   exists once some collection has ≥2 entries — a strong tell for 4a.
2. **Grep your own sim code for object-keyed iteration.** `for %w+, %w+ in`
   over anything you know is keyed by a unit.
3. **Look for `Random()` downstream of an unsorted traversal.**
4. Note that a desync is not always a crash log — compare game logs from two
   clients if you can get both.

---

## 5. Armies, alliances and spawning units

### Extra armies

Armies declared in `ExtraArmies` (§2) exist in the sim but occupy no lobby slot —
the standard way to own script-controlled units without giving a player control
of them. They need alliances set explicitly in `OnStart`:

```lua
SetAlliance(armyName, waveArmy, 'Ally')     -- 'Ally' | 'Enemy' | 'Neutral'
SetAlliedVictory(armyName, true)
brain:SetResourceSharing(false)
```

**[SRC]** `SetArmyColor(army, r, g, b)` with 0–255 components is a real sim
global (`lua/ScenarioFramework.lua`, ~line 1323). Useful for making
script-controlled armies read as one faction in the tactical view. Recolouring
*player* armies is usually unwelcome — teammates stop being distinguishable.

### `AddRestriction` destroys script-spawned units too

**[GAME]** This one costs everybody a debugging session. The build-restriction
system is not a UI filter — it is enforced at unit completion, and it fires for
units your own script created:

```lua
ScenarioFramework.AddRestriction(armyName, categories.ALLUNITS - allowed)
```

…will destroy anything you `CreateUnitHPR` for that army whose blueprint is not
in `allowed`, logging *"Unit.OnStopBeingBuilt() cannot create restricted unit"*.
The unit appears for an instant and vanishes.

**Rule: every blueprint your script spawns must be in the allowed set**, even one
the player could never reach anyway. Restrict the player through other means
(tech level, restricted engineers) if you need the unit to be script-only.

`ScenarioFramework.RemoveRestriction` lifts one later — this is the non-mod way to
implement tech phases or time-gated unlocks. Restrictions stack: adding a second
narrower restriction on top of a broad one works fine, and removing it returns to
the broad one.

### `INITIAL` is a reserved group name — and it auto-spawns

**[SRC]** `InitializeArmies()` → `CreateInitialArmyGroup` → `CreateArmyGroup(army,
'INITIAL')` (`lua/sim/ScenarioUtilities.lua`, ~391 and ~679) recursively spawns
**everything** under an army's `INITIAL` group in `_save.lua`, for **every** army,
at `OnPopulate` — regardless of whether that army corresponds to a filled lobby
slot.

**[GAME]** So pre-placed units under `INITIAL` appear even in unused slots. The
clean fix is prevent-spawn rather than destroy-after: rename the group in
`_save.lua` to something non-reserved, then spawn it yourself once you know who
is actually playing.

```lua
if ScenarioUtils.FindUnitGroup(army, 'MY_TOWERS') then
    ScenarioUtils.CreateArmyGroup(army, 'MY_TOWERS')
end
```

Guard with `FindUnitGroup` — `CreateArmyGroup` on a missing group errors.

**[SRC]** Related trap: `CreateInitialArmyGroup` spawns a **commander** for any
non-civilian army whose `INITIAL` group is nil or empty. If you rename away from
`INITIAL`, check whether you have just triggered stray ACUs. (Observed not to
fire for armies that already had `Units = {}`, but verify for your case.)

### Creating units from script

```lua
local u = CreateUnitHPR(blueprintId, armyName, x, y, z, pitch, yaw, roll)
```

**[SRC]** To make a spawned unit effectively invisible and inert while it still
exists (all confirmed methods): `HideBone(0, true)`, `SetUnSelectable(true)`,
`SetDoNotTarget(true)`, `SetCanTakeDamage(false)`. Note `Kill()` still removes it
— it bypasses the damage flag — so invulnerability can never block a cleanup path
or a win condition.

**[SRC]** `ChangeUnitArmy` / `TransferUnitsOwnership` exist (`lua/sim/SimUtils.lua`,
~246 / ~386) but **recreate** the unit rather than retagging it. There is no
per-unit colour override in FA; colour is per-army, so "change this unit's colour"
means "move it to another army", with all the entity-id churn that implies.

---

## 6. Markers, areas and the playable rectangle

Markers are placed in the editor and stored in `_save.lua` under
`Scenario.MasterChain._MASTERCHAIN_.Markers`.

**[GAME]** `ScenarioUtils.MarkerToPosition(name)` **errors on a missing marker**,
which makes probing for optional markers impossible. Read the table directly:

```lua
function GetMarker(name)
    return Scenario.MasterChain._MASTERCHAIN_.Markers[name]   -- nil if absent
end
```

This enables the "scan until first gap" pattern for a variable number of markers
(`MY_Cap1`, `MY_Cap2`, … stop at the first nil), which is how you let a map author
add content without touching code.

**Design the marker names as a contract** and document it in the repo: the human
placing markers in the editor and the code reading them are separated by hours.
A structured name (`<PREFIX>_L<lane>_<role><n>`) lets one query answer "which
lane does this belong to", which a flat name cannot.

### Playable area

**[SRC]** `ScenarioFramework.SetPlayableArea(rect, voFlag)`
(`lua/ScenarioFramework.lua`, ~line 1245) accepts either a rectangle or an
**area name string** from `_save.lua` (resolved via `ScenarioUtils.AreaToRect`),
and rounds coordinates to multiples of 4. It calls the engine's `SetPlayableRect`,
which genuinely confines movement and building and blacks out the border.

```lua
ScenarioFramework.SetPlayableArea('AREA_1', false)   -- false: skip camera pan + VO
```

**[GAME]** Call it from `OnStart`. Editing `Map → Area` in FAFMapEditor only moves
the rectangle in the save file; **nothing applies it at runtime unless the script
does**. A heightmap larger than the playable area is normal and renders as a black
border.

---

## 7. Blueprints from a map (no mod required)

**[SRC]** `LoadBlueprints()` (`lua/system/Blueprints.lua`, ~1220) runs
`DiskFindFiles(preGameData.CurrentMapDir, '*.bp')` **after** the game files and
**before** mods, on both the sim and UI blueprint passes. `CurrentMapDir` is
written into `Game.prefs` by `lua/ui/lobby/lobby.lua`. So a map can ship blueprint
changes with no mod and no install step for players.

```lua
-- units/MyMap_units.bp
UnitBlueprint {
    BlueprintId = 'uel0201',
    Merge = true,                       -- merge into stock, don't replace
    Economy = { BuildCostMass = 250, BuildCostEnergy = 1200, StorageMass = 0 },
}
```

**[SRC]** `StoreBlueprint` honours `Merge = true`, merging your fields into the
stock blueprint. Merges can **add and change** fields but **cannot delete** them —
the `nilValue` sentinel is not passed at that call site.

**[SRC] Merging into a LIST overwrites by index — it does not append.**
`BlueprintMerged` (`lua/system/Blueprints.lua:91`) recurses key by key, and an
array is just a table keyed 1..n. So a merge of
`Categories = { 'CYBRAN', 'SERAPHIM' }` replaces the stock entries **1 and 2**,
which on a real unit means silently destroying two of its categories. To append,
write explicit indices past the end of the stock list:

```lua
UnitBlueprint {
    BlueprintId = 'xeb2306',
    Merge = true,
    Categories = { [18] = 'AEON', [19] = 'CYBRAN', [20] = 'SERAPHIM' },
}
```

Count the stock entries first (extract `units.nx2` and read them), and re-check
after a FAF patch: if the list ever gets longer or shorter, that merge starts
overwriting entries or leaving a hole in the array.

A `.bp` may call `UnitBlueprint{}` any number of times and may `doscript(path, env)`,
so generate merges from a shared Lua data table rather than duplicating them. It
runs inside the loader's `safecall`, so a failure degrades to stock values instead
of crashing — grep the log for `Blueprints Loading: Blueprints from current map`
to confirm yours ran at all.

### Four hard limits

1. **[GAME] A map `.bp` merge loses to any mod that touches the same unit.**
   Load order is game files → map `.bp` → mods, so a unit-overhaul mod
   re-merging a unit overwrites your value. Verified in-game: an ACU
   `Economy.StorageMass` merge applied cleanly with no mods and reverted to the
   mod's value with them loaded. Untouched units keep the map's merge. **If your
   balance depends on a merge, either ship a mod or tell players to play without
   unit-overhaul mods.**

2. **[GAME] Runtime `__blueprints` edits do not reach the engine.** The C engine
   finalises each unit's economy from the blueprint at **load** time. Editing the
   Lua `__blueprints` table from a sim script afterwards changes only what *Lua*
   subsequently reads — not what a spawned unit actually gets. Proven: a script
   set `__blueprints[id].Economy.StorageMass = 100` before creating the unit; the
   Lua-side log printed 100 while the unit still contributed the stock 500.
   **All engine-affecting blueprint changes must be load-time.**

3. **[SRC] The 48x48 build-menu icon is not changeable from a map.**
   `lua/ui/game/construction.lua` (~766) hardcodes
   `UIUtil.UIFile('/icons/units/' .. id .. '_icon.dds')`, resolved against the
   skin texture root, which only checks `__active_mods` locations. Map folders
   mount at `/maps/<name>/`, never the VFS root. **[GAME]** Custom blueprint ids
   therefore always fall back to `default_icon.dds`, an image reading
   *"Place Holder"*. Workaround: override `StrategicIconName`, which the build
   button draws as an overlay (`construction.lua` ~770). Real art needs a mod.

4. **[SRC] Storage capacity has no setter and no buff.** Army max storage is the
   sum of owned units' `Economy.StorageMass`, committed by the engine as each
   unit completes. There is no `SetMaxStorage`/`SetStorage` on the brain and
   `lua/sim/Buff.lua` has no storage affect. To *grow* a live army's cap you must
   spawn a storage-bearing unit; to *lower* the base you must change a blueprint
   at load time (subject to limit 1).

### Defining new blueprints, and cloning traps

**[GAME]** A map can define brand-new blueprints, not only merge: `StoreBlueprint`
merges only when the id already exists *and* `Merge` is set; an unseen id is
stored outright, and the engine synthesises `categories.<newid>` so restrictions
work. But limit 3 means new ids always look broken in the build menu — which is
usually decisive against them. **Prefer building your mode out of stock units
with real art** over custom blueprints; it also sidesteps the whole icon problem.

If you do clone a stock blueprint:

- **[SRC] `bp.Source` is load-bearing.** `ExtractMeshBlueprint`
  (`Blueprints.lua`, ~507) derives the mesh id as
  `gsub(bp.Source, "_[a-z]+%.bp$", "_mesh")` and resolves the `.scm` LODs relative
  to it; the unit script is `<source dir>/<id>_script.lua`. Keep the stock
  `Source` or the clone renders as placeholder geometry.
- **[SRC] `Unit:DoDeathWeapon()` iterates `bp.Weapon` unguarded.** To strip
  weapons set `Weapon = {}`, never `nil`, or every death throws.

**[GAME] Path gotcha in map `.bp` files:** `debug.getinfo` returns a *backslash OS
path* under Wine (`z:\home\...`), but `doscript` resolves through the VFS
(`/maps/<name>/`). Deriving a map dir by string-stripping the OS path fails
silently inside the loader's `safecall`. Take the folder name and rebuild
`/maps/<name>/` explicitly.

---

## 8. Economy, buffs and unit control

### Resources

```lua
local brain = GetArmyBrain(armyName)
brain:GetEconomyStored('MASS')          -- also 'ENERGY'
brain:TakeResource('MASS', 100)
brain:GiveResource('MASS', 100)
```

**[GAME] `TakeResource` silently floors stored at 0.** Charging an unaffordable
amount does not fail — it just takes whatever is there. Any "pay for it" logic
must therefore check affordability *first*:

```lua
if brain:GetEconomyStored('MASS') >= cost then
    brain:TakeResource('MASS', cost)
else
    -- reject; do NOT charge partially
end
```

### Buffs

**[SRC]** `BuffBlueprint{...}` is a sim global usable from **map** code — no mod
needed — and `Buff.ApplyBuff(unit, 'MyBuffName')` applies it. Affects cover
Health, Regen, BuildRate, MoveMult, Mass/Energy production and similar;
notably **not** storage (§7 limit 4).

Track applied buffs in a unit-keyed table used as a **set** (membership only —
safe per §4a) so a rebuilt unit can be re-buffed idempotently.

**[SRC]** `SetProductionPerSecondMass(0)` re-applied per tick is the robust way to
neutralise native production — it survives unit upgrades and mod-added economy
enhancements, which a one-shot at start does not.

### Build orders and command queues

**[SRC]** There is **no queue-add event**. `OnStartBuild` fires when construction
actually begins, not when an item is queued. To react to queueing you must poll
`unit:GetCommandQueue()` each tick and diff against your own snapshot.

**[SRC]** There is **no native affordability gate** — `construction.lua` (~1388)
issues build orders unconditionally, so a player can queue what they cannot pay
for. If you want a spend gate, you must implement it.

Sim-side command-queue orders carry `.commandType` (numeric) and `.blueprintId`.
**[SRC]** `lua/sim/commands/shared.lua` (~332): `7` = BuildFactory (a unit build),
`27` = Upgrade (a structure upgrade). **UI-side** code reads a `.type` *string*
instead — do not mix the two conventions up when copying from `copy-queue.lua` or
`distribute-queue.lua`.

**[GAME] `SetBlockCommandQueue(true)` also blocks your own script's orders.** It
does not filter by origin: `IssueBuildFactory` and `IssueClearCommands` issued by
your script vanish silently while it is set. Never use it as an affordability
gate — the observed failure was a charge/refund oscillation, because the script's
own rebuild disappeared and the next tick read the empty queue as a player
cancellation. **[SRC]** Worse, `FactoryUnit` drives this flag itself in its
IdleState / FinishBuildThread / RolloffBody paths (`lua/sim/FactoryUnit.lua`), so
a per-tick setter fights the engine's own state machine.

**[GAME] `SetBuildRate(0)` alone does not reliably stop a factory** under queue
churn — spam-clicking could still produce a real unit. Combine with
`SetPaused(true)` and re-apply both every tick (a player can un-pause).

**[SRC]** A single factory order cannot be surgically removed. The engine's own
pattern (`lua/sim/SimUtils.lua`, ~54) is clear-and-reissue:
`IssueClearCommands({factory})` then `IssueBuildFactory({factory}, bp, n)`.

### Tech tiers come free

**[BP]** A T1 factory's `BuildableCategory` asks for `BUILTBYTIER1FACTORY`, which
T2 units do not carry — so a T1 factory physically cannot offer T2 units
regardless of your per-army whitelist. "Must upgrade to build T2" is
engine-enforced; you do not need to implement it.

**[BP]** Likewise the upgrade button exists automatically because the higher-tier
building's blueprint has `General.UpgradesFrom`. **[SRC]** And the UI converts a
click on a unit whose `UpgradesFrom` matches the selected factory into an Upgrade
order, never a plain build (`construction.lua`, ~1413) — so a "build the T2
factory directly" bypass is not reachable through the UI.

**[BP]** Check `BuildableCategory` before assuming what can build what: the stock
ACU's includes `BUILTBYCOMMANDER`/`BUILTBYTIER2COMMANDER`/`BUILTBYTIER3COMMANDER`
with no enhancement prerequisite, so it natively builds T1, T2 **and** T3
structures. **[BP]** Note it is also **faction-scoped** — the entries are
`"BUILTBYTIER3COMMANDER UEF"`, an intersection — so a Cybran ACU cannot build a
UEF-only structure. If you want one faction's building available to everyone, the
merge to make is on the *building's* `Categories` (add the other faction names),
not on each ACU.

#### An upgrade's price is a differential, not the target's cost

**[SRC]** Every stock factory above tier 1 sets
`Economy.DifferentialUpgradeCostCalculation = true`, and
`Game.GetConstructEconomyModel` (`lua/game.lua:57`) then computes

```lua
mass   = math.max(targetData.BuildCostMass   - upgradeBaseData.BuildCostMass,   0)
energy = math.max(targetData.BuildCostEnergy - upgradeBaseData.BuildCostEnergy, 0)
```

where `upgradeBaseData` is the Economy of the building being upgraded. The UI
tooltip goes through this (`unitviewDetail.lua:856` passes the builder's own
Economy as the third argument), so **the number the player sees on the upgrade
button is target-minus-source**.

Any script that charges for an upgrade itself must apply the same subtraction, or
the button will advertise one price and your script will demand another. The
failure mode is silent and baffling: the player has more than the advertised cost,
clicks, and nothing happens. It also means a `.bp` merge that "sets the upgrade
cost" is really setting the top of a subtraction — write the tier costs so the
*difference* between consecutive tiers is what you intend to charge.

---

## 9. Sim ↔ UI boundary

| | Sim | UI |
|---|---|---|
| Runs | Once per client, must be identical | Per client, free to differ |
| Owns | Units, resources, damage, win/loss | Panels, sounds, camera, text |
| Reaches the other via | `Sync` table | `Sync` table, read in `UserSync` |
| Desync risk | **Yes** | No |

Sim → UI: sim writes a field into the `Sync` table; the UI reads it in a hooked
`UserSync.lua` `OnSync()`. The whole pattern, from King of the Hill:

```lua
-- sim side
Sync.SendPlayerPointData = points

-- hook/lua/UserSync.lua
local baseOnSync = OnSync
function OnSync()
    baseOnSync()                                   -- don't break anything
    if Sync.SendPlayerPointData then
        ForkThread(controllerUI.ProcessPlayerPointData, Sync.SendPlayerPointData)
    end
end
```

Each field is checked for presence because `OnSync` fires every tick and most
fields are absent most ticks.

- `PrintText` from sim is global to all clients (§4c). Gate with `GetFocusArmy()`
  for anything player-specific.
- **Never let UI state or a per-client value flow back into sim state.**
- A mod that only draws things should set `ui_only = true` — it then cannot
  desync at all, and players can enable it unilaterally.

### 9a. What a map has instead of a UI

A **map** cannot ship UI lua — only mods mount at the VFS root — so the `Sync` +
hooked `UserSync` pattern above is closed to it. Two consequences worth knowing
before designing any map HUD:

- **The objectives panel does not exist in a skirmish.** `gamemain.lua:305` only
  calls `objectives2.CreateUI` when `campaignMode` is set [SRC], so
  `SimObjectives` and `Sync.ObjectivesTable` are a dead end outside campaign —
  the sim writes, and nothing is listening.
- **The first `PrintText` of the game can kill `PrintText` for the whole
  session.** `textdisplay.lua` captures its parent control *once*, as a module
  upvalue at load time [SRC, `lua/ui/game/textdisplay.lua:17`]:

  ```lua
  local worldView = import("/lua/ui/game/borders.lua").GetMapGroup()
  ```

  and `GetMapGroup()` returns **`false`** until the UI has built its border
  controls — `gamemain.CreateUI` → `borders.SetupBorderControl` →
  `CreateControls`, which is driven by the engine's `CreateGameInterface`
  [SRC, `borders.lua:17,50,92`; `gamemain.lua:260,536-542`]. The sim can start
  before that. `Sync.PrintText` is drained by `UserSync.OnSync`, which is
  already running, so a message sent from `OnStart` at tick 0 loads
  `textdisplay` with a dead parent, and from then on **every** `PrintText`
  throws

  ```
  maui/text.lua(19): Expected a game object. (Did you call with '.' instead of ':'?)
  ```

  and nothing is ever drawn again. It is unrecoverable — the module is cached
  with its bad upvalue, `PrintToScreen` leaves no partial state to repair, and
  sim code cannot reach a UI module to fix it. [GAME — observed in a 4-player
  FAF game: 138 of these, first message at tick 0, no on-screen text for the
  entire match.]

  The only lever a map has is time. Route every message through one helper that
  holds anything printed in the first several seconds of game time and flushes
  it when the gate opens; sim time only advances once the session is genuinely
  running, so a handful of seconds is a strong bound. Anything that *repaints on
  a cycle* must wait for the gate rather than queue, or the flushed batch lands
  on top of the next cycle and breaks the pooling rule below.
- **`PrintText` is the whole toolbox**, and it has a pooling rule.
  `textdisplay.PrintToScreen` keeps a list of text controls **per screen
  location**, reuses the first one that has gone *inactive*, and appends a brand
  new control below when they are all still live [SRC,
  `lua/ui/game/textdisplay.lua`]. A control goes inactive `duration` seconds
  after printing plus about one more second of alpha fade. So a display that
  repaints itself must satisfy

  ```
  repaint period > duration + 1
  ```

  or it grows by a full set of lines every cycle, forever. The price of obeying
  it is one fade-out/fade-in per cycle. Give any repeating display a location no
  other code prints to, or interleaved prints scramble which line lands in which
  control. Valid locations are the nine in `textdisplay.lua`: `lefttop`,
  `leftcenter`, `leftbottom`, `centertop`, `center`, `centerbottom`, `righttop`,
  `rightcenter`, `rightbottom`.
- **That period must be real seconds, and `WaitSeconds` is not.** `WaitSeconds`
  counts **game** time, which players speed up and slow down with the `+`/`-`
  keys; the fade in `PrintToScreen`'s `OnFrame` accumulates **real** frame
  deltas. So a display paced with `WaitSeconds` violates the rule above as soon
  as the game is sped up — at 10x a 12-second period is 1.2 real seconds against
  an unchanged 10-second fade, and every cycle appends a fresh set of controls.
  [GAME — observed as a scoreboard that reprinted itself repeatedly, more copies
  the faster the sim ran.] `GetSystemTimeSecondsOnlyForProfileUse()` **is
  callable from the sim** [SRC — `SimCallbacks.lua:38`,
  `sim/ScenarioUtilities.lua:44`]; use it to decide when a repaint is due and let
  `WaitSeconds` set only how often you check. Its value differs per client, so
  like `GetFocusArmy()` it may drive UI output and never sim state. The same
  reasoning applies to any wait for a real-world event, such as the UI finishing
  its build above.
- **A location is a fixed anchor with no offset**, so text sits flush against the
  screen edge and can collide with the stock UI (the resource bars occupy the top
  left). The only levers are padding: leading spaces to inset horizontally, and
  blank spacer lines printed first to push content down one line at a time —
  which is what the `PrintText(" ", …)` "spacer" calls in published maps are for.
  A blank line must be `" "`, not `""`: an empty text control has no height for
  the next line to stack below.

### 9b. Reading chat from the sim (chat commands, no mod)

The stock UI forwards **every chat message into the sim** as a side effect of
recording chat into replays. `ReceiveChat` fires
[SRC, `lua/ui/game/chat.lua:810`]:

```lua
SimCallback({Func = "GiveResourcesToPlayer",
             Args = {From = GetFocusArmy(), To = GetFocusArmy(), Mass = 0,
                     Energy = 0, Sender = sender, Msg = msg}}, true)
```

Sim-side that reaches `SimUtils.GiveResourcesToPlayer`, which calls
`SendChatToReplay(data)` and then returns immediately because `From == To`
[SRC, `lua/SimUtils.lua:1463`]. So the transfer is always a no-op and the
payload carries `data.Sender` (nickname) and `data.Msg.text` (what was typed).

To intercept it, replace `SendChatToReplay` on the SimUtils module:

```lua
local SimUtils = import('/lua/simutils.lua')
local original = SimUtils.SendChatToReplay
SimUtils.SendChatToReplay = function(data)
    original(data)
    -- data.Sender, data.Msg.text
end
```

This works because `SendChatToReplay` is called *unqualified* from inside
`GiveResourcesToPlayer`, so it is resolved through SimUtils' module environment
at call time, and `import()` returns exactly that environment table (§1, module
scope). `import` lowercases the path before caching [SRC,
`lua/system/import.lua:106`], so casing cannot fork a second instance.

Hooking `SimCallbacks.Callbacks` instead does **not** work: that table is a
file-local, and it captured `SimUtils.GiveResourcesToPlayer` by value at load
time.

A leading `/` **does** reach `msg.text` intact. `OnEnterPressed`
[SRC, `chat.lua:719-732`] strips it only when building `args` for
`RunChatCommand`, and just four commands are registered
(`enablenotify`, `disablenotify`, `enablenotifyoverlay`,
`disablenotifyoverlay` — `AddChatCommand` in `lua/ui/notify/`); anything else
returns false and the message is sent verbatim. Re-check this if a future patch
adds client-side slash commands, because a name collision swallows the trigger
silently, with no error anywhere.

Three cautions:

- Dispatch handlers with `ForkThread`, not a direct call. A throw inside a
  handler propagates into `SendChatToReplay` → `GiveResourcesToPlayer` →
  `DoCallback` and can break replay chat logging for the rest of the game;
  forks are also scheduled in the deterministic order the callbacks arrive, so
  this costs nothing on the desync side.
- Resolve the sender by matching `data.Sender` against `GetArmyBrain(name).Nickname`.
  `GetCurrentCommandSourceArmy()` gives the client that *issued* that copy, which
  is not the same thing.
- `ReceiveChat` runs on every client that received the message, and each issues
  its own SimCallback, so the sim sees **more than one copy of a single message**
  [GAME — a 4-player game logged two dispatches for one typed command; whether
  the count is exactly one per receiving client is still unmeasured]. Dedupe on sender + text +
  `GetGameTimeSeconds()`, and make the visible effect fire only in the branch
  that actually changed state, so a duplicate cannot announce twice.

---

## 10. Verification and debugging

There is no test framework. This is the whole toolkit.

### Syntax check

```sh
luac5.1 -p path/to/file.lua      # also works on .bp files — they are Lua
```

Catches syntax errors only. It cannot catch a nil category, a wrong blueprint id,
a missing marker, or a desync. **Never report "syntax-clean" as "works."**

**And note the version mismatch, which is the trap for this guide's audience:
`luac5.1` is a Lua *5.1* parser checking *5.0*-dialect code.** `#t`, `ipairs(t)`
and `pairs(t)` all parse perfectly cleanly under it — so the single most frequent
class of LLM error in this domain (§1) is exactly the class your only local tool
cannot detect. `for i, v in someTable do` also parses, because a generic `for`
accepts any expression; it fails at *runtime*, in a game, on someone else's
machine. Dialect conformance has to be checked by reading, not by tooling.

### Game logs — the only real evidence channel

```sh
grep -E 'MYMODE|WARN|error' ~/.faforever/logs/game_*.log
```

Prefix every log line from your own code with a unique tag and route it through
one function gated on a debug flag:

```lua
function Log(msg)
    if DebugMode then LOG('MyMode: ' .. msg) end
end
```

`LOG` and `WARN` are sim globals. Log the values you are about to branch on, not
that you reached a line — "reached OnStart" tells you nothing that "active
players: 2, allowed categories: 14" does not.

### Read the engine instead of guessing

**[GAME]** The gamedata archives are **plain zip files**:

```sh
unzip -oq ~/.faforever/gamedata/lua.nx2 -d /tmp/fa && grep -rn 'SetPlayableArea' /tmp/fa
```

| Archive | Contents |
|---|---|
| `lua.nx2` | Engine + UI Lua (`lua/sim/`, `lua/ui/`) — behaviour questions |
| `units.nx2` | Blueprints — verify ids, costs, categories |
| `textures.nx2` | Icons — check whether art for a unit actually ships |

**Note for FAF specifically:** `units.nx2` carries only files FAF has *patched*.
A unit missing from it is not evidence the unit does not exist — check the retail
`gamedata/units.scd` too. This has caused wrong "that unit doesn't exist"
conclusions. Corroborating evidence that a unit is live: an icon in
`textures.nx2`, a build hotkey in `lua/ui/game/buildmodedata.lua`, AI platoon
templates referencing it, or recent balance-changelog entries.

### Test without unit-overhaul mods

**[GAME]** BlackOps, Total Mayhem and similar re-merge stock blueprints and load
*after* your map (§7 limit 1). Any balance-sensitive testing must be done with
them off, or you are measuring their numbers, not yours.

---

## 11. Symptom → cause

| Symptom | Likely cause |
|---|---|
| Script appears not to run at all; no error banner | `OnStart` threw early. Classic: `categories[SOMETHING_UPPERCASE]` → nil → *"get as UserData expected but got nil"*. Check the log. (§1) |
| A unit the script spawns flashes and disappears | Your own `AddRestriction` destroyed it — *"cannot create restricted unit"*. Add its blueprint to the allowed set. (§5) |
| Desync starting round 2–3, reliably, never in round 1 | Iteration over an object-keyed table reaching sim state; only ≥2 entries expose it. (§4a) |
| A message meant for one player shows for everyone | Bare `PrintText` from sim. Gate on `GetFocusArmy()`. (§4c) |
| A per-tick loop stops running, silently | Uncaught error in a forked thread — often a moho getter on a destroyed unit. Use cached `.EntityId`/`.Blueprint`. (§1) |
| Blueprint change works alone, reverts with mods on | Mods load after the map's `.bp`. Ship a mod or drop the mods. (§7) |
| Blueprint change never takes effect at all | Runtime `__blueprints` edit. Must be load-time. (§7) |
| Build icon reads "Place Holder" | Custom blueprint id; map cannot supply icon art. Use `StrategicIconName` or a stock unit. (§7) |
| Pre-placed units appear for empty lobby slots | They are under the reserved `INITIAL` group, which auto-spawns for every army. (§5) |
| Players build/move outside the intended area | `SetPlayableArea` never called; the `size` field is cosmetic. (§6) |
| Script's own `IssueBuildFactory` silently does nothing | `SetBlockCommandQueue(true)` is set — it blocks the script too. (§8) |
| Charged for something unaffordable, got a partial take | `TakeResource` floors at 0; check affordability first. (§8) |
| Errors on a marker that may or may not exist | `MarkerToPosition` throws on missing. Read the Markers table directly. (§6) |
| No `PrintText` ever appears, and the log repeats *"maui/text.lua(19): Expected a game object"* | The map's first `PrintText` ran before the UI built its map group, so `textdisplay.lua` cached a dead parent. Permanent for the session — delay the first message. (§9a) |
| A repeating `PrintText` display grows extra lines every cycle | Repaint period is not longer than `duration` + ~1s of fade, so `PrintToScreen` appends new controls instead of reusing them. (§9a) |
| …and it gets worse the faster the sim speed | The period is paced with `WaitSeconds` (game time) while the fade is real time. Pace it against the wall clock. (§9a) |
| A map's objectives never appear on screen | The objectives panel is only created in campaign mode. (§9a) |
| Unexpected extra ACUs | An army's `INITIAL` group is nil/empty and `CreateInitialArmyGroup` spawned a commander. (§5) |
| The hover unit-info panel flashes and vanishes; it comes back only while the mouse keeps moving | A fast script loop is re-setting unit state (e.g. `SetPaused`/`SetBuildRate`) that has not changed. Every re-fire of `OnSelectionChanged` runs `construction.OnSelection`, which calls `UnitViewDetail.Hide()` and rebuilds the build-icon grid; only a fresh MouseEnter re-shows it. Check before you set. (§8) |
| A re-issued factory queue reads as scattered single icons | The engine merges only *consecutive* identical `BuildFactory` orders. Issue one `IssueBuildFactory(units, bp, n)` per blueprint. (§8) |

---

## 12. Working practices for LLM-generated FAF code

1. **Verify every blueprint id against `units.nx2` before using it.** Do not
   pattern-match from a naming convention. Real counterexample: T2 fighter/bombers
   use expansion-pack prefixes (`dea0202`, `xaa0202`, `dra0202`, `xsa0202`), not
   the `uea`/`uaa`/`ura`/`xsa` pattern their tier-1 siblings use — scanning only
   the regular prefixes produces a confident, wrong "that unit doesn't exist".
2. **Do not label units from memory.** Confirm tier and role from the blueprint's
   categories. A wrong label ("T2 flak" for what is actually T1 point defense)
   propagates into balance decisions and survives for weeks.
3. **Keep one balance table.** Unit rosters, costs and role assignments in one
   Lua table that both the code and any generated docs read, so they cannot
   drift. Generate the human-readable reference; do not hand-maintain it.
4. **Match the surrounding dialect exactly.** §1. A single `ipairs` is a runtime
   error in a file that will not be run until a human launches a game.
5. **State what you verified and what you assumed.** "luac-clean, untested
   in-game" is the honest status of nearly everything you write here. Say it.
6. **Write the *why* into the comment, not just the *what*.** The determinism
   fixes in particular look like pointless sorting to the next reader, who will
   remove them. The comment above `SortedKeys` in §4a is the model: say what
   breaks if it goes away.
7. **When a design has an untested engine assumption at its centre, name it as
   the first thing the human should check in-game.** One targeted question after
   a playtest is worth more than any amount of further reasoning.

---

## Sources

Everything above came from one of: reading engine/UI Lua extracted from
`lua.nx2`; reading blueprints from `units.nx2`; FAF game logs from real sessions;
or reference implementations by other authors — the **King of the Hill** mod
(Jip), **Wave of Death**, and **Survival: The Great Pass** are all worth reading
before inventing a pattern.

Engine paths cited, all under the extracted `lua.nx2`:

| Path | For |
|---|---|
| `lua/system/Blueprints.lua` | Blueprint load order, `Merge`, mesh derivation |
| `lua/sim/ScenarioUtilities.lua` | `InitializeArmies`, army groups, `AreaToRect` |
| `lua/ScenarioFramework.lua` | `SetPlayableArea`, `AddRestriction`, `SetArmyColor` |
| `lua/sim/Unit.lua` | `OnPreCreate` cached fields |
| `lua/sim/FactoryUnit.lua` | Factory state machine, command-queue blocking |
| `lua/sim/SimUtils.lua` | Clear-and-reissue pattern, ownership transfer |
| `lua/sim/units/ACUUnit.lua` | `GiveInitialResources` (ACU gifts its storage as start mass) |
| `lua/sim/Buff.lua` | Which affects exist |
| `lua/sim/commands/shared.lua` | Command type numbers |
| `lua/SimSync.lua` | Sim→UI sync, the `GetFocusArmy` precedent |
| `lua/ui/game/construction.lua` | Build menu: icons, tooltips, upgrade orders |
| `lua/ui/lobby/lobby.lua` | `CurrentMapDir` |
