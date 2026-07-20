# FAF Line Wars

A Line Wars game mode (WC3 / SC2 Nexus-Wars style) for Supreme Commander:
Forged Alliance Forever, implemented as a scripted skirmish map.

**The loop:** timed rounds. During each build phase you spend script-granted
mass on spawner structures. When the round ends, every spawner produces its
units, which march down your lane attack-moving everything they meet. Destroy
the enemy Core at the far end before your own falls. Up to three lanes, each a
mirrored 1v1 (lobby slots 1v2, 3v4, 5v6).

## Layout

```
LineWars-2p.v0001/            the map folder FAF loads 
  LineWars-2p_scenario.lua    armies, teams, ExtraArmies, file paths
  LineWars-2p_options.lua     lobby options: income model, round length, Core HP
  LineWars-2p_script.lua      entry point: OnPopulate/OnStart, alliances, wiring
  LineWars-2p.scmap           map file created by FAFMapEditor 512x256 (10x5)
  LineWars-2p_save.lua
  lib/Config.lua           all tuning + army/lane/marker contract
  lib/SpawnerTypes.lua     structure -> spawned-units data (the balance table)
  lib/RoundManager.lua     round timer loop + announcements
  lib/WaveSpawner.lua      wave spawning, platoon march orders, idle watchdog
  lib/Economy.lua          income models (spawner income / flat scaling)
  lib/WinCondition.lua     Cores, elimination, side victory
  MARKERS.md               contract for building the .scmap in FAFMapEditor
lua-examples/              reference maps/mods (Wave of Death, The Great Pass, KotH)
deployed-map		   symlink to real deployed copy of map.
```

## Status

- [x] Script framework scaffolded (untested — no map yet)
- [x] Build `LineWars.scmap` + `LineWars_save.lua` in FAFMapEditor per MARKERS.md
- [ ] First in-game smoke test (round loop, income, wave march, Core death)
- [ ] Balance pass on SpawnerTypes numbers
- [ ] More spawner types (AA, shields, T2/T3, experimental mass sink)
- [ ] Custom blueprints for spawners/Core instead of stock-structure proxies

## Design decisions so far

- One player per lane, 1v1 duels; sides/alliances fixed by start position.
- Wave units belong to per-player `ARMY_WAVE_n` extra armies so players cannot
  micro their waves.
- Economy is a lobby option: spawner-income (default, Nexus-Wars style) or
  flat per-round scaling. No mass extractors; all income is script-granted.
- ACU is the builder; its build menu is restricted to exactly the spawner set.
- Core is currently a UEF T3 pgen proxy with a health multiplier.
