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
Higher tiers are the native factory upgrade; upgrading unlocks that
tier's units.

**Mass/Energy is the blueprint value; Pay is what the upgrade actually
costs.** They differ above tier 1 because those buildings set
`DifferentialUpgradeCostCalculation`, so the engine — and the upgrade
button's own tooltip, and `FactoryQueue.UpgradeCost` — price the upgrade
as this tier minus the tier below.

| Factory | Tier | Faction | Blueprint | Mass | Energy | Pay (mass) | Pay (energy) | Health |
| --- | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |
| Land Factory | 1 | UEF | `ueb0101` | 100* | 500* | — | — | 4000 |
| Land Factory | 1 | Aeon | `uab0101` | 100* | 500* | — | — | 3200 |
| Land Factory | 1 | Cybran | `urb0101` | 100* | 500* | — | — | 2750 |
| Land Factory | 1 | Seraphim | `xsb0101` | 100* | 500* | — | — | 3500 |
| Land Factory | 2 | UEF | `ueb0201` | 350* | 1700* | 250 | 1200 | 8000 |
| Land Factory | 2 | Aeon | `uab0201` | 350* | 1700* | 250 | 1200 | 6600 |
| Land Factory | 2 | Cybran | `urb0201` | 350* | 1700* | 250 | 1200 | 6100 |
| Land Factory | 2 | Seraphim | `xsb0201` | 350* | 1700* | 250 | 1200 | 7200 |
| Land Factory | 3 | UEF | `ueb0301` | 850* | 4200* | 500 | 2500 | 16000 |
| Land Factory | 3 | Aeon | `uab0301` | 850* | 4200* | 500 | 2500 | 12800 |
| Land Factory | 3 | Cybran | `urb0301` | 850* | 4200* | 500 | 2500 | 11000 |
| Land Factory | 3 | Seraphim | `xsb0301` | 850* | 4200* | 500 | 2500 | 14000 |
| Air Factory | 1 | UEF | `ueb0102` | 150* | 800* | — | — | 4000 |
| Air Factory | 1 | Aeon | `uab0102` | 150* | 800* | — | — | 3200 |
| Air Factory | 1 | Cybran | `urb0102` | 150* | 800* | — | — | 2750 |
| Air Factory | 1 | Seraphim | `xsb0102` | 150* | 800* | — | — | 3500 |
| Air Factory | 2 | UEF | `ueb0202` | 500* | 2550* | 350 | 1750 | 8000 |
| Air Factory | 2 | Aeon | `uab0202` | 500* | 2550* | 350 | 1750 | 6600 |
| Air Factory | 2 | Cybran | `urb0202` | 500* | 2550* | 350 | 1750 | 6100 |
| Air Factory | 2 | Seraphim | `xsb0202` | 500* | 2550* | 350 | 1750 | 7200 |
| Air Factory | 3 | UEF | `ueb0302` | 1150* | 5800* | 650 | 3250 | 16000 |
| Air Factory | 3 | Aeon | `uab0302` | 1150* | 5800* | 650 | 3250 | 12800 |
| Air Factory | 3 | Cybran | `urb0302` | 1150* | 5800* | 650 | 3250 | 11000 |
| Air Factory | 3 | Seraphim | `xsb0302` | 1150* | 5800* | 650 | 3250 | 14000 |

## ACU-built defense structures

