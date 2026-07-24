# Line Wars — buildable units

**Generated file — do not edit.** Run `python3 tools/gen-units-md.py`
after changing `LineWars-2p.v0001/lib/UnitTypes.lua` (which units exist)
or `LineWars-2p.v0001/units/LineWars_units.bp` (what they cost).

Costs are what a player is actually charged when queuing. A `*` marks a
value Line Wars overrides; everything else is stock FAF. Build time is
deliberately absent: factories are pinned to build rate 0, so mass and
energy are the only levers that gate army size.

Caveat: the overrides live in a map `.bp`, which loses to any unit mod
that touches the same unit — with BlackOps/Total Mayhem loaded, `*`
values silently revert to the mod's. Play without unit-overhaul mods.

## Factories

Built by the ACU. Each one is an independent queue bound to the lane it
stands in, so a factory sited in a teammate's lane reinforces that lane.

| Factory | Faction | Blueprint | Mass | Energy | Health |
| --- | --- | --- | ---: | ---: | ---: |
| Land Factory | UEF | `ueb0101` | 100* | 500* | 4000 |
| Land Factory | Aeon | `uab0101` | 100* | 500* | 3200 |
| Land Factory | Cybran | `urb0101` | 100* | 500* | 2750 |
| Land Factory | Seraphim | `xsb0101` | 100* | 500* | 3500 |
| Air Factory | UEF | `ueb0102` | 150* | 800* | 4000 |
| Air Factory | Aeon | `uab0102` | 150* | 800* | 3200 |
| Air Factory | Cybran | `urb0102` | 150* | 800* | 2750 |
| Air Factory | Seraphim | `xsb0102` | 150* | 800* | 3500 |

## Land Factory units

| Role | Faction | Blueprint | Name | Mass | Energy | Health | Speed |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| Light Assault Bot | UEF | `uel0106` | Mech Marine | 30 | 120 | 60 | 4.2 |
| Light Assault Bot | Aeon | `ual0106` | Flare | 42 | 165 | 115 | 3.8 |
| Light Assault Bot | Cybran | `url0106` | Hunter | 35 | 140 | 90 | 4 |
| Light Assault Bot | Seraphim | `xsl0101` | Selen | 20 | 80 | 35 | 3.8 |
| Tank | UEF | `uel0201` | MA12 Striker | 56 | 266 | 300 | 3.4 |
| Tank | Aeon | `ual0201` | Aurora | 54 | 270 | 155 | 3 |
| Tank | Cybran | `url0107` | Mantis | 56 | 273 | 270 | 3.7 |
| Tank | Seraphim | `xsl0201` | Thaam | 54 | 270 | 280 | 3.5 |
| Mobile Artillery | UEF | `uel0103` | Lobo | 36 | 180 | 205 | 2.8 |
| Mobile Artillery | Aeon | `ual0103` | Fervor | 36 | 180 | 150 | 2.7 |
| Mobile Artillery | Cybran | `url0103` | Medusa | 36 | 180 | 140 | 2.9 |
| Mobile Artillery | Seraphim | `xsl0103` | Zthuee | 54 | 180 | 170 | 2.7 |
| Mobile AA | UEF | `uel0104` | Archer | 55 | 275 | 310 | 3.3 |
| Mobile AA | Aeon | `ual0104` | Thistle | 55 | 275 | 265 | 2.8 |
| Mobile AA | Cybran | `url0104` | Sky Slammer | 55 | 275 | 260 | 2.9 |
| Mobile AA | Seraphim | `xsl0104` | Ia-istle | 55 | 275 | 310 | 3.4 |

## Air Factory units

| Role | Faction | Blueprint | Name | Mass | Energy | Health | Speed |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| Attack Bomber | UEF | `uea0103` | Scorcher | 90 | 450* | 215 | 10 |
| Attack Bomber | Aeon | `uaa0103` | Shimmer | 90 | 450* | 205 | 10 |
| Attack Bomber | Cybran | `ura0103` | Zeus | 90 | 450* | 200 | 10 |
| Attack Bomber | Seraphim | `xsa0103` | Sinnve | 90 | 450* | 210 | 10 |

## Every unit by mass cost

The relative-pricing view: cheapest first, all factions and both
factories together.

| Mass | Energy | Unit | Faction | Role | Factory | Health |
| ---: | ---: | --- | --- | --- | --- | ---: |
| 20 | 80 | Selen (`xsl0101`) | Seraphim | Light Assault Bot | Land Factory | 35 |
| 30 | 120 | Mech Marine (`uel0106`) | UEF | Light Assault Bot | Land Factory | 60 |
| 35 | 140 | Hunter (`url0106`) | Cybran | Light Assault Bot | Land Factory | 90 |
| 36 | 180 | Fervor (`ual0103`) | Aeon | Mobile Artillery | Land Factory | 150 |
| 36 | 180 | Lobo (`uel0103`) | UEF | Mobile Artillery | Land Factory | 205 |
| 36 | 180 | Medusa (`url0103`) | Cybran | Mobile Artillery | Land Factory | 140 |
| 42 | 165 | Flare (`ual0106`) | Aeon | Light Assault Bot | Land Factory | 115 |
| 54 | 270 | Aurora (`ual0201`) | Aeon | Tank | Land Factory | 155 |
| 54 | 180 | Zthuee (`xsl0103`) | Seraphim | Mobile Artillery | Land Factory | 170 |
| 54 | 270 | Thaam (`xsl0201`) | Seraphim | Tank | Land Factory | 280 |
| 55 | 275 | Thistle (`ual0104`) | Aeon | Mobile AA | Land Factory | 265 |
| 55 | 275 | Archer (`uel0104`) | UEF | Mobile AA | Land Factory | 310 |
| 55 | 275 | Sky Slammer (`url0104`) | Cybran | Mobile AA | Land Factory | 260 |
| 55 | 275 | Ia-istle (`xsl0104`) | Seraphim | Mobile AA | Land Factory | 310 |
| 56 | 266 | MA12 Striker (`uel0201`) | UEF | Tank | Land Factory | 300 |
| 56 | 273 | Mantis (`url0107`) | Cybran | Tank | Land Factory | 270 |
| 90 | 450* | Shimmer (`uaa0103`) | Aeon | Attack Bomber | Air Factory | 205 |
| 90 | 450* | Scorcher (`uea0103`) | UEF | Attack Bomber | Air Factory | 215 |
| 90 | 450* | Zeus (`ura0103`) | Cybran | Attack Bomber | Air Factory | 200 |
| 90 | 450* | Sinnve (`xsa0103`) | Seraphim | Attack Bomber | Air Factory | 210 |
