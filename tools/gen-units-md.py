#!/usr/bin/env python3
"""Generate UNITS.md — the Line Wars balance reference.

Reads three sources and joins them:

  * LineWars-2p.v0001/lib/UnitTypes.lua   which factories exist and what each
                                          one may build (the balance table)
  * LineWars-2p.v0001/units/LineWars_units.bp
                                          Line Wars' own cost overrides
  * <gamedata>/units.nx2                  the stock blueprint each unit starts
                                          from (an ordinary zip)

Costs are shown post-override, marked with * where Line Wars changes them, so
the table always reflects what a player is actually charged.

Usage:  python3 tools/gen-units-md.py [--gamedata ~/.faforever/gamedata] [-o UNITS.md]
"""

import argparse
import os
import re
import sys
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAP = os.path.join(REPO, "LineWars-2p.v0001")
UNIT_TYPES = os.path.join(MAP, "lib", "UnitTypes.lua")
OVERRIDES_BP = os.path.join(MAP, "units", "LineWars_units.bp")
DEFAULT_GAMEDATA = os.path.expanduser("~/.faforever/gamedata")


def strip_lua_comments(text):
    return re.sub(r"--[^\n]*", "", text)


def parse_id_list(body):
    """Comma-separated blueprint ids, position-preserving.

    A slot may be `false` — a faction with no unit for that role — and the list
    index IS the faction, so those come back as None rather than being dropped.
    """
    out = []
    for token in body.split(","):
        token = token.strip()
        if not token:
            continue
        m = re.match(r"'([^']+)'$", token)
        out.append(m.group(1) if m else None)
    return out


def parse_unit_types(path):
    """-> [ {kind, name, factories: [id], tiers: {n: [id]}, roles: [ {name, tier, units: [id]} ]} ]

    `factories` are the tier-1 buildings (faction-aligned); `tiers` maps a tier
    number to the buildings a player upgrades into at that tier. Each role carries
    the building `tier` required to queue it.
    """
    text = strip_lua_comments(open(path, encoding="utf-8").read())
    header = re.compile(
        r"kind\s*=\s*'([A-Z]+)'\s*,\s*name\s*=\s*'([^']+)'\s*,"
        r"\s*byFaction\s*=\s*\{([^}]*)\}",
        re.S,
    )
    matches = list(header.finditer(text))
    if not matches:
        sys.exit("gen-units-md: no factory definitions found in %s" % path)

    # The LAST factory's roles run to the end of the Factories table, not to end
    # of file: AcuStructures follows it and its rows have the same
    # `name = '...', tier = N, byFaction = {...}` shape, so an unbounded tail
    # listed every ACU defense structure as an air-factory unit.
    marker = re.search(r"^AcuStructures\s*=", text, re.M)
    factories_end = marker.start() if marker else len(text)

    out = []
    for i, m in enumerate(matches):
        tail_end = matches[i + 1].start() if i + 1 < len(matches) else factories_end
        tail = text[m.end():tail_end]
        # Everything before `roles =` holds the upgrade tiers; split so a role's
        # own braces can't be mistaken for a `[n] = { ids }` tier entry.
        pre_roles = re.split(r"\broles\s*=", tail, maxsplit=1)[0]
        tiers = {
            int(tn): parse_id_list(tb)
            for tn, tb in re.findall(r"\[(\d+)\]\s*=\s*\{([^}]*)\}", pre_roles)
        }
        roles = [
            {"name": rn, "tier": int(rt or 1), "units": parse_id_list(rb)}
            for rn, rt, rb in re.findall(
                r"name\s*=\s*'([^']+)'\s*,"
                r"(?:\s*tier\s*=\s*(\d+)\s*,)?"
                r"\s*byFaction\s*=\s*\{([^}]*)\}",
                tail,
            )
        ]
        out.append({
            "kind": m.group(1),
            "name": m.group(2),
            "factories": parse_id_list(m.group(3)),
            "tiers": tiers,
            "roles": roles,
        })
    return out