Built directly by the ACU on its own side of the lane midline — exempt from
the no-build zone (that is the point: it's how you hold a forward choke), but
never past the midline. The tier column is a real gate the engine applies: a
pre-upgrade ACU does not show T3 items in its build menu, even though the stock
BuildableCategory carries BUILTBYCOMMANDER, BUILTBYTIER2COMMANDER and
BUILTBYTIER3COMMANDER from the start. These use the engine's own
construction economy (cost drains gradually over BuildTime) rather than the
factory-queue charge/refund path, so a value here exceeding a storage cap is
a slow build, not a hard block.

The T3 Point Defense is one building, the UEF Ravager, for every faction:
stock FA has no other, so `units/LineWars_units.bp` appends the remaining
three faction categories to it and every ACU can build it. It keeps its UEF
model and name whoever builds it.

| Structure | Tier | Faction | Blueprint | Mass | Energy | Health |
| --- | ---: | --- | --- | ---: | ---: | ---: |
| T1 Point Defense | 1 | UEF | `ueb2101` | 250 | 2000 | 1300 |
| T1 Point Defense | 1 | Aeon | `uab2101` | 250 | 2000 | 1300 |
| T1 Point Defense | 1 | Cybran | `urb2101` | 250 | 2000 | 1300 |
| T1 Point Defense | 1 | Seraphim | `xsb2101` | 250 | 2000 | 1300 |
| T1 AA Defense | 1 | UEF | `ueb2104` | 150 | 1500 | 800 |
| T1 AA Defense | 1 | Aeon | `uab2104` | 150 | 1500 | 800 |
| T1 AA Defense | 1 | Cybran | `urb2104` | 150 | 1500 | 800 |
| T1 AA Defense | 1 | Seraphim | `xsb2104` | 150 | 1500 | 800 |
| T2 Point Defense | 2 | UEF | `ueb2301` | 540 | 3780 | 2250 |
| T2 Point Defense | 2 | Aeon | `uab2301` | 540 | 3780 | 2000 |
| T2 Point Defense | 2 | Cybran | `urb2301` | 480 | 3360 | 2000 |
| T2 Point Defense | 2 | Seraphim | `xsb2301` | 540 | 3780 | 2100 |
| T2 AA Defense | 2 | UEF | `ueb2204` | 400 | 4000 | 2590 |
| T2 AA Defense | 2 | Aeon | `uab2204` | 400 | 4000 | 2450 |
| T2 AA Defense | 2 | Cybran | `urb2204` | 400 | 4000 | 2380 |
| T2 AA Defense | 2 | Seraphim | `xsb2204` | 400 | 4000 | 2520 |
| T2 Shield | 2 | UEF | `ueb4202` | 600 | 6000 | 250 |
| T2 Shield | 2 | Aeon | `uab4202` | 480 | 5760 | 150 |
| T2 Shield | 2 | Cybran | `urb4202` | 160 | 2000 | 500 |
| T2 Shield | 2 | Seraphim | `xsb4202` | 700 | 7000 | 400 |
| T3 AA Defense | 3 | UEF | `ueb2304` | 800 | 8000 | 5000 |
| T3 AA Defense | 3 | Aeon | `uab2304` | 800 | 8000 | 5000 |
| T3 AA Defense | 3 | Cybran | `urb2304` | 800 | 8000 | 5000 |
| T3 AA Defense | 3 | Seraphim | `xsb2304` | 800 | 8000 | 5000 |
| T3 Point Defense | 3 | UEF | `xeb2306` | 1080* | 7560* | 6500 |
| T3 Point Defense | 3 | Aeon | `xeb2306` | 1080* | 7560* | 6500 |
| T3 Point Defense | 3 | Cybran | `xeb2306` | 1080* | 7560* | 6500 |
| T3 Point Defense | 3 | Seraphim | `xeb2306` | 1080* | 7560* | 6500 |

## ACU-built economy (lobby option)

Behind the **Allow T2 power generators** lobby option, which defaults to
Allow; set it to Disallow and these vanish from the ACU's build menu
entirely. The engine's own tier gate applies, so the ACU needs the Advanced
Engineering upgrade first.

Unlike the defense structures above these get NO no-build-zone carve-out —
one sited in the lane corridor is refunded pro-rata and destroyed, exactly
like a misplaced factory, because a building this size is precisely the wall
the no-build zone exists to prevent.

A T2 power generator pays 500 energy/s — the same as a Core — so it is the
one way to change your energy income by building something.

| Structure | Tier | Faction | Blueprint | Mass | Energy | Health |
| --- | ---: | --- | --- | ---: | ---: | ---: |
| T2 Power Generator | 2 | UEF | `ueb1201` | 1200 | 12000 | 2500 |
| T2 Power Generator | 2 | Aeon | `uab1201` | 1200 | 12000 | 2300 |
| T2 Power Generator | 2 | Cybran | `urb1201` | 1200 | 12000 | 2200 |
| T2 Power Generator | 2 | Seraphim | `xsb1201` | 1200 | 12000 | 2400 |

## Storage buildings

`lib/CoreStorage.lua` spawns one of each on every Core at the start of each
round, hidden and invulnerable — that is how the mass and energy caps grow.
**The ACU can also build them**, a side effect of the restriction exemption
those script spawns need, so the price below is a real decision: cap bought
ahead of the round schedule, against a design where storage and not income
gates tier 3. Both costs are doubled from stock for that reason; the
Capacity column is what one building adds.

| Building | Faction | Blueprint | Mass | Energy | Capacity |
| --- | --- | --- | ---: | ---: | ---: |
| Mass Storage | UEF | `ueb1106` | 400* | 3000* | 100* |
| Mass Storage | Aeon | `uab1106` | 400* | 3000* | 100* |
| Mass Storage | Cybran | `urb1106` | 400* | 3000* | 100* |
| Mass Storage | Seraphim | `xsb1106` | 400* | 3000* | 100* |
| Energy Storage | UEF | `ueb1105` | 500* | 2400* | 500* |
| Energy Storage | Aeon | `uab1105` | 500* | 2400* | 500* |
| Energy Storage | Cybran | `urb1105` | 500* | 2400* | 500* |
| Energy Storage | Seraphim | `xsb1105` | 500* | 2400* | 500* |

## ACU-built experimentals

One per faction, built directly by the ACU — but only once it has the Tech 3
Engineering Suite enhancement. The engine gates that itself (T3 items are
hidden from a pre-upgrade ACU's build menu); `lib/Experimentals.lua` adds a
build restriction on top as belt-and-braces, behind
`Config.ExperimentalsScriptTierGate`. The moment one completes it is transferred into the
builder's ARMY_WAVE_n and sent marching down the lane it was built in — the
player never gets to drive it.

Priced at a QUARTER of stock mass and a FIFTH of stock energy, so unlike
everything else here they are not on the ~1:5 curve. Like the defense
structures they drain gradually over BuildTime, so no storage cap blocks them.

| Unit | Faction | Blueprint | Name | Mass | Energy | Health | Speed |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| Fatboy | UEF | `uel0401` | Fatboy | 7000* | 70000* | 12500 | 1.8 |
| Colossus | Aeon | `ual0401` | Galactic Colossus | 6875* | 68750* | 99999 | 2.4 |
| Monkeylord | Cybran | `url0402` | Monkeylord | 5000* | 52000* | 45000 | 2.5 |
| Ythotha | Seraphim | `xsl0401` | Ythotha | 6625* | 66000* | 67000 | 2.5 |

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
| Mobile Missile Launcher | 2 | UEF | `uel0111` | Flapjack | 180 | 900* | 825 | 2.9 |
| Mobile Missile Launcher | 2 | Aeon | `ual0111` | Evensong | 180 | 900* | 750 | 2.8 |
| Mobile Missile Launcher | 2 | Cybran | `url0111` | Viper | 180 | 900* | 700 | 3 |
| Mobile Missile Launcher | 2 | Seraphim | `xsl0111` | Ythisah | 180 | 900* | 800 | 3.0 |
| Mobile Flak | 2 | UEF | `uel0205` | Sky Boxer | 160 | 800 | 1000 | 3.1 |
| Mobile Flak | 2 | Aeon | `ual0205` | Ascendant | 160 | 800 | 1000 | 2.7 |
| Mobile Flak | 2 | Cybran | `url0205` | Banger | 160 | 800 | 1000 | 2.9 |
| Mobile Flak | 2 | Seraphim | `xsl0205` | Iashavoh | 160 | 800 | 1000 | 2.6 |
| Siege Assault Bot | 3 | UEF | `uel0303` | Titan | 480 | 2400* | 2400 | 3.8 |
| Siege Assault Bot | 3 | Aeon | `ual0303` | Harbinger Mark IV | 840 | 4200* | 3600 | 3.0 |
| Siege Assault Bot | 3 | Cybran | `url0303` | Loyalist | 480 | 2400* | 3000 | 3.8 |
| Siege Assault Bot | 3 | Seraphim | `xsl0303` | Othuum | 840 | 4200* | 4700 | 2.9 |
| Heavy Artillery | 3 | UEF | `uel0304` | Demolisher | 800 | 4000* | 950 | 2.2 |
| Heavy Artillery | 3 | Aeon | `ual0304` | Serenity | 800 | 4000* | 900 | 2.2 |
| Heavy Artillery | 3 | Cybran | `url0304` | Trebuchet | 800 | 4000* | 850 | 2.2 |
| Heavy Artillery | 3 | Seraphim | `xsl0304` | Suthanus | 800 | 4000* | 925 | 2.2 |
| T3 Mobile AA | 3 | UEF | `delk002` | Cougar | 600 | 3000* | 1900 | 3.5 |
| T3 Mobile AA | 3 | Aeon | `dalk003` | Redeemer | 600 | 3000* | 1700 | 3.3 |
| T3 Mobile AA | 3 | Cybran | `drlk001` | Bouncer | 600 | 3000* | 1900 | 3.6 |
| T3 Mobile AA | 3 | Seraphim | `dslk004` | Uyanah | 720 | 3600* | 1800 | 3.4 |
| Faction Special | 3 | UEF | `xel0305` | Percival | 1280 | 6400* | 7200 | 2.2 |
| Faction Special | 3 | Aeon | `xal0305` | Sprite Striker | 700 | 3500* | 500 | 2.5 |
| Faction Special | 3 | Cybran | `xrl0305` | The Brick | 1280 | 6400* | 7500 | 2.4 |
| Faction Special | 3 | Seraphim | `xsl0305` | Usha-Ah | 780 | 3900* | 700 | 2.3 |

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
| Gunship | 2 | UEF | `uea0203` | Stinger | 192 | 960* | 700 | 13.5 |
| Gunship | 2 | Aeon | `uaa0203` | Specter | 270 | 1350* | 848 | 12 |
| Gunship | 2 | Cybran | `ura0203` | Renegade | 270 | 1350* | 832 | 12 |
| Gunship | 2 | Seraphim | `xsa0203` | Vulthoo | 500 | 2500* | 1800 | 11 |
| Fighter/Bomber | 2 | UEF | `dea0202` | Janus | 360 | 1800* | 1200 | 15 |
| Fighter/Bomber | 2 | Aeon | `xaa0202` | Swift Wind | 235 | 1175* | 800 | 18 |
| Fighter/Bomber | 2 | Cybran | `dra0202` | Corsair | 420 | 2100* | 1100 | 15 |
| Fighter/Bomber | 2 | Seraphim | `xsa0202` | Notha | 420 | 2100* | 1000 | 15 |
| Air Superiority Fighter | 3 | UEF | `uea0303` | Wasp | 450 | 2250* | 2300 | 22 |
| Air Superiority Fighter | 3 | Aeon | `uaa0303` | Corona | 450 | 2250* | 2250 | 22 |
| Air Superiority Fighter | 3 | Cybran | `ura0303` | Gemini | 450 | 2250* | 2225 | 22 |
| Air Superiority Fighter | 3 | Seraphim | `xsa0303` | Iazyne | 450 | 2250* | 2275 | 22 |
| Heavy Air | 3 | UEF | `uea0305` | Broadsword | 1500 | 7500* | 6000 | 10 |
| Heavy Air | 3 | Aeon | `xaa0305` | Restorer | 1200 | 6000* | 6000 | 10 |
| Heavy Air | 3 | Cybran | `xra0305` | Wailer | 1500 | 7500* | 5900 | 10 |
| Heavy Air | 3 | Seraphim | `xsa0304` | Sinntha | 1750 | 8750* | 3900 | 17 |

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
| 160 | 800 | Ascendant (`ual0205`) | Aeon | Mobile Flak | Land Factory | 1000 |
| 160 | 800 | Sky Boxer (`uel0205`) | UEF | Mobile Flak | Land Factory | 1000 |
| 160 | 800 | Banger (`url0205`) | Cybran | Mobile Flak | Land Factory | 1000 |
| 160 | 800 | Iashavoh (`xsl0205`) | Seraphim | Mobile Flak | Land Factory | 1000 |
| 180 | 900* | Evensong (`ual0111`) | Aeon | Mobile Missile Launcher | Land Factory | 750 |
| 180 | 900* | Flapjack (`uel0111`) | UEF | Mobile Missile Launcher | Land Factory | 825 |
| 180 | 900* | Viper (`url0111`) | Cybran | Mobile Missile Launcher | Land Factory | 700 |
| 180 | 900* | Ythisah (`xsl0111`) | Seraphim | Mobile Missile Launcher | Land Factory | 800 |
| 192 | 960* | Stinger (`uea0203`) | UEF | Gunship | Air Factory | 700 |
| 198 | 990 | Pillar (`uel0202`) | UEF | Heavy Tank | Land Factory | 1500 |
| 235 | 1175* | Swift Wind (`xaa0202`) | Aeon | Fighter/Bomber | Air Factory | 800 |
| 270 | 1350* | Specter (`uaa0203`) | Aeon | Gunship | Air Factory | 848 |
| 270 | 1350* | Renegade (`ura0203`) | Cybran | Gunship | Air Factory | 832 |
| 290 | 1500 | Rhino (`url0202`) | Cybran | Heavy Tank | Land Factory | 1900 |
| 360 | 1800* | Janus (`dea0202`) | UEF | Fighter/Bomber | Air Factory | 1200 |
| 360 | 1800 | Obsidian (`ual0202`) | Aeon | Heavy Tank | Land Factory | 1250 |
| 360 | 1800 | Ilshavoh (`xsl0202`) | Seraphim | Heavy Tank | Land Factory | 2500 |
| 420 | 2100* | Corsair (`dra0202`) | Cybran | Fighter/Bomber | Air Factory | 1100 |
| 420 | 2100* | Notha (`xsa0202`) | Seraphim | Fighter/Bomber | Air Factory | 1000 |
| 450 | 2250* | Corona (`uaa0303`) | Aeon | Air Superiority Fighter | Air Factory | 2250 |
| 450 | 2250* | Wasp (`uea0303`) | UEF | Air Superiority Fighter | Air Factory | 2300 |
| 450 | 2250* | Gemini (`ura0303`) | Cybran | Air Superiority Fighter | Air Factory | 2225 |
| 450 | 2250* | Iazyne (`xsa0303`) | Seraphim | Air Superiority Fighter | Air Factory | 2275 |
| 480 | 2400* | Titan (`uel0303`) | UEF | Siege Assault Bot | Land Factory | 2400 |
| 480 | 2400* | Loyalist (`url0303`) | Cybran | Siege Assault Bot | Land Factory | 3000 |
| 500 | 2500* | Vulthoo (`xsa0203`) | Seraphim | Gunship | Air Factory | 1800 |
| 600 | 3000* | Redeemer (`dalk003`) | Aeon | T3 Mobile AA | Land Factory | 1700 |
| 600 | 3000* | Cougar (`delk002`) | UEF | T3 Mobile AA | Land Factory | 1900 |
| 600 | 3000* | Bouncer (`drlk001`) | Cybran | T3 Mobile AA | Land Factory | 1900 |
| 700 | 3500* | Sprite Striker (`xal0305`) | Aeon | Faction Special | Land Factory | 500 |
| 720 | 3600* | Uyanah (`dslk004`) | Seraphim | T3 Mobile AA | Land Factory | 1800 |
| 780 | 3900* | Usha-Ah (`xsl0305`) | Seraphim | Faction Special | Land Factory | 700 |
| 800 | 4000* | Serenity (`ual0304`) | Aeon | Heavy Artillery | Land Factory | 900 |
| 800 | 4000* | Demolisher (`uel0304`) | UEF | Heavy Artillery | Land Factory | 950 |
| 800 | 4000* | Trebuchet (`url0304`) | Cybran | Heavy Artillery | Land Factory | 850 |
| 800 | 4000* | Suthanus (`xsl0304`) | Seraphim | Heavy Artillery | Land Factory | 925 |
| 840 | 4200* | Harbinger Mark IV (`ual0303`) | Aeon | Siege Assault Bot | Land Factory | 3600 |
| 840 | 4200* | Othuum (`xsl0303`) | Seraphim | Siege Assault Bot | Land Factory | 4700 |
| 1200 | 6000* | Restorer (`xaa0305`) | Aeon | Heavy Air | Air Factory | 6000 |
| 1280 | 6400* | Percival (`xel0305`) | UEF | Faction Special | Land Factory | 7200 |
| 1280 | 6400* | The Brick (`xrl0305`) | Cybran | Faction Special | Land Factory | 7500 |
| 1500 | 7500* | Broadsword (`uea0305`) | UEF | Heavy Air | Air Factory | 6000 |
| 1500 | 7500* | Wailer (`xra0305`) | Cybran | Heavy Air | Air Factory | 5900 |
| 1750 | 8750* | Sinntha (`xsa0304`) | Seraphim | Heavy Air | Air Factory | 3900 |
