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

Built by the ACU (Tech 1). Each one is an independent queue bound to the
lane it stands in, so a factory sited in a teammate's lane reinforces it.
Higher tiers are the native factory upgrade (its Mass/Energy is the upgrade
cost Line Wars charges); upgrading unlocks that tier's units.

| Factory | Tier | Faction | Blueprint | Mass | Energy | Health |
| --- | ---: | --- | --- | ---: | ---: | ---: |
| Land Factory | 1 | UEF | `ueb0101` | 100* | 500* | 4000 |
| Land Factory | 1 | Aeon | `uab0101` | 100* | 500* | 3200 |
| Land Factory | 1 | Cybran | `urb0101` | 100* | 500* | 2750 |
| Land Factory | 1 | Seraphim | `xsb0101` | 100* | 500* | 3500 |
| Land Factory | 2 | UEF | `ueb0201` | 250* | 1200* | 8000 |
| Land Factory | 2 | Aeon | `uab0201` | 250* | 1200* | 6600 |
| Land Factory | 2 | Cybran | `urb0201` | 250* | 1200* | 6100 |
| Land Factory | 2 | Seraphim | `xsb0201` | 250* | 1200* | 7200 |
| Air Factory | 1 | UEF | `ueb0102` | 150* | 800* | 4000 |
| Air Factory | 1 | Aeon | `uab0102` | 150* | 800* | 3200 |
| Air Factory | 1 | Cybran | `urb0102` | 150* | 800* | 2750 |
| Air Factory | 1 | Seraphim | `xsb0102` | 150* | 800* | 3500 |

## Land Factory units

| Role | Tier | Faction | Blueprint | Name | Mass | Energy | Health | Speed |
| --- | ---: | --- | --- | --- | ---: | ---: | ---: | ---: |
| Light Assault Bot | 1 | UEF | `uel0106` | Mech Marine | 30 | 120 | 60 | 4.2 |
| Light Assault Bot | 1 | Aeon | `ual0106` | Flare | 42 | 165 | 115 | 3.8 |
| Light Assault Bot | 1 | Cybran | `url0106` | Hunter | 35 | 140 | 90 | 4 |
| Light Assault Bot | 1 | Seraphim | `xsl0101` | Selen | 20 | 80 | 35 | 3.8 |
| Tank | 1 | UEF | `uel0201` | MA12 Striker | 56 | 266 | 300 | 3.4 |
| Tank | 1 | Aeon | `ual0201` | Aurora | 54 | 270 | 155 | 3 |
| Tank | 1 | Cybran | `url0107` | Mantis | 56 | 273 | 270 | 3.7 |
| Tank | 1 | Seraphim | `xsl0201` | Thaam | 54 | 270 | 280 | 3.5 |
| Mobile Artillery | 1 | UEF | `uel0103` | Lobo | 36 | 180 | 205 | 2.8 |
| Mobile Artillery | 1 | Aeon | `ual0103` | Fervor | 36 | 180 | 150 | 2.7 |
| Mobile Artillery | 1 | Cybran | `url0103` | Medusa | 36 | 180 | 140 | 2.9 |
| Mobile Artillery | 1 | Seraphim | `xsl0103` | Zthuee | 54 | 180 | 170 | 2.7 |
| Mobile AA | 1 | UEF | `uel0104` | Archer | 55 | 275 | 310 | 3.3 |
| Mobile AA | 1 | Aeon | `ual0104` | Thistle | 55 | 275 | 265 | 2.8 |
| Mobile AA | 1 | Cybran | `url0104` | Sky Slammer | 55 | 275 | 260 | 2.9 |
| Mobile AA | 1 | Seraphim | `xsl0104` | Ia-istle | 55 | 275 | 310 | 3.4 |
| Heavy Tank | 2 | UEF | `uel0202` | Pillar | 198 | 990 | 1500 | 3.1 |
| Heavy Tank | 2 | Aeon | `ual0202` | Obsidian | 360 | 1800 | 1250 | 2.7 |
| Heavy Tank | 2 | Cybran | `url0202` | Rhino | 290 | 1500 | 1900 | 2.9 |
| Heavy Tank | 2 | Seraphim | `xsl0202` | Ilshavoh | 360 | 1800 | 2500 | 2.6 |

## Air Factory units

| Role | Tier | Faction | Blueprint | Name | Mass | Energy | Health | Speed |
| --- | ---: | --- | --- | --- | ---: | ---: | ---: | ---: |
| Interceptor | 1 | UEF | `uea0102` | Cyclone | 50 | 250* | 295 | 15 |
| Interceptor | 1 | Aeon | `uaa0102` | Conservator | 50 | 250* | 285 | 15 |
| Interceptor | 1 | Cybran | `ura0102` | Prowler | 50 | 250* | 280 | 15 |
| Interceptor | 1 | Seraphim | `xsa0102` | Ia-atha | 50 | 250* | 290 | 15 |
| Attack Bomber | 1 | UEF | `uea0103` | Scorcher | 90 | 450* | 215 | 10 |
| Attack Bomber | 1 | Aeon | `uaa0103` | Shimmer | 90 | 450* | 205 | 10 |
| Attack Bomber | 1 | Cybran | `ura0103` | Zeus | 90 | 450* | 200 | 10 |
| Attack Bomber | 1 | Seraphim | `xsa0103` | Sinnve | 90 | 450* | 210 | 10 |

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
| 50 | 250* | Conservator (`uaa0102`) | Aeon | Interceptor | Air Factory | 285 |
| 50 | 250* | Cyclone (`uea0102`) | UEF | Interceptor | Air Factory | 295 |
| 50 | 250* | Prowler (`ura0102`) | Cybran | Interceptor | Air Factory | 280 |
| 50 | 250* | Ia-atha (`xsa0102`) | Seraphim | Interceptor | Air Factory | 290 |
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
| 198 | 990 | Pillar (`uel0202`) | UEF | Heavy Tank | Land Factory | 1500 |
| 290 | 1500 | Rhino (`url0202`) | Cybran | Heavy Tank | Land Factory | 1900 |
| 360 | 1800 | Obsidian (`ual0202`) | Aeon | Heavy Tank | Land Factory | 1250 |
| 360 | 1800 | Ilshavoh (`xsl0202`) | Seraphim | Heavy Tank | Land Factory | 2500 |