def parse_acu_structures(path):
    """-> [ {name, tier, units: [id]} ] from the AcuStructures table.

    Same shape as a Factories role ({name, tier, byFaction}), but AcuStructures
    is a standalone top-level table (structures the ACU builds directly, never
    queued in a factory) — scanned from its own marker rather than via
    parse_unit_types' per-factory header regex.

    Bounded at the AcuExperimentals marker for the same reason parse_unit_types
    is bounded here: a later table with rows of a similar shape would otherwise
    be swallowed by the unbounded tail.
    """
    text = strip_lua_comments(open(path, encoding="utf-8").read())
    m = re.search(r"AcuStructures\s*=\s*\{", text)
    if not m:
        sys.exit("gen-units-md: no AcuStructures table found in %s" % path)
    end = re.search(r"^AcuExperimentals\s*=", text, re.M)
    body = text[m.end():end.start() if end else len(text)]
    return [
        {"name": rn, "tier": int(rt or 1), "units": parse_id_list(rb)}
        for rn, rt, rb in re.findall(
            r"name\s*=\s*'([^']+)'\s*,"
            r"(?:\s*tier\s*=\s*(\d+)\s*,)?"
            r"\s*byFaction\s*=\s*\{([^}]*)\}",
            body,
        )
    ]


def parse_acu_experimentals(path):
    """-> [ {name, faction (1-based), id} ] from the AcuExperimentals table.

    A different row shape from AcuStructures: one unit per faction rather than a
    role with a four-entry byFaction list, because each faction has exactly one
    and the ids share no naming pattern.
    """
    text = strip_lua_comments(open(path, encoding="utf-8").read())
    m = re.search(r"AcuExperimentals\s*=\s*\{", text)
    if not m:
        return []
    return [
        {"name": rn, "faction": int(rf), "id": rid}
        for rn, rf, rid in re.findall(
            r"name\s*=\s*'([^']+)'\s*,\s*faction\s*=\s*(\d+)\s*,\s*id\s*=\s*'([^']+)'",
            text[m.end():],
        )
    ]


def parse_overrides(path):
    """-> { blueprint id: {field: value} } from the OVERRIDES table in the .bp"""
    text = strip_lua_comments(open(path, encoding="utf-8").read())
    out = {}
    groups = re.finditer(
        r"ids\s*=\s*\{([^}]*)\}(.*?)(?=ids\s*=\s*\{|\Z)", text, re.S
    )
    for g in groups:
        fields = {
            k: int(v)
            for k, v in re.findall(r"(BuildCost\w+|StorageMass)\s*=\s*(-?\d+)", g.group(2))
        }
        for uid in parse_id_list(g.group(1)):
            out.setdefault(uid.lower(), {}).update(fields)
    return out


NUM = r"([-\d.]+)"


def field(text, name, pattern=NUM):
    m = re.search(re.escape(name) + r"\s*=\s*" + pattern, text)
    return m.group(1) if m else None


def load_stock(gamedata):
    """-> { blueprint id: {mass, energy, health, speed, name, desc} }"""
    archive = os.path.join(gamedata, "units.nx2")
    if not os.path.isfile(archive):
        sys.exit("gen-units-md: no units.nx2 under %s (pass --gamedata)" % gamedata)

    stock = {}
    with zipfile.ZipFile(archive) as z:
        wanted = {}
        for name in z.namelist():
            m = re.match(r"units/([^/]+)/\1_unit\.bp$", name, re.I)
            if m:
                wanted[m.group(1).lower()] = name
        for uid, name in wanted.items():
            raw = z.read(name).decode("latin-1")
            stock[uid] = {
                "mass": field(raw, "BuildCostMass"),
                "energy": field(raw, "BuildCostEnergy"),
                "health": field(raw, "MaxHealth"),
                # Aircraft carry a near-zero ground MaxSpeed alongside the real
                # MaxAirspeed, so air wins wherever both are present.
                "speed": field(raw, "MaxAirspeed") or field(raw, "MaxSpeed"),
                "name": field(raw, "UnitName", r'"(?:<[^>]*>)?([^"]*)"'),
                "desc": field(raw, "Description", r'"(?:<[^>]*>)?([^"]*)"'),
                # Set on every stock factory above tier 1: the engine prices an
                # upgrade into this building as its cost MINUS the cost of the
                # building being upgraded (lua/game.lua:57).
                "differential": "DifferentialUpgradeCostCalculation" in raw,
            }
    return stock


