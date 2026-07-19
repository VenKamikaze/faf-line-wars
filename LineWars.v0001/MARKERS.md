# Line Wars — map contract for FAFMapEditor

The script is written against the names below. When building `LineWars.scmap`
in FAFMapEditor (`~/Games/faf-linux/FAFMapEditor1.0rc3`), everything here must
exist in the map for the script to work. Names are **case-sensitive**.

## Suggested layout

Three parallel lanes running the long axis of the map. Per lane, each side has
a build zone set back from the lane (out of point-defense range of it), a Core
behind the build zone, and a wave spawn point at the lane entrance:

```
Side A                 lane i                  Side B
[Core]--[build zone / ACU start]--[Spawn] ~~~~ [Spawn]--[build zone / ACU start]--[Core]
```

## Armies

Create these armies in the editor (they must all appear in `LineWars_save.lua`):

| Army | Purpose |
|---|---|
| `ARMY_1` … `ARMY_6` | Player slots, **with start positions**. Lane pairing is fixed by position: 1v2 = lane 1, 3v4 = lane 2, 5v6 = lane 3. Sides: odd = A, even = B. |
| `ARMY_WAVE_1` … `ARMY_WAVE_6` | Script-owned wave armies (no start position needed). Must also stay listed in `customprops.ExtraArmies` in `LineWars_scenario.lua`. |

Place each player's start position inside their build zone.

## Markers (type: Blank Marker)

Per lane `i` (1–3) and side `S` (`A`/`B`):

| Marker | Required | Meaning |
|---|---|---|
| `LW_Li_Spawn_S` | yes | Where side S's wave appears, at their end of the lane |
| `LW_Li_Core_S` | yes | Where side S's Core structure is spawned |
| `LW_Li_Wp1_S`, `LW_Li_Wp2_S`, … | no | Optional path waypoints for side S's waves, walked in numeric order (use for curved lanes). Omit entirely for straight lanes. |

Example full set for lane 1: `LW_L1_Spawn_A`, `LW_L1_Spawn_B`, `LW_L1_Core_A`,
`LW_L1_Core_B`.

A wave from side A walks: `LW_Li_Spawn_A` → `LW_Li_Wp*_A` (if any) → enemy
Core, attack-moving the whole way.

## Files the editor generates vs. files we own

- Editor generates: `LineWars.scmap`, `LineWars_save.lua`, preview images.
- We own: `LineWars_scenario.lua`, `LineWars_options.lua`,
  `LineWars_script.lua`, `lib/`. If the editor rewrites the scenario file,
  restore `customprops.ExtraArmies`, the `script`/`save`/`map` paths, and
  update `size` to the real map size.

## Terrain notes

- Keep lanes flat and wide enough for formations (~20+ units of walkable width).
- Impassable terrain/cliffs between lanes so waves can't cross over.
- No mass points or hydro spots anywhere — income is script-driven.
- Map size suggestion: 20x10 km (1024x512) or 10x5 km (512x256) for faster games.

## Testing

Symlink the map folder so FAF sees it:

```
ln -s ~/personal/git/faf-line-wars/LineWars.v0001 ~/Games/faf-linux/faf-maps-mods/maps/LineWars.v0001
```

Then host an offline skirmish on it (easiest: `run-offline`, put an AI in slot
2 so lane 1 is paired; the AI won't play sensibly but the round loop, waves,
income, and Cores can all be exercised solo). Watch `~/.faforever/logs/` for
`LineWars:` LOG lines and WARN messages about missing markers.