def num(value):
    """1234.0 -> '1234'; keep one decimal otherwise."""
    if value is None:
        return "?"
    f = float(value)
    return str(int(f)) if f == int(f) else "%.1f" % f


def cost(uid, key, bp_key, stock, overrides):
    """Effective cost, suffixed with * when Line Wars overrides the stock value."""
    entry = stock.get(uid, {})
    over = overrides.get(uid, {}).get(bp_key)
    if over is None:
        return num(entry.get(key))
    return "%s*" % num(over)


def effective(uid, key, bp_key, stock, overrides):
    """Effective cost as a number (override if there is one, else stock)."""
    over = overrides.get(uid, {}).get(bp_key)
    if over is not None:
        return float(over)
    return float(stock.get(uid, {}).get(key) or 0)


def upgrade_cost(uid, prev_uid, stock, overrides):
    """What a tier upgrade actually charges: (mass, energy).

    Every stock factory above tier 1 sets Economy.DifferentialUpgradeCostCalculation,
    so both the upgrade button's tooltip and FactoryQueue.UpgradeCost price it as
    (this tier) minus (the tier below) -- see lua/game.lua:57. The blueprint's own
    BuildCostMass/Energy is NOT what the player pays.
    """
    pairs = []
    for key, bp_key in (("mass", "BuildCostMass"), ("energy", "BuildCostEnergy")):
        here = effective(uid, key, bp_key, stock, overrides)
        below = effective(prev_uid, key, bp_key, stock, overrides)
        if stock.get(uid, {}).get("differential"):
            pairs.append(max(here - below, 0))
        else:
            pairs.append(here)
    return pairs


def sort_key(uid, stock, overrides):
    over = overrides.get(uid, {}).get("BuildCostMass")
    if over is not None:
        return float(over)
    return float(stock.get(uid, {}).get("mass") or 0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gamedata", default=DEFAULT_GAMEDATA)
    ap.add_argument("-o", "--output", default=os.path.join(REPO, "UNITS.md"))
    args = ap.parse_args()

    factions = re.findall(
        r"'([^']+)'",
        re.search(
            r"FactionNames\s*=\s*\{([^}]*)\}",
            strip_lua_comments(open(UNIT_TYPES, encoding="utf-8").read()),
        ).group(1),
    )
    kinds = parse_unit_types(UNIT_TYPES)
    structures = parse_acu_structures(UNIT_TYPES)
    experimentals = parse_acu_experimentals(UNIT_TYPES)
    overrides = parse_overrides(OVERRIDES_BP)
    stock = load_stock(os.path.expanduser(args.gamedata))

    for uid in [u for k in kinds for r in k["roles"] for u in r["units"]] + \
               [f for k in kinds for f in k["factories"]] + \
               [f for k in kinds for ids in k["tiers"].values() for f in ids] + \
               [u for s in structures for u in s["units"]] + \
               [e["id"] for e in experimentals]:
        if uid is not None and uid not in stock:
            sys.exit("gen-units-md: %s is not a real blueprint id" % uid)

    L = []
    L.append("# Line Wars — buildable units")
    L.append("")
    L.append("**Generated file — do not edit.** Run `python3 tools/gen-units-md.py`")
    L.append("after changing `LineWars-2p.v0001/lib/UnitTypes.lua` (which units exist)")
    L.append("or `LineWars-2p.v0001/units/LineWars_units.bp` (what they cost).")
    L.append("")
    L.append("Costs are what a player is actually charged when queuing. A `*` marks a")
    L.append("value Line Wars overrides; everything else is stock FAF. Build time is")
    L.append("deliberately absent: factories are pinned to build rate 0, so mass and")
    L.append("energy are the only levers that gate army size.")
    L.append("")
    L.append("Caveat: the overrides live in a map `.bp`, which loses to any unit mod")
    L.append("that touches the same unit — with BlackOps/Total Mayhem loaded, `*`")
    L.append("values silently revert to the mod's. Play without unit-overhaul mods.")
    L.append("")

    L.append("## Factories")
    L.append("")
    L.append("Built by the ACU (Tech 1). Each one is an independent queue bound to the")
    L.append("lane it stands in, so a factory sited in a teammate's lane reinforces it.")
    L.append("Higher tiers are the native factory upgrade; upgrading unlocks that")
    L.append("tier's units.")
    L.append("")
    L.append("**Mass/Energy is the blueprint value; Pay is what the upgrade actually")
    L.append("costs.** They differ above tier 1 because those buildings set")
    L.append("`DifferentialUpgradeCostCalculation`, so the engine — and the upgrade")
    L.append("button's own tooltip, and `FactoryQueue.UpgradeCost` — price the upgrade")
    L.append("as this tier minus the tier below.")
    L.append("")
    L.append("| Factory | Tier | Faction | Blueprint | Mass | Energy | Pay (mass) | Pay (energy) | Health |")
    L.append("| --- | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |")
    for k in kinds:
        levels = [(1, k["factories"])] + sorted(k["tiers"].items())
        for n, (tier, ids) in enumerate(levels):
            prev = levels[n - 1][1] if n else None
            for i, uid in enumerate(ids):
                if uid is None:
                    continue
                if prev is None:
                    pay_m = pay_e = "—"
                else:
                    m, e = upgrade_cost(uid, prev[i], stock, overrides)
                    pay_m, pay_e = num(m), num(e)
                L.append("| %s | %s | %s | `%s` | %s | %s | %s | %s | %s |" % (
                    k["name"], tier, factions[i], uid,
                    cost(uid, "mass", "BuildCostMass", stock, overrides),
                    cost(uid, "energy", "BuildCostEnergy", stock, overrides),
                    pay_m, pay_e,
                    num(stock[uid].get("health")),
                ))
    L.append("")

    L.append("## ACU-built defense structures")
    L.append("")
    L.append("Built directly by the ACU on its own side of the lane midline — exempt from")
    L.append("the no-build zone (that is the point: it's how you hold a forward choke), but")
    L.append("never past the midline. The tier column is a real gate the engine applies: a")
    L.append("pre-upgrade ACU does not show T3 items in its build menu, even though the stock")
    L.append("BuildableCategory carries BUILTBYCOMMANDER, BUILTBYTIER2COMMANDER and")
    L.append("BUILTBYTIER3COMMANDER from the start. These use the engine's own")
    L.append("construction economy (cost drains gradually over BuildTime) rather than the")
    L.append("factory-queue charge/refund path, so a value here exceeding a storage cap is")
    L.append("a slow build, not a hard block.")
    L.append("")
    L.append("The T3 Point Defense is one building, the UEF Ravager, for every faction:")
    L.append("stock FA has no other, so `units/LineWars_units.bp` appends the remaining")
    L.append("three faction categories to it and every ACU can build it. It keeps its UEF")
    L.append("model and name whoever builds it.")
    L.append("")
    L.append("| Structure | Tier | Faction | Blueprint | Mass | Energy | Health |")
    L.append("| --- | ---: | --- | --- | ---: | ---: | ---: |")
    for s in sorted(structures, key=lambda r: r["tier"]):
        for i, uid in enumerate(s["units"]):
            if uid is None:
                continue
            L.append("| %s | %s | %s | `%s` | %s | %s | %s |" % (
                s["name"], s["tier"], factions[i], uid,
                cost(uid, "mass", "BuildCostMass", stock, overrides),
                cost(uid, "energy", "BuildCostEnergy", stock, overrides),
                num(stock[uid].get("health")),
            ))
    L.append("")

    L.append("## ACU-built experimentals")
    L.append("")
    L.append("One per faction, built directly by the ACU — but only once it has the Tech 3")
    L.append("Engineering Suite enhancement. The engine gates that itself (T3 items are")
    L.append("hidden from a pre-upgrade ACU's build menu); `lib/Experimentals.lua` adds a")
    L.append("build restriction on top as belt-and-braces, behind")
    L.append("`Config.ExperimentalsScriptTierGate`. The moment one completes it is transferred into the")
    L.append("builder's ARMY_WAVE_n and sent marching down the lane it was built in — the")
    L.append("player never gets to drive it.")
    L.append("")
    L.append("Priced at a QUARTER of stock mass and a FIFTH of stock energy, so unlike")
    L.append("everything else here they are not on the ~1:5 curve. Like the defense")
    L.append("structures they drain gradually over BuildTime, so no storage cap blocks them.")
    L.append("")
    L.append("| Unit | Faction | Blueprint | Name | Mass | Energy | Health | Speed |")
    L.append("| --- | --- | --- | --- | ---: | ---: | ---: | ---: |")
    for e in sorted(experimentals, key=lambda r: r["faction"]):
        uid = e["id"]
        L.append("| %s | %s | `%s` | %s | %s | %s | %s | %s |" % (
            e["name"], factions[e["faction"] - 1], uid,
            stock[uid].get("name") or "?",
            cost(uid, "mass", "BuildCostMass", stock, overrides),
            cost(uid, "energy", "BuildCostEnergy", stock, overrides),
            num(stock[uid].get("health")),
            num(stock[uid].get("speed")),
        ))
    L.append("")

    for k in kinds:
        L.append("## %s units" % k["name"])
        L.append("")
        L.append("| Role | Tier | Faction | Blueprint | Name | Mass | Energy | Health | Speed |")
        L.append("| --- | ---: | --- | --- | --- | ---: | ---: | ---: | ---: |")
        for role in sorted(k["roles"], key=lambda r: r["tier"]):
            for i, uid in enumerate(role["units"]):
                if uid is None:
                    continue
                L.append("| %s | %s | %s | `%s` | %s | %s | %s | %s | %s |" % (
                    role["name"], role["tier"], factions[i], uid,
                    stock[uid].get("name") or "?",
                    cost(uid, "mass", "BuildCostMass", stock, overrides),
                    cost(uid, "energy", "BuildCostEnergy", stock, overrides),
                    num(stock[uid].get("health")),
                    num(stock[uid].get("speed")),
                ))
        L.append("")

    L.append("## Every unit by mass cost")
    L.append("")
    L.append("The relative-pricing view: cheapest first, all factions and both")
    L.append("factories together.")
    L.append("")
    L.append("| Mass | Energy | Unit | Faction | Role | Factory | Health |")
    L.append("| ---: | ---: | --- | --- | --- | --- | ---: |")
    rows = []
    for k in kinds:
        for role in k["roles"]:
            for i, uid in enumerate(role["units"]):
                if uid is None:
                    continue
                rows.append((sort_key(uid, stock, overrides), uid, factions[i],
                             role["name"], k["name"]))
    for _, uid, faction, role, kind_name in sorted(rows, key=lambda r: (r[0], r[1])):
        L.append("| %s | %s | %s (`%s`) | %s | %s | %s | %s |" % (
            cost(uid, "mass", "BuildCostMass", stock, overrides),
            cost(uid, "energy", "BuildCostEnergy", stock, overrides),
            stock[uid].get("name") or "?", uid, faction, role, kind_name,
            num(stock[uid].get("health")),
        ))
    L.append("")

    open(args.output, "w", encoding="utf-8").write("\n".join(L))
    print("wrote %s (%d units, %d factories, %d ACU structures)" % (
        args.output,
        sum(1 for k in kinds for r in k["roles"] for u in r["units"] if u),
        sum(len(k["factories"]) for k in kinds),
        sum(1 for s in structures for u in s["units"] if u),
    ))


if __name__ == "__main__":
    main()
